import Foundation
import IhsanCore
import IhsanLocation
import IhsanPrayerTimes
import OSLog
import SwiftData
@preconcurrency import UserNotifications

public struct PrayerNotificationPreference: Equatable, Sendable {
    public let prayer: Prayer
    /// Whether a notification fires at all for this prayer.
    public let isEnabled: Bool
    /// What it sounds like. `.silent` is a real answer — banner only —
    /// and is the single way this app says "no sound"; there is no
    /// second mute flag that could disagree with it.
    public let soundChoice: AdhanSoundCatalog
    public let leadTimeSeconds: Int
    /// Whether this prayer may break through Focus.
    public let isTimeSensitive: Bool

    public init(
        prayer: Prayer,
        isEnabled: Bool = true,
        soundChoice: AdhanSoundCatalog = .chime,
        leadTimeSeconds: Int = 0,
        isTimeSensitive: Bool = false
    ) {
        self.prayer = prayer
        self.isEnabled = isEnabled
        self.soundChoice = soundChoice
        self.leadTimeSeconds = leadTimeSeconds
        self.isTimeSensitive = isTimeSensitive
    }
}

public struct NotificationScheduleSettings: Equatable, Sendable {
    public let notificationsEnabled: Bool
    /// A pause suppresses ṣalāh notifications and Live Activities, but
    /// not remembrance. Keeping this separate from the global switch
    /// prevents an excused pause from accidentally muting adhkār too.
    public let prayerNotificationsSuppressed: Bool
    public let morningAdhkarReminderEnabled: Bool
    public let eveningAdhkarReminderEnabled: Bool
    public let calculationMethod: CalculationMethodChoice
    public let madhab: MadhabChoice
    public let highLatitudeRule: HighLatitudeRule
    /// The user's calculation depth. Notifications fire against the
    /// same instants the plate draws — a custom angle that moved Fajr
    /// must move the Fajr notification too.
    public let calculationTuning: CalculationTuning
    public let prayerPreferences: [PrayerNotificationPreference]

    public init(
        notificationsEnabled: Bool = true,
        prayerNotificationsSuppressed: Bool = false,
        morningAdhkarReminderEnabled: Bool = false,
        eveningAdhkarReminderEnabled: Bool = false,
        calculationMethod: CalculationMethodChoice = .isna,
        madhab: MadhabChoice = .standard,
        highLatitudeRule: HighLatitudeRule = .middleOfNight,
        calculationTuning: CalculationTuning = .standard,
        prayerPreferences: [PrayerNotificationPreference] = Prayer.allCases.map { PrayerNotificationPreference(prayer: $0) }
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.prayerNotificationsSuppressed = prayerNotificationsSuppressed
        self.morningAdhkarReminderEnabled = morningAdhkarReminderEnabled
        self.eveningAdhkarReminderEnabled = eveningAdhkarReminderEnabled
        self.calculationMethod = calculationMethod
        self.madhab = madhab
        self.highLatitudeRule = highLatitudeRule
        self.calculationTuning = calculationTuning
        self.prayerPreferences = prayerPreferences
    }

    func preference(for prayer: Prayer) -> PrayerNotificationPreference {
        prayerPreferences.first { $0.prayer == prayer } ?? PrayerNotificationPreference(prayer: prayer)
    }
}

extension NotificationScheduleSettings {
    /// `isPaused` suppresses prayer alerts without touching their stored
    /// preferences. An explicitly enabled remembrance reminder remains
    /// available because remembrance itself is not part of the pause.
    init(
        userSettings: UserSettings,
        isPaused: Bool = false,
        adhkarRemindersEnabled: Bool = false
    ) {
        let decodedConfigs = (try? JSONDecoder().decode(
            [PrayerNotificationConfig].self,
            from: Data(userSettings.prayerNotificationsConfigJSON.utf8)
        )) ?? Prayer.allCases.map { PrayerNotificationConfig(prayer: $0) }

        self.init(
            notificationsEnabled: userSettings.notificationsEnabled,
            prayerNotificationsSuppressed: isPaused,
            morningAdhkarReminderEnabled: adhkarRemindersEnabled
                && AdhkarAvailability.isAvailable
                && userSettings.adhkarLayerEnabled
                && userSettings.adhkarMorningEnabled,
            eveningAdhkarReminderEnabled: adhkarRemindersEnabled
                && AdhkarAvailability.isAvailable
                && userSettings.adhkarLayerEnabled
                && userSettings.adhkarEveningEnabled,
            calculationMethod: userSettings.calculationMethod,
            madhab: userSettings.madhab,
            highLatitudeRule: userSettings.highLatitudeRule,
            calculationTuning: userSettings.calculationTuning,
            prayerPreferences: decodedConfigs.map {
                // The legacy per-prayer mute column still wins when it
                // is off, so a person who silenced a prayer in an
                // earlier build stays silenced through the change of
                // vocabulary.
                let stored = AdhanSoundCatalog(userChoice: $0.athanSoundName)
                let muted = !userSettings.adhanEnabled(for: $0.prayer)
                return PrayerNotificationPreference(
                    prayer: $0.prayer,
                    isEnabled: $0.isEnabled,
                    soundChoice: muted ? .silent : stored,
                    leadTimeSeconds: $0.leadTimeSeconds,
                    isTimeSensitive: $0.isTimeSensitive
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
            isPaused: !activePauses.isEmpty,
            adhkarRemindersEnabled: AdhkarReminderPreferenceStore.isEnabled
        )
    }
}

/// Adhkār reminders are device-local, like notification authorization
/// itself. Suggestions remain visible independently; this preference
/// only decides whether the device calls attention to an opening window.
public enum AdhkarReminderPreferenceStore {
    public static let key = "IhsanAdhkarWindowRemindersEnabled"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: IhsanModelContainerFactory.appGroupIdentifier) ?? .standard
    }

