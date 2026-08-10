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
    let firstIsha = try #require(activityScheduler.requests.first { $0.prayer == .isha })
    #expect(firstIsha.windowEnd == firstIsha.scheduledTime.addingTimeInterval(8 * 3_600))

    let pending = await center.pendingNotificationRequests()
    #expect(pending.count == 71)
    #expect(pending.contains { $0.identifier == "unrelated.notification" })
}

@Test
func theDawnVariantIsOfferedForFajrAndNowhereElse() {
    #expect(AdhanSoundCatalog.options(for: .fajr).contains(.chimeDawn))
    for prayer in Prayer.allCases where prayer != .fajr {
        #expect(!AdhanSoundCatalog.options(for: prayer).contains(.chimeDawn))
    }
    // Every prayer can always be chimed or silenced.
    for prayer in Prayer.allCases {
        #expect(AdhanSoundCatalog.options(for: prayer).contains(.chime))
        #expect(AdhanSoundCatalog.options(for: prayer).contains(.silent))
    }
}

@Test
func silenceIsHonouredRatherThanReplacedBySystemDefault() {
    let content = NotificationContent.makeAdhanContent(
        prayer: .dhuhr,
        scheduledDate: fixedDate(),
        timeZone: TimeZone(secondsFromGMT: 0)!,
        soundChoice: .silent,
        isTimeSensitive: false,
        soundFileResolver: .allPresent
    )

    #expect(content.sound == nil, "Silent must mean silent, not the system tri-tone.")
    #expect(content.userInfo[ScheduledNotificationUserInfoKey.soundFileName] == nil)
    #expect(content.userInfo[ScheduledNotificationUserInfoKey.soundChoice] as? String == "silent")
}

@Test
func aChoiceWhoseRecordingIsMissingFallsBackToTheChime() {
    // Only the chime is in the bundle — the state this build ships in.
    let onlyChime = AdhanSoundFileResolver { $0 == AdhanAsset.chime }

    #expect(AdhanSoundCatalog.takbirat.resolvedFileName(using: onlyChime) == AdhanAsset.chime)
    #expect(AdhanSoundCatalog.takbirat.awaitsRecording(using: onlyChime))
    #expect(!AdhanSoundCatalog.chime.awaitsRecording(using: onlyChime))
    #expect(AdhanSoundCatalog.silent.resolvedFileName(using: onlyChime) == nil)
    #expect(!AdhanSoundCatalog.silent.awaitsRecording(using: onlyChime))

    let content = NotificationContent.makeAdhanContent(
        prayer: .fajr,
        scheduledDate: fixedDate(),
        timeZone: TimeZone(secondsFromGMT: 0)!,
        soundChoice: .takbirat,
        isTimeSensitive: false,
        soundFileResolver: onlyChime
    )
    #expect(content.userInfo[ScheduledNotificationUserInfoKey.soundFileName] as? String == AdhanAsset.chime)
    #expect(content.sound != nil)
}

@Test
func nothingBreaksThroughFocusUnlessAsked() {
    let quiet = NotificationContent.makeAdhanContent(
        prayer: .asr,
        scheduledDate: fixedDate(),
        timeZone: TimeZone(secondsFromGMT: 0)!,
        soundChoice: .chime,
        isTimeSensitive: false,
        soundFileResolver: .allPresent
    )
    #expect(quiet.interruptionLevel == .active)

    let asked = NotificationContent.makeAdhanContent(
        prayer: .fajr,
        scheduledDate: fixedDate(),
        timeZone: TimeZone(secondsFromGMT: 0)!,
        soundChoice: .chimeDawn,
        isTimeSensitive: true,
        soundFileResolver: .allPresent
    )
    #expect(asked.interruptionLevel == .timeSensitive)
}

@Test
func everyPrayerNotificationCarriesThePlayAdhanCategory() {
    let content = NotificationContent.makeAdhanContent(
        prayer: .maghrib,
        scheduledDate: fixedDate(),
        timeZone: TimeZone(secondsFromGMT: 0)!,
        soundChoice: .chime,
        isTimeSensitive: false,
        soundFileResolver: .allPresent
    )
    #expect(content.categoryIdentifier == NotificationCategory.prayer)
}

