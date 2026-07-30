import Foundation
import IhsanCore
import IhsanLocation
import IhsanPrayerTimes
import OSLog
import SwiftData
@preconcurrency import UserNotifications

public struct PrayerNotificationPreference: Equatable, Sendable {
    public let prayer: Prayer
    public let isEnabled: Bool
    public let soundChoice: AdhanSoundCatalog?
    public let leadTimeSeconds: Int
    /// When `false`, the scheduled notification uses the system default
    /// tone instead of the configured adhan recording. This is the
    /// "mute adhan for this prayer" toggle exposed in the row UI, and
    /// is independent of `isEnabled` (which decides whether a
    /// notification fires at all).
    public let adhanEnabled: Bool

    public init(
        prayer: Prayer,
        isEnabled: Bool = true,
        soundChoice: AdhanSoundCatalog? = nil,
        leadTimeSeconds: Int = 0,
        adhanEnabled: Bool = true
    ) {
        self.prayer = prayer
        self.isEnabled = isEnabled
        self.soundChoice = soundChoice
        self.leadTimeSeconds = leadTimeSeconds
        self.adhanEnabled = adhanEnabled
    }
}

public struct NotificationScheduleSettings: Equatable, Sendable {
    public let notificationsEnabled: Bool
    public let calculationMethod: CalculationMethodChoice
    public let madhab: MadhabChoice
    public let highLatitudeRule: HighLatitudeRule
    public let adhanSoundChoice: AdhanSoundCatalog
    public let prayerPreferences: [PrayerNotificationPreference]

    public init(
        notificationsEnabled: Bool = true,
        calculationMethod: CalculationMethodChoice = .isna,
        madhab: MadhabChoice = .standard,
        highLatitudeRule: HighLatitudeRule = .middleOfNight,
        adhanSoundChoice: AdhanSoundCatalog = .systemDefault,
        prayerPreferences: [PrayerNotificationPreference] = Prayer.allCases.map { PrayerNotificationPreference(prayer: $0) }
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.calculationMethod = calculationMethod
        self.madhab = madhab
        self.highLatitudeRule = highLatitudeRule
        self.adhanSoundChoice = adhanSoundChoice
        self.prayerPreferences = prayerPreferences
    }

    func preference(for prayer: Prayer) -> PrayerNotificationPreference {
        prayerPreferences.first { $0.prayer == prayer } ?? PrayerNotificationPreference(prayer: prayer)
    }
}

extension NotificationScheduleSettings {
    /// `isPaused` suppresses the whole schedule without touching any stored
    /// preference — per-prayer overrides come back exactly as the user left
    /// them when the pause ends.
    init(userSettings: UserSettings, isPaused: Bool = false) {
        let decodedConfigs = (try? JSONDecoder().decode(
            [PrayerNotificationConfig].self,
            from: Data(userSettings.prayerNotificationsConfigJSON.utf8)
        )) ?? Prayer.allCases.map { PrayerNotificationConfig(prayer: $0) }

        self.init(
            notificationsEnabled: userSettings.notificationsEnabled && !isPaused,
            calculationMethod: userSettings.calculationMethod,
            madhab: userSettings.madhab,
            highLatitudeRule: userSettings.highLatitudeRule,
            prayerPreferences: decodedConfigs.map {
                let soundChoice = AdhanSoundCatalog(userChoice: $0.athanSoundName)
                return PrayerNotificationPreference(
                    prayer: $0.prayer,
                    isEnabled: $0.isEnabled,
                    soundChoice: soundChoice == .systemDefault ? nil : soundChoice,
                    leadTimeSeconds: $0.leadTimeSeconds,
                    adhanEnabled: userSettings.adhanEnabled(for: $0.prayer)
                )
            }
        )
    }
}

public protocol NotificationSettingsProviding: Sendable {
    func currentNotificationSettings() async throws -> NotificationScheduleSettings
}

public protocol PrayerActivityScheduling: Sendable {
    func schedulePrayerActivityStart(
        for prayerTime: PrayerTime,
        in dayTimes: DayPrayerTimes,
        startDate: Date
    ) async throws
}

public struct NoOpPrayerActivityScheduler: PrayerActivityScheduling {
    public init() {}

    public func schedulePrayerActivityStart(
        for prayerTime: PrayerTime,
        in dayTimes: DayPrayerTimes,
        startDate: Date
    ) async throws {
        _ = (prayerTime, dayTimes, startDate)
    }
}