    public static var isEnabled: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}

public actor NotificationScheduler {
    public static let shared = NotificationScheduler(
        prayerTimesProvider: AdhanPrayerTimesProvider(),
        locationProvider: CoreLocationCoordinator.shared,
        settingsProvider: UserSettingsNotificationSettingsProvider()
    )

    static let notificationIdentifierPrefix = "ihsan.prayer."
    static let adhkarNotificationIdentifierPrefix = "ihsan.adhkar."
    private static let rollingWindowDayCount = 14
    /// Avoids stacking a remembrance banner on the prayer notification
    /// at the exact same instant while remaining well inside each window.
    private static let adhkarReminderDelay: TimeInterval = 10 * 60

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
        guard settings.notificationsEnabled
                || settings.morningAdhkarReminderEnabled
                || settings.eveningAdhkarReminderEnabled
        else {
            logger.info("Ihsan notifications are disabled; clearing pending notifications.")
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
            highLatitudeRule: settings.highLatitudeRule,
            tuning: settings.calculationTuning
        )

        await cancelAllScheduledNotifications()

        for day in days {
            if settings.notificationsEnabled && !settings.prayerNotificationsSuppressed {
                for prayerTime in day.allFardh {
                    let preference = settings.preference(for: prayerTime.prayer)
                    guard preference.isEnabled else {
                        continue
                    }

                    let notificationDate = prayerTime.scheduledTime.addingTimeInterval(TimeInterval(-preference.leadTimeSeconds))
                    let activityStartDate = prayerTime.scheduledTime.addingTimeInterval(
                        -LiveActivityWindow.preAdhanLead
                    )
                    if activityStartDate > referenceDate {
                        try await prayerActivityScheduler.schedulePrayerActivityStart(
                            for: prayerTime,
                            in: day,
                            startDate: activityStartDate
                        )
                    } else if prayerTime.scheduledTime.addingTimeInterval(
                        LiveActivityWindow.postAdhanLifetime
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

                    let request = makeNotificationRequest(
                        prayerTime: prayerTime,
                        notificationDate: notificationDate,
                        timeZone: place.timeZone,
                        soundChoice: preference.soundChoice,
                        isTimeSensitive: preference.isTimeSensitive
                    )
                    try await notificationCenter.add(request)
                }
            }

            if settings.morningAdhkarReminderEnabled {
                try await scheduleAdhkarReminder(
                    category: .morning,
                    windowStart: day.fajr.scheduledTime,
                    referenceDate: referenceDate,
                    timeZone: place.timeZone
                )
            }
            if settings.eveningAdhkarReminderEnabled {
                try await scheduleAdhkarReminder(
                    category: .evening,
                    windowStart: day.maghrib.scheduledTime,
                    referenceDate: referenceDate,
                    timeZone: place.timeZone
                )
            }
        }
    }

    public func cancelAllScheduledNotifications() async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let ihsanIdentifiers = pendingRequests
            .map(\.identifier)
            .filter {
                $0.hasPrefix(Self.notificationIdentifierPrefix)
                    || $0.hasPrefix(Self.adhkarNotificationIdentifierPrefix)
            }
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
        soundChoice: AdhanSoundCatalog,
        isTimeSensitive: Bool
    ) -> UNNotificationRequest {
        let content = NotificationContent.makeAdhanContent(
            prayer: prayerTime.prayer,
            scheduledDate: prayerTime.scheduledTime,
            timeZone: timeZone,
            soundChoice: soundChoice,
            isTimeSensitive: isTimeSensitive,
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

    private func scheduleAdhkarReminder(
        category: AdhkarCategory,
        windowStart: Date,
        referenceDate: Date,
        timeZone: TimeZone
    ) async throws {
        let notificationDate = windowStart.addingTimeInterval(Self.adhkarReminderDelay)
        guard notificationDate > referenceDate else { return }

        let content = NotificationContent.makeAdhkarContent(
            category: category,
            scheduledDate: notificationDate,
            timeZone: timeZone
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: notificationDate
        )
        components.timeZone = timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "\(Self.adhkarNotificationIdentifierPrefix)\(category.rawValue).\(Int(notificationDate.timeIntervalSince1970))"
        try await notificationCenter.add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
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