@Test
func anExcusedPauseSchedulesNothingAndLeavesEveryPreferenceIntact() async throws {
    let center = MockNotificationCenter(existingRequests: [
        makeExistingRequest(identifier: "ihsan.prayer.fajr.1")
    ])
    let settings = UserSettings()
    settings.setSound(.takbirat, for: .fajr)
    settings.setTimeSensitive(true, for: .fajr)

    let paused = NotificationScheduleSettings(userSettings: settings, isPaused: true)
    #expect(paused.notificationsEnabled)
    #expect(paused.prayerNotificationsSuppressed)

    let activityScheduler = MockPrayerActivityScheduler()
    let scheduler = makeScheduler(
        now: fixedDate(),
        center: center,
        settings: paused,
        activityScheduler: activityScheduler
    )
    try await scheduler.rebuildSchedule()

    let added = center.events.filter(\.isAdd)
    #expect(added.isEmpty, "A pause must schedule nothing at all.")
    let scheduled = await scheduler.scheduledNotifications()
    #expect(scheduled.isEmpty)
    #expect(activityScheduler.cancelCount == 1)

    // And the preferences it suppressed are untouched, so they come
    // back exactly as they were when the pause ends.
    #expect(settings.sound(for: .fajr) == .takbirat)
    #expect(settings.isTimeSensitive(.fajr))
    let resumed = NotificationScheduleSettings(userSettings: settings, isPaused: false)
    #expect(resumed.notificationsEnabled)
    #expect(!resumed.prayerNotificationsSuppressed)
    #expect(resumed.preference(for: .fajr).soundChoice == .takbirat)
    #expect(resumed.preference(for: .fajr).isTimeSensitive)
}

@Test
func optedInAdhkarRemindersAreQuietAndFollowTheirWindowOpenings() async throws {
    let center = MockNotificationCenter()
    let settings = NotificationScheduleSettings(
        notificationsEnabled: false,
        morningAdhkarReminderEnabled: true,
        eveningAdhkarReminderEnabled: true
    )
    let scheduler = makeScheduler(now: fixedDate(), center: center, settings: settings)

    try await scheduler.rebuildSchedule()

    let pending = await center.pendingNotificationRequests()
    let adhkar = pending.filter { $0.identifier.hasPrefix("ihsan.adhkar.") }
    #expect(adhkar.count == 28)
    #expect(adhkar.allSatisfy { $0.content.sound == nil })
    #expect(adhkar.allSatisfy { $0.content.categoryIdentifier == NotificationCategory.adhkar })
    #expect(await scheduler.scheduledNotifications().isEmpty)
}

@Test
func perPrayerSoundsSurviveTheRoundTripThroughSettings() {
    let settings = UserSettings()
    settings.setSound(.chimeDawn, for: .fajr)
    settings.setSound(.silent, for: .dhuhr)
    settings.setSound(.takbirat, for: .maghrib)

    #expect(settings.sound(for: .fajr) == .chimeDawn)
    #expect(settings.sound(for: .dhuhr) == .silent)
    #expect(settings.sound(for: .maghrib) == .takbirat)
    #expect(settings.sound(for: .asr) == .chime, "An untouched prayer keeps the chime.")

    // Silencing writes the legacy mute column too, so the two stores
    // can never disagree about whether a prayer makes a sound.
    #expect(!settings.adhanEnabled(for: .dhuhr))
    #expect(settings.adhanEnabled(for: .fajr))

    let schedule = NotificationScheduleSettings(userSettings: settings)
    #expect(schedule.preference(for: .fajr).soundChoice == .chimeDawn)
    #expect(schedule.preference(for: .dhuhr).soundChoice == .silent)
    #expect(schedule.preference(for: .maghrib).soundChoice == .takbirat)
}

@Test
func aPrayerMutedByAnEarlierBuildStaysSilent() {
    let settings = UserSettings()
    // The old vocabulary: a sound name plus a separate mute column.
    settings.setNotificationConfig(
        PrayerNotificationConfig(prayer: .isha, athanSoundName: "standard-long")
    )
    settings.setAdhanEnabled(false, for: .isha)

    #expect(settings.sound(for: .isha) == .silent)
    #expect(NotificationScheduleSettings(userSettings: settings)
        .preference(for: .isha).soundChoice == .silent)
}

@Test
func storedNamesFromEarlierBuildsReadAsSomethingAudible() {
    #expect(AdhanSoundCatalog(userChoice: "default") == .chime)
    #expect(AdhanSoundCatalog(userChoice: "standard-long") == .chime)
    #expect(AdhanSoundCatalog(userChoice: "adhan-standard-long.caf") == .chime)
    #expect(AdhanSoundCatalog(userChoice: "fajr-aware-long") == .chimeDawn)
    #expect(AdhanSoundCatalog(userChoice: "standard-short") == .takbirat)
    #expect(AdhanSoundCatalog(userChoice: "silent") == .silent)
    #expect(AdhanSoundCatalog(userChoice: "who knows") == .chime)
}