public actor UserSettingsNotificationSettingsProvider: NotificationSettingsProviding {
    public init() {}

    public func currentNotificationSettings() async throws -> NotificationScheduleSettings {
        // The process's one container — never a second mirrored
        // instance over the same store (CoreData 134422).
        let container = try IhsanSharedModelContainer.shared.container()
        let context = ModelContext(container)
        let settings = try UserSettings.fetchOrCreate(in: context)

        let activePauses = try context.fetch(FetchDescriptor<PauseInterval>(
            predicate: #Predicate { $0.endDate == nil }
        ))

        return NotificationScheduleSettings(
            userSettings: settings,
            isPaused: !activePauses.isEmpty
        )
    }
}

public actor NotificationScheduler {
    /// Scheduling-only Live Activity window. This package has no
    /// dependency on, and cannot affect, the prayer state resolver.
    private static let liveActivityPreAdhanSchedulingLeadTime: TimeInterval = 60 * 60
    private static let liveActivityPostAdhanSchedulingLifetime: TimeInterval = 30 * 60
    public static let shared = NotificationScheduler(
        prayerTimesProvider: AdhanPrayerTimesProvider(),
        locationProvider: CoreLocationCoordinator.shared,
        settingsProvider: UserSettingsNotificationSettingsProvider()
    )

    static let notificationIdentifierPrefix = "ihsan.prayer."
    private static let rollingWindowDayCount = 14

    private let prayerTimesProvider: any PrayerTimesProviding
    private let locationProvider: any LocationProviding
    private let settingsProvider: any NotificationSettingsProviding
    private let notificationCenter: any UserNotificationScheduling
    private var prayerActivityScheduler: any PrayerActivityScheduling
    private let now: @Sendable () -> Date
    private let soundFileResolver: AdhanSoundFileResolver
    private let logger = Logger(subsystem: "com.sameerstudios.ihsan", category: "NotificationScheduler")

    public init(
        prayerTimesProvider: any PrayerTimesProviding,
        locationProvider: any LocationProviding,
        settingsProvider: any NotificationSettingsProviding
    ) {
        self.init(
            prayerTimesProvider: prayerTimesProvider,
            locationProvider: locationProvider,
            settingsProvider: settingsProvider,
            notificationCenter: SystemUserNotificationCenter(center: .current()),
            prayerActivityScheduler: NoOpPrayerActivityScheduler(),
            now: { Date() },
            soundFileResolver: .mainBundle
        )
    }

    init(
        prayerTimesProvider: any PrayerTimesProviding,
        locationProvider: any LocationProviding,
        settingsProvider: any NotificationSettingsProviding,
        notificationCenter: any UserNotificationScheduling,
        prayerActivityScheduler: any PrayerActivityScheduling = NoOpPrayerActivityScheduler(),
        now: @escaping @Sendable () -> Date,
        soundFileResolver: AdhanSoundFileResolver
    ) {
        self.prayerTimesProvider = prayerTimesProvider
        self.locationProvider = locationProvider
        self.settingsProvider = settingsProvider
        self.notificationCenter = notificationCenter
        self.prayerActivityScheduler = prayerActivityScheduler
        self.now = now
        self.soundFileResolver = soundFileResolver
    }

    public func setPrayerActivityScheduler(_ scheduler: any PrayerActivityScheduling) {
        prayerActivityScheduler = scheduler
    }

    @discardableResult
    public func requestAuthorization() async throws -> Bool {
        try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func rebuildSchedule() async throws {
        let authorizationStatus = await notificationCenter.authorizationStatus()
        guard authorizationStatus.allowsScheduling else {
            logger.info("Notification permission is not granted; skipping adhan notification rebuild.")
            return
        }

        let settings = try await settingsProvider.currentNotificationSettings()
        guard settings.notificationsEnabled else {
            logger.info("Prayer notifications are disabled; clearing Ihsan pending notifications.")
            await cancelAllScheduledNotifications()
            return
        }

        let place = try await locationProvider.currentPlace()
        let referenceDate = now()
        let dateRangeEnd = try scheduleEndDate(from: referenceDate, timeZone: place.timeZone)
        let days = try prayerTimesProvider.dayTimesRange(
            from: referenceDate,
            to: dateRangeEnd,
            coordinates: place.coordinates,
            timeZone: place.timeZone,
            calculationMethod: settings.calculationMethod,
            madhab: settings.madhab,
            highLatitudeRule: settings.highLatitudeRule
        )

        await cancelAllScheduledNotifications()

        for day in days {
            for prayerTime in day.allFardh {
                let preference = settings.preference(for: prayerTime.prayer)
                guard preference.isEnabled else {
                    continue
                }

                let notificationDate = prayerTime.scheduledTime.addingTimeInterval(TimeInterval(-preference.leadTimeSeconds))
                let activityStartDate = prayerTime.scheduledTime.addingTimeInterval(
                    -Self.liveActivityPreAdhanSchedulingLeadTime
                )
                if activityStartDate > referenceDate {
                    try await prayerActivityScheduler.schedulePrayerActivityStart(
                        for: prayerTime,
                        in: day,
                        startDate: activityStartDate
                    )
                } else if prayerTime.scheduledTime.addingTimeInterval(
                    Self.liveActivityPostAdhanSchedulingLifetime
                ) > referenceDate {
                    try await prayerActivityScheduler.schedulePrayerActivityStart(
                        for: prayerTime,
                        in: day,
                        startDate: activityStartDate
                    )
                }

                guard notificationDate > referenceDate else {
                    continue
                }

                // When the user has muted the adhan for this prayer, fall
                // back to the system default tone — they still receive the
                // notification, just without the recorded call to prayer.
                let resolvedSoundChoice: AdhanSoundCatalog = preference.adhanEnabled
                    ? (preference.soundChoice ?? settings.adhanSoundChoice)
                    : .systemDefault
                let request = makeNotificationRequest(
                    prayerTime: prayerTime,
                    notificationDate: notificationDate,
                    timeZone: place.timeZone,
                    soundChoice: resolvedSoundChoice
                )
                try await notificationCenter.add(request)
            }
        }

    }

    public func cancelAllScheduledNotifications() async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let ihsanIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.notificationIdentifierPrefix) }
        guard !ihsanIdentifiers.isEmpty else {
            return
        }

        await notificationCenter.removePendingNotificationRequests(withIdentifiers: ihsanIdentifiers)
    }

    public func scheduledNotifications() async -> [ScheduledNotification] {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        return pendingRequests
            .filter { $0.identifier.hasPrefix(Self.notificationIdentifierPrefix) }
            .compactMap(ScheduledNotification.init(request:))
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private func scheduleEndDate(from referenceDate: Date, timeZone: TimeZone) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard let endDate = calendar.date(
            byAdding: .day,
            value: Self.rollingWindowDayCount - 1,
            to: referenceDate
        ) else {
            throw NotificationSchedulerError.invalidScheduleWindow
        }
        return endDate
    }

    private func makeNotificationRequest(
        prayerTime: PrayerTime,
        notificationDate: Date,
        timeZone: TimeZone,
        soundChoice: AdhanSoundCatalog
    ) -> UNNotificationRequest {
        let content = NotificationContent.makeAdhanContent(
            prayer: prayerTime.prayer,
            scheduledDate: prayerTime.scheduledTime,
            timeZone: timeZone,
            soundChoice: soundChoice,
            soundFileResolver: soundFileResolver
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notificationDate)
        components.timeZone = timeZone

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = Self.identifier(for: prayerTime.prayer, scheduledDate: prayerTime.scheduledTime)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private static func identifier(for prayer: Prayer, scheduledDate: Date) -> String {
        "\(notificationIdentifierPrefix)\(prayer.rawValue).\(Int(scheduledDate.timeIntervalSince1970))"
    }
}

public enum NotificationSchedulerError: Error, Sendable {
    case invalidScheduleWindow
}

extension ScheduledNotification {
    init?(request: UNNotificationRequest) {
        guard
            let prayerRawValue = request.content.userInfo[ScheduledNotificationUserInfoKey.prayer] as? String,
            let prayer = Prayer(rawValue: prayerRawValue),
            let scheduledDate = request.content.userInfo[ScheduledNotificationUserInfoKey.scheduledDate] as? Date
        else {
            return nil
        }

        self.init(
            id: request.identifier,
            prayer: prayer,
            scheduledDate: scheduledDate,
            title: request.content.title,
            subtitle: request.content.subtitle,
            body: request.content.body,
            soundFileName: request.content.userInfo[ScheduledNotificationUserInfoKey.soundFileName] as? String
        )
    }
}

enum NotificationAuthorizationState: Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var allowsScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        }
    }
}

protocol UserNotificationScheduling: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationStatus() async -> NotificationAuthorizationState
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async
}

final class SystemUserNotificationCenter: UserNotificationScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter) {
        self.center = center
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func authorizationStatus() async -> NotificationAuthorizationState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .denied
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
