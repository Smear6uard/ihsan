import Foundation
import IhsanCore
import IhsanLocation
import IhsanPrayerTimes
import Testing
@preconcurrency import UserNotifications
@testable import IhsanNotifications

@Test
func rebuildScheduleCancelsExistingIhsanRequestsThenSchedulesRollingWindow() async throws {
    let now = fixedDate()
    let center = MockNotificationCenter(existingRequests: [
        makeExistingRequest(identifier: "ihsan.prayer.fajr.1"),
        makeExistingRequest(identifier: "unrelated.notification")
    ])
    let activityScheduler = MockPrayerActivityScheduler()
    let scheduler = makeScheduler(now: now, center: center, activityScheduler: activityScheduler)

    try await scheduler.rebuildSchedule()

    let events = center.events
    #expect(events.first == .remove(["ihsan.prayer.fajr.1"]))
    #expect(events.filter(\.isAdd).count == 70)
    #expect(activityScheduler.requests.count == 70)

    let pending = await center.pendingNotificationRequests()
    #expect(pending.count == 71)
    #expect(pending.contains { $0.identifier == "unrelated.notification" })
}

@Test
func fajrAwareSoundUsesFajrFileOnlyForFajr() {
    #expect(AdhanSoundCatalog.fajrAwareLong.fileName(for: .fajr) == "adhan-fajr-long.caf")
    #expect(AdhanSoundCatalog.fajrAwareLong.fileName(for: .dhuhr) == "adhan-standard-long.caf")
    #expect(AdhanSoundCatalog.fajrAwareShort.fileName(for: .fajr) == "adhan-fajr-short.caf")
    #expect(AdhanSoundCatalog.fajrAwareShort.fileName(for: .isha) == "adhan-standard-short.caf")
}

@Test
func contentFallsBackToDefaultSoundButKeepsDiagnosticFileNameWhenAssetIsMissing() {
    let content = NotificationContent.makeAdhanContent(
        prayer: .fajr,
        scheduledDate: fixedDate(),
        timeZone: TimeZone(secondsFromGMT: 0)!,
        soundChoice: .fajrAwareLong,
        soundFileResolver: AdhanSoundFileResolver { _ in false }
    )

    #expect(content.userInfo[ScheduledNotificationUserInfoKey.soundFileName] as? String == "adhan-fajr-long.caf")
}

@Test
func rebuildScheduleSkipsPrayersDisabledInSettings() async throws {
    let center = MockNotificationCenter()
    let activityScheduler = MockPrayerActivityScheduler()
    let disabledAsrSettings = NotificationScheduleSettings(
        prayerPreferences: Prayer.allCases.map {
            PrayerNotificationPreference(prayer: $0, isEnabled: $0 != .asr, soundChoice: .standardShort)
        }
    )
    let scheduler = makeScheduler(
        now: fixedDate(),
        center: center,
        settings: disabledAsrSettings,
        activityScheduler: activityScheduler
    )

    try await scheduler.rebuildSchedule()

    let scheduled = await scheduler.scheduledNotifications()
    #expect(scheduled.count == 56)
    #expect(!scheduled.contains { $0.prayer == .asr })
    #expect(activityScheduler.requests.count == 56)
    #expect(!activityScheduler.requests.contains { $0.prayer == .asr })
}

@Test
func rebuildScheduleIsNoOpWhenNotificationPermissionIsDenied() async throws {
    let center = MockNotificationCenter(authorization: .denied)
    let scheduler = makeScheduler(now: fixedDate(), center: center)

    try await scheduler.rebuildSchedule()

    #expect(center.events.isEmpty)
}

private func makeScheduler(
    now: Date,
    center: MockNotificationCenter,
    settings: NotificationScheduleSettings = NotificationScheduleSettings(
        adhanSoundChoice: .fajrAwareLong
    ),
    activityScheduler: MockPrayerActivityScheduler = MockPrayerActivityScheduler()
) -> NotificationScheduler {
    NotificationScheduler(
        prayerTimesProvider: MockPrayerTimesProvider(),
        locationProvider: MockLocationProvider(),
        settingsProvider: MockSettingsProvider(settings: settings),
        notificationCenter: center,
        prayerActivityScheduler: activityScheduler,
        now: { now },
        soundFileResolver: AdhanSoundFileResolver { _ in true }
    )
}

private func fixedDate() -> Date {
    ISO8601DateFormatter().date(from: "2026-05-15T00:00:00Z")!
}

private func makeExistingRequest(identifier: String) -> UNNotificationRequest {
    UNNotificationRequest(
        identifier: identifier,
        content: UNMutableNotificationContent(),
        trigger: nil
    )
}