@Test
func aPreferencePayloadFromAnEarlierBuildStillDecodes() throws {
    // No `isTimeSensitive` key — exactly what a shipped build wrote.
    let legacy = #"[{"prayer":"fajr","isEnabled":true,"athanSoundName":"standard-long","leadTimeSeconds":300}]"#
    let decoded = try JSONDecoder().decode(
        [PrayerNotificationConfig].self, from: Data(legacy.utf8)
    )

    #expect(decoded.count == 1)
    #expect(decoded[0].leadTimeSeconds == 300)
    #expect(decoded[0].isTimeSensitive == false)
}

@Test
func theGentleWakeAndTheNotificationShareOneTone() {
    #expect(AdhanAsset.nightWake == AdhanAsset.chime)
}

/// `AdhanAsset.nightWake` is a computed alias for the chime and it is THE
/// swap point: when the muezzin-era recordings land, replacing the chime
/// replaces all four anchors with no code change anywhere else. This test
/// exists so the swap point cannot quietly become plural.
@Test
func everyWakeAnchorSharesOneTone() {
    for anchor in WakeAnchor.allCases {
        #expect(WakeSound.assetName(for: anchor) == AdhanAsset.nightWake)
    }
    #expect(Set(WakeAnchor.allCases.map { WakeSound.assetName(for: $0) }).count == 1)
}

@Test
func rebuildScheduleSkipsPrayersDisabledInSettings() async throws {
    let center = MockNotificationCenter()
    let activityScheduler = MockPrayerActivityScheduler()
    let disabledAsrSettings = NotificationScheduleSettings(
        prayerPreferences: Prayer.allCases.map {
            PrayerNotificationPreference(prayer: $0, isEnabled: $0 != .asr, soundChoice: .chime)
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
func rebuildScheduleClearsIhsanRequestsWhenNotificationPermissionIsDenied() async throws {
    let center = MockNotificationCenter(
        authorization: .denied,
        existingRequests: [
            makeExistingRequest(identifier: "ihsan.prayer.fajr.1"),
            makeExistingRequest(identifier: "unrelated.notification"),
        ]
    )
    let scheduler = makeScheduler(now: fixedDate(), center: center)

    try await scheduler.rebuildSchedule()

    #expect(center.events == [.remove(["ihsan.prayer.fajr.1"])])
    let pending = await center.pendingNotificationRequests()
    #expect(pending.map(\.identifier) == ["unrelated.notification"])
}

private func makeScheduler(
    now: Date,
    center: MockNotificationCenter,
    settings: NotificationScheduleSettings = NotificationScheduleSettings(),
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
        highLatitudeRule: HighLatitudeRule,
        tuning: CalculationTuning
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
        highLatitudeRule: HighLatitudeRule,
        tuning: CalculationTuning
    ) throws -> PrayerTime {
        try dayTimes(
            for: referenceDate,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: calculationMethod,
            madhab: madhab,
            highLatitudeRule: highLatitudeRule,
            tuning: tuning
        ).fajr
    }

    func currentPrayer(
        at referenceDate: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule,
        tuning: CalculationTuning
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
        highLatitudeRule: HighLatitudeRule,
        tuning: CalculationTuning
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
                highLatitudeRule: highLatitudeRule,
                tuning: tuning
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
        let windowEnd: Date
        let startDate: Date
    }

    private var recordedRequests: [Request] = []
    private var recordedCancelCount = 0
    private let lock = NSLock()

    var requests: [Request] {
        lock.withLock { recordedRequests }
    }

    var cancelCount: Int {
        lock.withLock { recordedCancelCount }
    }

    func schedulePrayerActivityStart(
        for prayerTime: PrayerTime,
        in dayTimes: DayPrayerTimes,
        windowEnd: Date,
        startDate: Date
    ) async throws {
        lock.withLock {
            recordedRequests.append(Request(
                prayer: prayerTime.prayer,
                scheduledTime: prayerTime.scheduledTime,
                windowEnd: windowEnd,
                startDate: startDate
            ))
        }
        _ = dayTimes
    }

    func cancelAllPrayerActivities() async {
        lock.withLock { recordedCancelCount += 1 }
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

// MARK: - Iqamah reminders
//
// An ordinary notification, not an alarm: it says the congregation is
// about to begin and then gets out of the way.

private func masjidFixture(
    entries: [IqamahEntry],
    leadMinutes: Int = 10,
    name: String? = "Masjid al-Noor",
    khutbah: Int? = nil
) -> MyMasjidSnapshot {
    MyMasjidSnapshot(
        name: name,
        streetLabel: nil,
        entries: Prayer.allCases.map { prayer in
            entries.first { $0.prayer == prayer } ?? IqamahEntry(prayer: prayer)
        },
        jumuahKhutbahMinutesFromMidnight: khutbah,
        reminderLeadMinutes: leadMinutes
    )
}

/// Fire instants recovered from the identifiers, which carry the epoch
/// exactly the way the adhkār reminders' do.
private func iqamahFireDates(
    _ center: MockNotificationCenter,
    prayer: Prayer? = nil
) async -> [Date] {
    let prefix = NotificationScheduler.iqamahNotificationIdentifierPrefix
    return await center.pendingNotificationRequests()
        .map(\.identifier)
        .filter { $0.hasPrefix(prefix) }
        .filter { identifier in
            guard let prayer else { return true }
            return identifier.contains(".\(prayer.rawValue).")
        }
        .compactMap { identifier -> Date? in
            guard let epoch = identifier.split(separator: ".").last.flatMap({ Double($0) })
            else { return nil }
            return Date(timeIntervalSince1970: epoch)
        }
        .sorted()
}

@Test
func iqamahReminderFiresTheConfiguredLeadBeforeTheResolvedIqamah() async throws {
    let center = MockNotificationCenter()
    let scheduler = makeScheduler(
        now: fixedDate(),
        center: center,
        settings: NotificationScheduleSettings(
            myMasjid: masjidFixture(
                entries: [
                    IqamahEntry(
                        prayer: .dhuhr, mode: .offset, offsetMinutes: 20, reminderEnabled: true
                    )
                ],
                leadMinutes: 10
            )
        )
    )

    try await scheduler.rebuildSchedule()

    // Mock Dhuhr is dayStart + 12h; iqamah is +20; the reminder is −10.
    let expected = fixedDate().addingTimeInterval(12 * 3_600 + 10 * 60)
    let fires = await iqamahFireDates(center, prayer: .dhuhr)
    #expect(fires.first == expected)
}

@Test
func iqamahReminderResolvesAFixedTimeRatherThanAnOffset() async throws {
    let center = MockNotificationCenter()
    let scheduler = makeScheduler(
        now: fixedDate(),
        center: center,
        settings: NotificationScheduleSettings(
            myMasjid: masjidFixture(
                entries: [
                    IqamahEntry(
                        prayer: .dhuhr,
                        mode: .fixed,
                        fixedMinutesFromMidnight: 13 * 60 + 30,
                        reminderEnabled: true
                    )
                ],
                leadMinutes: 15
            )
        )
    )

    try await scheduler.rebuildSchedule()

    // 1:30 PM in the place's zone (GMT here), less the 15-minute lead.
    let expected = fixedDate().addingTimeInterval(13 * 3_600 + 15 * 60)
    let fires = await iqamahFireDates(center, prayer: .dhuhr)
    #expect(fires.first == expected)
}

@Test
func iqamahReminderSchedulesOnlyPrayersWhoseReminderIsOn() async throws {
    let center = MockNotificationCenter()
    let scheduler = makeScheduler(
        now: fixedDate(),
        center: center,
        settings: NotificationScheduleSettings(
            myMasjid: masjidFixture(entries: [
                IqamahEntry(
                    prayer: .dhuhr, mode: .offset, offsetMinutes: 20, reminderEnabled: true
                ),
                IqamahEntry(
                    prayer: .asr, mode: .offset, offsetMinutes: 15, reminderEnabled: false
                ),
            ])
        )
    )

    try await scheduler.rebuildSchedule()

    #expect(!(await iqamahFireDates(center, prayer: .dhuhr)).isEmpty)
    #expect((await iqamahFireDates(center, prayer: .asr)).isEmpty)
}

@Test
func iqamahReminderSkipsAnArmedPrayerWithNoTimeSet() async throws {
    let center = MockNotificationCenter()
    let scheduler = makeScheduler(
        now: fixedDate(),
        center: center,
        settings: NotificationScheduleSettings(
            myMasjid: masjidFixture(entries: [
                IqamahEntry(prayer: .dhuhr, mode: .none, reminderEnabled: true)
            ])
        )
    )

    try await scheduler.rebuildSchedule()

    #expect((await iqamahFireDates(center)).isEmpty)
}

/// Rest is rest. A pause suppresses ṣalāh notifications, and the iqamah
/// reminder is one of them.
@Test
func iqamahReminderIsSuppressedByAnOpenPause() async throws {
    let center = MockNotificationCenter()
    let scheduler = makeScheduler(
        now: fixedDate(),
        center: center,
        settings: NotificationScheduleSettings(
            prayerNotificationsSuppressed: true,
            myMasjid: masjidFixture(entries: [
                IqamahEntry(
                    prayer: .dhuhr, mode: .offset, offsetMinutes: 20, reminderEnabled: true
                )
            ])
        )
    )

    try await scheduler.rebuildSchedule()

    #expect((await iqamahFireDates(center)).isEmpty)
}

/// Someone who has already prayed does not need to be called again — and
/// only for the day they logged, not for the whole rolling window.
@Test
func iqamahReminderIsSuppressedForADayAlreadyLogged() async throws {
    let center = MockNotificationCenter()
    let gmt = TimeZone(secondsFromGMT: 0)!
    let todaysDhuhr = fixedDate().addingTimeInterval(12 * 3_600)
    let key = NotificationScheduler.iqamahDayKey(
        prayer: .dhuhr, adhan: todaysDhuhr, timeZone: gmt
    )

    let scheduler = makeScheduler(
        now: fixedDate(),
        center: center,
        settings: NotificationScheduleSettings(
            myMasjid: masjidFixture(entries: [
                IqamahEntry(
                    prayer: .dhuhr, mode: .offset, offsetMinutes: 20, reminderEnabled: true
                )
            ]),
            loggedPrayerKeys: [key]
        )
    )

    try await scheduler.rebuildSchedule()

    let fires = await iqamahFireDates(center, prayer: .dhuhr)
    let todaysReminder = fixedDate().addingTimeInterval(12 * 3_600 + 10 * 60)
    #expect(!fires.contains(todaysReminder))
    // Tomorrow's is untouched: one logged prayer silences one day.
    #expect(fires.contains(todaysReminder.addingTimeInterval(24 * 3_600)))
}

@Test
func iqamahReminderNeedsAMasjid() async throws {
    let center = MockNotificationCenter()
    let scheduler = makeScheduler(
        now: fixedDate(),
        center: center,
        settings: NotificationScheduleSettings(myMasjid: nil)
    )

    try await scheduler.rebuildSchedule()

    #expect((await iqamahFireDates(center)).isEmpty)
}

/// It is a reminder, not a summons. Breaking through Focus belongs to the
/// prayer itself, and only when the user asked for it.
@Test
func iqamahReminderIsNotTimeSensitive() async throws {
    let center = MockNotificationCenter()
    let scheduler = makeScheduler(
        now: fixedDate(),
        center: center,
        settings: NotificationScheduleSettings(
            myMasjid: masjidFixture(entries: [
                IqamahEntry(
                    prayer: .dhuhr, mode: .offset, offsetMinutes: 20, reminderEnabled: true
                )
            ])
        )
    )

    try await scheduler.rebuildSchedule()

    let requests = await center.pendingNotificationRequests().filter {
        $0.identifier.hasPrefix(NotificationScheduler.iqamahNotificationIdentifierPrefix)
    }
    #expect(!requests.isEmpty)
    #expect(requests.allSatisfy { $0.content.interruptionLevel != .timeSensitive })
}

@Test
func iqamahRemindersAreSweptWithTheRestOfTheSchedule() async throws {
    let center = MockNotificationCenter()
    let scheduler = makeScheduler(
        now: fixedDate(),
        center: center,
        settings: NotificationScheduleSettings(
            myMasjid: masjidFixture(entries: [
                IqamahEntry(
                    prayer: .dhuhr, mode: .offset, offsetMinutes: 20, reminderEnabled: true
                )
            ])
        )
    )
    try await scheduler.rebuildSchedule()
    #expect(!(await iqamahFireDates(center)).isEmpty)

    await scheduler.cancelAllScheduledNotifications()

    #expect((await iqamahFireDates(center)).isEmpty)
}

@Test
func iqamahReminderNeverSchedulesAMomentAlreadyPast() async throws {
    let center = MockNotificationCenter()
    let scheduler = makeScheduler(
        now: fixedDate().addingTimeInterval(13 * 3_600),
        center: center,
        settings: NotificationScheduleSettings(
            myMasjid: masjidFixture(entries: [
                IqamahEntry(
                    prayer: .dhuhr, mode: .offset, offsetMinutes: 20, reminderEnabled: true
                )
            ])
        )
    )

    try await scheduler.rebuildSchedule()

    let reference = fixedDate().addingTimeInterval(13 * 3_600)
    #expect((await iqamahFireDates(center)).allSatisfy { $0 > reference })
}