private struct MockPrayerTimesProvider: PrayerTimesProviding {
    func dayTimes(
        for date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> DayPrayerTimes {
        let dayStart = Calendar.gregorianUTC.startOfDay(for: date)
        return DayPrayerTimes(
            date: dayStart,
            timeZoneIdentifier: timeZone.identifier,
            coordinates: coordinates,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule,
            fajr: PrayerTime(prayer: .fajr, scheduledTime: dayStart.addingTimeInterval(5 * 3_600)),
            dhuhr: PrayerTime(prayer: .dhuhr, scheduledTime: dayStart.addingTimeInterval(12 * 3_600)),
            asr: PrayerTime(prayer: .asr, scheduledTime: dayStart.addingTimeInterval(15 * 3_600)),
            maghrib: PrayerTime(prayer: .maghrib, scheduledTime: dayStart.addingTimeInterval(19 * 3_600)),
            isha: PrayerTime(prayer: .isha, scheduledTime: dayStart.addingTimeInterval(21 * 3_600)),
            sunrise: dayStart.addingTimeInterval(6 * 3_600),
            middleOfTheNight: dayStart.addingTimeInterval(24 * 3_600),
            lastThirdOfTheNight: dayStart.addingTimeInterval(26 * 3_600)
        )
    }

    func nextPrayer(
        from referenceDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> PrayerTime {
        try dayTimes(
            for: referenceDate,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule
        ).fajr
    }

    func currentPrayer(
        at referenceDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> PrayerTime? {
        nil
    }

    func dayTimesRange(
        from startDate: Date,
        to endDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> [DayPrayerTimes] {
        var days: [DayPrayerTimes] = []
        var cursor = Calendar.gregorianUTC.startOfDay(for: startDate)
        let finalDay = Calendar.gregorianUTC.startOfDay(for: endDate)

        while cursor <= finalDay {
            days.append(try dayTimes(
                for: cursor,
                coordinates: coordinates,
                timeZone: timeZone,
                calculationMethod: calculationMethod,
                madhab: madhab,
                highLatitudeRule: highLatitudeRule
            ))
            cursor = Calendar.gregorianUTC.date(byAdding: .day, value: 1, to: cursor)!
        }

        return days
    }
}

private struct MockLocationProvider: LocationProviding {
    func currentAuthorization() async -> LocationAuthorization {
        .authorizedWhenInUse
    }

    func requestWhenInUseAuthorization() async throws -> LocationAuthorization {
        .authorizedWhenInUse
    }

    func requestAlwaysAuthorization() async throws -> LocationAuthorization {
        .authorizedAlways
    }

    func authorizationUpdates() -> AsyncStream<LocationAuthorization> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func currentPlace(timeout: TimeInterval, staleAfter: TimeInterval) async throws -> LocatedPlace {
        LocatedPlace(
            coordinates: Coordinates(latitude: 41.8781, longitude: -87.6298),
            timeZone: TimeZone(secondsFromGMT: 0)!,
            cityName: "Chicago",
            countryCode: "US",
            timestamp: fixedDate()
        )
    }

    func significantLocationChanges() -> AsyncStream<LocatedPlace> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func startMonitoringSignificantChanges() async throws {}

    func stopMonitoringSignificantChanges() async {}

    func isHeadingAvailable() -> Bool { false }

    func headingUpdates() async throws -> AsyncStream<HeadingSample> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

private struct MockSettingsProvider: NotificationSettingsProviding {
    let settings: NotificationScheduleSettings

    func currentNotificationSettings() async throws -> NotificationScheduleSettings {
        settings
    }
}

private final class MockNotificationCenter: UserNotificationScheduling, @unchecked Sendable {
    private let authorization: NotificationAuthorizationState
    private var requests: [UNNotificationRequest]
    private var recordedEvents: [NotificationCenterEvent] = []
    private let lock = NSLock()

    init(
        authorization: NotificationAuthorizationState = .authorized,
        existingRequests: [UNNotificationRequest] = []
    ) {
        self.authorization = authorization
        self.requests = existingRequests
    }

    var events: [NotificationCenterEvent] {
        lock.withLock {
            recordedEvents
        }
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorization.allowsScheduling
    }

    func authorizationStatus() async -> NotificationAuthorizationState {
        authorization
    }

    func add(_ request: UNNotificationRequest) async throws {
        lock.withLock {
            recordedEvents.append(.add(request.identifier))
            requests.append(request)
        }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        lock.withLock {
            requests
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        lock.withLock {
            recordedEvents.append(.remove(identifiers.sorted()))
            requests.removeAll { identifiers.contains($0.identifier) }
        }
    }
}

private final class MockPrayerActivityScheduler: PrayerActivityScheduling, @unchecked Sendable {
    struct Request: Equatable {
        let prayer: Prayer
        let scheduledTime: Date
        let startDate: Date
    }

    private var recordedRequests: [Request] = []
    private let lock = NSLock()

    var requests: [Request] {
        lock.withLock { recordedRequests }
    }

    func schedulePrayerActivityStart(
        for prayerTime: PrayerTime,
        in dayTimes: DayPrayerTimes,
        startDate: Date
    ) async throws {
        lock.withLock {
            recordedRequests.append(Request(
                prayer: prayerTime.prayer,
                scheduledTime: prayerTime.scheduledTime,
                startDate: startDate
            ))
        }
        _ = dayTimes
    }
}

private enum NotificationCenterEvent: Equatable {
    case add(String)
    case remove([String])

    var isAdd: Bool {
        if case .add = self {
            true
        } else {
            false
        }
    }
}

private extension Calendar {
    static var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
