import Foundation
import SwiftData
import Testing
@testable import IhsanCore

private let seededLogID = UUID()
private let seededPauseID = UUID()
private let seededQadaEntryID = UUID()

/// Builds and tears down a V1 container in its own scope so the store closes
/// before the migrating container opens the same file.
private func seedV1Store(at url: URL) throws {
    let schema = Schema(versionedSchema: IhsanSchemaV1.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: configuration)
    let context = ModelContext(container)

    context.insert(IhsanSchemaV1.PrayerLog(
        id: seededLogID,
        prayer: .fajr,
        prayerDate: Date(timeIntervalSinceReferenceDate: 700_000_000),
        loggedTimeZoneIdentifier: "America/Toronto",
        scheduledTime: Date(timeIntervalSinceReferenceDate: 700_000_100),
        prayedAt: Date(timeIntervalSinceReferenceDate: 700_000_200),
        status: .onTime,
        withJamaah: true,
        note: "quiet fajr"
    ))
    context.insert(IhsanSchemaV1.PrayerLog(
        id: UUID(),
        prayer: .isha,
        prayerDate: Date(timeIntervalSinceReferenceDate: 700_040_000),
        loggedTimeZoneIdentifier: "America/Toronto",
        scheduledTime: Date(timeIntervalSinceReferenceDate: 700_040_100),
        status: .late,
        lateBySeconds: 1200
    ))
    context.insert(IhsanSchemaV1.Reflection(
        kind: .daily,
        forDate: Date(timeIntervalSinceReferenceDate: 700_000_000),
        loggedTimeZoneIdentifier: "America/Toronto",
        typedText: "wrote a few lines"
    ))
    context.insert(IhsanSchemaV1.DayRecord(
        forDate: Date(timeIntervalSinceReferenceDate: 700_000_000),
        loggedTimeZoneIdentifier: "America/Toronto",
        isPaused: true
    ))
    context.insert(IhsanSchemaV1.PauseInterval(
        id: seededPauseID,
        startDate: Date(timeIntervalSinceReferenceDate: 699_900_000),
        loggedTimeZoneIdentifier: "America/Toronto",
        note: "resting"
    ))
    context.insert(IhsanSchemaV1.TravelInterval(
        startDate: Date(timeIntervalSinceReferenceDate: 699_000_000),
        endDate: Date(timeIntervalSinceReferenceDate: 699_500_000),
        loggedTimeZoneIdentifier: "America/Toronto",
        toLocationLabel: "Chicago"
    ))
    context.insert(IhsanSchemaV1.PeriodSummary(
        periodKind: .week,
        periodStart: Date(timeIntervalSinceReferenceDate: 699_000_000),
        periodEnd: Date(timeIntervalSinceReferenceDate: 699_600_000),
        loggedTimeZoneIdentifier: "America/Toronto",
        expectedPrayerCount: 35,
        loggedPrayerCount: 31
    ))

    let settings = IhsanSchemaV1.UserSettings()
    settings.hasCompletedOnboarding = true
    settings.notificationsEnabled = false
    settings.lastResolvedCityName = "Toronto"
    context.insert(settings)

    try context.save()
}

/// Seeds a store shaped exactly like a real V2 install — including qada
/// records, an excused pause, and a witr-tracking settings row — using the
/// frozen V2 snapshot types, then closes it.
private func seedV2Store(at url: URL) throws {
    let schema = Schema(versionedSchema: IhsanSchemaV2.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: configuration)
    let context = ModelContext(container)

    context.insert(IhsanSchemaV2.PrayerLog(
        id: seededLogID,
        prayer: .fajr,
        prayerDate: Date(timeIntervalSinceReferenceDate: 700_000_000),
        loggedTimeZoneIdentifier: "America/Toronto",
        scheduledTime: Date(timeIntervalSinceReferenceDate: 700_000_100),
        prayedAt: Date(timeIntervalSinceReferenceDate: 700_000_200),
        status: .onTime,
        withJamaah: true,
        note: "quiet fajr"
    ))
    context.insert(IhsanSchemaV2.PrayerLog(
        id: UUID(),
        prayer: .isha,
        prayerDate: Date(timeIntervalSinceReferenceDate: 700_040_000),
        loggedTimeZoneIdentifier: "America/Toronto",
        scheduledTime: Date(timeIntervalSinceReferenceDate: 700_040_100),
        status: .late,
        lateBySeconds: 1200
    ))
    context.insert(IhsanSchemaV2.PauseInterval(
        id: seededPauseID,
        startDate: Date(timeIntervalSinceReferenceDate: 699_900_000),
        expectedEndDate: Date(timeIntervalSinceReferenceDate: 701_000_000),
        loggedTimeZoneIdentifier: "America/Toronto",
        note: "resting"
    ))

    let ledger = IhsanSchemaV2.QadaLedger(category: .isha, remainingCount: 40)
    ledger.madeUpCount = 3
    context.insert(ledger)
    context.insert(IhsanSchemaV2.QadaEntry(
        id: seededQadaEntryID,
        category: .isha,
        kind: .estimated,
        amount: 40,
        reason: "first estimate"
    ))
    context.insert(IhsanSchemaV2.QadaEntry(
        id: UUID(),
        category: .witr,
        kind: .madeUp,
        amount: 1,
        forDate: Date(timeIntervalSinceReferenceDate: 700_040_000)
    ))

    let settings = IhsanSchemaV2.UserSettings()
    settings.hasCompletedOnboarding = true
    settings.qadaTrackingEnabled = true
    settings.qadaTracksWitr = true
    settings.lastResolvedCityName = "Toronto"
    context.insert(settings)

    try context.save()
}

/// Seeds a store shaped exactly like a real V3 install — prayer logs,
/// the qada ledger, a pause, nafl records, and a sunnah-enabled
/// settings row — using the frozen V3 snapshot types, then closes it.
private func seedV3Store(at url: URL) throws {
    let schema = Schema(versionedSchema: IhsanSchemaV3.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: configuration)
    let context = ModelContext(container)

    context.insert(IhsanSchemaV3.PrayerLog(
        id: seededLogID,
        prayer: .fajr,
        prayerDate: Date(timeIntervalSinceReferenceDate: 700_000_000),
        loggedTimeZoneIdentifier: "America/Toronto",
        scheduledTime: Date(timeIntervalSinceReferenceDate: 700_000_100),
        prayedAt: Date(timeIntervalSinceReferenceDate: 700_000_200),
        status: .onTime,
        withJamaah: true,
        note: "quiet fajr"
    ))
    context.insert(IhsanSchemaV3.PauseInterval(
        id: seededPauseID,
        startDate: Date(timeIntervalSinceReferenceDate: 699_900_000),
        expectedEndDate: Date(timeIntervalSinceReferenceDate: 701_000_000),
        loggedTimeZoneIdentifier: "America/Toronto",
        note: "resting"
    ))

    let ledger = IhsanSchemaV3.QadaLedger(category: .isha, remainingCount: 40)
    ledger.madeUpCount = 3
    context.insert(ledger)
    context.insert(IhsanSchemaV3.QadaEntry(
        id: seededQadaEntryID,
        category: .isha,
        kind: .estimated,
        amount: 40,
        reason: "first estimate"
    ))
    context.insert(IhsanSchemaV3.NaflLog(
        kind: .witr,
        naflDate: Date(timeIntervalSinceReferenceDate: 700_050_000),
        rakahCount: 3
    ))

    let settings = IhsanSchemaV3.UserSettings()
    settings.hasCompletedOnboarding = true
    settings.qadaTrackingEnabled = true
    settings.sunnahLayerEnabled = true
    settings.hijriCalendarOffsetDays = 1
    settings.lastResolvedCityName = "Toronto"
    context.insert(settings)

    try context.save()
}

/// Seeds a store shaped exactly like a real V4 install — the worship
/// layer's own records included — using the frozen V4 snapshot types,
/// then closes it.
private func seedV4Store(at url: URL) throws {
    let schema = Schema(versionedSchema: IhsanSchemaV4.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: configuration)
    let context = ModelContext(container)

    let log = IhsanSchemaV4.PrayerLog()
    log.id = seededLogID
    log.dedupKey = "fajr-2023-03-09"
    log.prayerRaw = Prayer.fajr.rawValue
    log.prayerDate = Date(timeIntervalSinceReferenceDate: 700_000_000)
    log.loggedTimeZoneIdentifier = "America/Toronto"
    log.scheduledTime = Date(timeIntervalSinceReferenceDate: 700_000_100)
    log.prayedAt = Date(timeIntervalSinceReferenceDate: 700_000_200)
    log.statusRaw = PrayerStatus.onTime.rawValue
    log.withJamaah = true
    log.note = "quiet fajr"
    context.insert(log)

    let pause = IhsanSchemaV4.PauseInterval()
    pause.id = seededPauseID
    pause.startDate = Date(timeIntervalSinceReferenceDate: 699_900_000)
    pause.expectedEndDate = Date(timeIntervalSinceReferenceDate: 701_000_000)
    pause.loggedTimeZoneIdentifier = "America/Toronto"
    pause.note = "resting"
    context.insert(pause)

    let ledger = IhsanSchemaV4.QadaLedger()
    ledger.categoryRaw = QadaCategory.isha.rawValue
    ledger.remainingCount = 40
    ledger.madeUpCount = 3
    context.insert(ledger)

    let entry = IhsanSchemaV4.QadaEntry()
    entry.id = seededQadaEntryID
    entry.categoryRaw = QadaCategory.isha.rawValue
    entry.kindRaw = QadaEntryKind.estimated.rawValue
    entry.amount = 40
    entry.reason = "first estimate"
    context.insert(entry)

    let fast = IhsanSchemaV4.FastLog()
    fast.dedupKey = "fast-2023-03-10"
    fast.kindRaw = FastKind.whiteDay.rawValue
    fast.stateRaw = FastState.kept.rawValue
    fast.fastDate = Date(timeIntervalSinceReferenceDate: 700_090_000)
    context.insert(fast)

    let session = IhsanSchemaV4.DhikrSession()
    session.sessionDate = Date(timeIntervalSinceReferenceDate: 700_090_000)
    session.count = 33
    session.phraseRaw = DhikrPhrase.subhanallah.rawValue
    context.insert(session)

    let settings = IhsanSchemaV4.UserSettings()
    settings.hasCompletedOnboarding = true
    settings.calculationMethodRaw = CalculationMethodChoice.karachi.rawValue
    settings.qadaTrackingEnabled = true
    settings.sunnahLayerEnabled = true
    settings.fastingMonThuOfferEnabled = true
    settings.hijriCalendarOffsetDays = 1
    settings.lastResolvedCityName = "Toronto"
    context.insert(settings)

    try context.save()
}

private func withMigratedStore(
    seed: (URL) throws -> Void,
    assertions: (ModelContext) throws -> Void
) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ihsan-migration-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeURL = directory.appendingPathComponent("Ihsan.sqlite")

    try seed(storeURL)

    let schema = Schema(versionedSchema: IhsanSchemaV10.self)
    let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
    let container = try ModelContainer(
        for: schema,
        migrationPlan: IhsanMigrationPlan.self,
        configurations: configuration
    )
    try assertions(ModelContext(container))
}

// Each migration test runs in its own child process (exit test): SwiftData
// caches entity metadata per class *name* process-wide, so the frozen V1 and
// frozen V2 snapshots — which deliberately reuse the live entity names —
// would poison each other's containers if seeded in one process.

@Test
func migratingSeededV1StoreToLatestPreservesEveryRecord() async {
    await #expect(processExitsWith: .success) {
        try assertV1StoreMigratesToLatest()
    }
}

@Test
func migratingSeededV2StoreToV3PreservesPrayerLogsQadaEntriesAndPauses() async {
    await #expect(processExitsWith: .success) {
        try assertV2StoreMigratesToV3()
    }
}

@Test
func migratedStoreAcceptsNewNaflAndQadaRecords() async {
    await #expect(processExitsWith: .success) {
        try assertMigratedStoreIsWritable()
    }
}

@Test
func migratingSeededV3StoreToV4PreservesTheLedgerAndAddsTheWorshipTables() async {
    await #expect(processExitsWith: .success) {
        try assertV3StoreMigratesToV4()
    }
}

@Test
func migratingSeededV4StoreToV5PreservesWorshipRecordsAndLandsUntunedCalculation() async {
    await #expect(processExitsWith: .success) {
        try assertV4StoreMigratesToV5()
    }
}

private func assertV4StoreMigratesToV5() throws {
    try withMigratedStore(seed: seedV4Store) { context in
        // Nothing the worship layer wrote may be disturbed by adding
        // calculation depth.
        let logs = try context.fetch(FetchDescriptor<PrayerLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == seededLogID)
        #expect(logs.first?.note == "quiet fajr")

        let ledgers = try context.fetch(FetchDescriptor<QadaLedger>())
        #expect(ledgers.first?.remainingCount == 40)
        #expect(ledgers.first?.madeUpCount == 3)

        let entries = try context.fetch(FetchDescriptor<QadaEntry>())
        #expect(entries.first?.id == seededQadaEntryID)

        let fasts = try context.fetch(FetchDescriptor<FastLog>())
        #expect(fasts.first?.kind == .whiteDay)
        let sessions = try context.fetch(FetchDescriptor<DhikrSession>())
        #expect(sessions.first?.count == 33)

        let pauses = try context.fetch(FetchDescriptor<PauseInterval>())
        #expect(pauses.first?.note == "resting")

        let settings = try #require(try context.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(settings.hasCompletedOnboarding == true)
        #expect(settings.calculationMethod == .karachi)
        #expect(settings.sunnahLayerEnabled == true)
        #expect(settings.fastingMonThuOfferEnabled == true)
        #expect(settings.hijriCalendarOffsetDays == 1)

        // An existing install arrives on the untouched preset: no
        // custom angle, no interval, no offsets. A migration must never
        // silently move someone's prayer times.
        #expect(settings.customFajrAngle == nil)
        #expect(settings.customIshaAngle == nil)
        #expect(settings.customIshaIntervalMinutes == nil)
        #expect(settings.calculationTuning == .standard)
        #expect(settings.calculationTuning.overridesAngles == false)

        // And the new columns are writable, round-tripping through the
        // derived tuning.
        settings.calculationTuning = CalculationTuning(
            fajrAngle: 17.5,
            ishaRule: .intervalMinutes(90),
            offsets: PrayerOffsets(fajr: -2, isha: 3)
        )
        try context.save()

        let reread = try #require(try context.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(reread.calculationTuning.fajrAngle == 17.5)
        #expect(reread.calculationTuning.ishaRule == .intervalMinutes(90))
        #expect(reread.calculationTuning.offsets.fajr == -2)
        #expect(reread.calculationTuning.offsets.isha == 3)
        #expect(reread.calculationTuning.overridesAngles)
    }
}

/// Seeds a store shaped like the build that shipped calculation depth —
/// the version a device could already be sitting at when the sound work
/// arrives.
private func seedV5Store(at url: URL) throws {
    let schema = Schema(versionedSchema: IhsanSchemaV5.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: configuration)
    let context = ModelContext(container)

    let log = IhsanSchemaV5.PrayerLog()
    log.id = seededLogID
    log.dedupKey = "fajr-2023-03-09"
    log.prayerRaw = Prayer.fajr.rawValue
    log.prayerDate = Date(timeIntervalSinceReferenceDate: 700_000_000)
    log.loggedTimeZoneIdentifier = "America/Toronto"
    log.statusRaw = PrayerStatus.onTime.rawValue
    log.note = "quiet fajr"
    context.insert(log)

    let settings = IhsanSchemaV5.UserSettings()
    settings.hasCompletedOnboarding = true
    settings.customFajrAngle = 17.5
    settings.customIshaIntervalMinutes = 90
    settings.prayerOffsetAsrMinutes = 3
    settings.lastResolvedCityName = "Toronto"
    context.insert(settings)

    try context.save()
}

@Test
func migratingSeededV5StoreToV6KeepsCalculationDepthAndLandsSilentModeOff() async {
    await #expect(processExitsWith: .success) {
        try assertV5StoreMigratesToV6()
    }
}

private func assertV5StoreMigratesToV6() throws {
    try withMigratedStore(seed: seedV5Store) { context in
        let logs = try context.fetch(FetchDescriptor<PrayerLog>())
        #expect(logs.first?.id == seededLogID)
        #expect(logs.first?.note == "quiet fajr")

        let settings = try #require(try context.fetch(FetchDescriptor<UserSettings>()).first)
        // Calculation depth set at V5 survives untouched: adding a sound
        // preference may not quietly move anybody's prayer times.
        #expect(settings.calculationTuning.fajrAngle == 17.5)
        #expect(settings.calculationTuning.ishaRule == .intervalMinutes(90))
        #expect(settings.calculationTuning.offsets.asr == 3)

        // And the new field lands quiet: the silent switch is honoured
        // until someone says otherwise.
        #expect(settings.adhanPlaysInSilentMode == false)
    }
}

/// A store shaped like a real 1.0.0 install: worship records, the
/// sunnah layer on, a dhikr sitting already recorded.
private func seedV6Store(at url: URL) throws {
    let schema = Schema(versionedSchema: IhsanSchemaV6.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: configuration)
    let context = ModelContext(container)

    let log = IhsanSchemaV6.PrayerLog()
    log.id = seededLogID
    log.dedupKey = "fajr-2023-03-09"
    log.prayerRaw = Prayer.fajr.rawValue
    log.prayerDate = Date(timeIntervalSinceReferenceDate: 700_000_000)
    log.loggedTimeZoneIdentifier = "America/Toronto"
    log.statusRaw = PrayerStatus.onTime.rawValue
    log.withJamaah = true
    log.note = "quiet fajr"
    context.insert(log)

    let dhikr = IhsanSchemaV6.DhikrSession()
    dhikr.sessionDate = Date(timeIntervalSinceReferenceDate: 700_000_000)
    dhikr.count = 66
    dhikr.phraseRaw = DhikrPhrase.subhanallah.rawValue
    context.insert(dhikr)

    let pause = IhsanSchemaV6.PauseInterval()
    pause.id = seededPauseID
    pause.startDate = Date(timeIntervalSinceReferenceDate: 699_900_000)
    pause.note = "resting"
    context.insert(pause)

    let settings = IhsanSchemaV6.UserSettings()
    settings.hasCompletedOnboarding = true
    settings.sunnahLayerEnabled = true
    settings.sunnahDuhaEnabled = true
    settings.adhanPlaysInSilentMode = true
    settings.lastResolvedCityName = "Toronto"
    context.insert(settings)

    try context.save()
}

@Test
func migratingSeededV6StoreToV7KeepsEveryRecordAndLandsAdhkarOff() async {
    await #expect(processExitsWith: .success) {
        try assertV6StoreMigratesToV7()
    }
}

private func assertV6StoreMigratesToV7() throws {
    try withMigratedStore(seed: seedV6Store) { context in
        // Nothing a person recorded may be disturbed by adding a
        // remembrance table.
        let logs = try context.fetch(FetchDescriptor<PrayerLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == seededLogID)
        #expect(logs.first?.note == "quiet fajr")
        #expect(logs.first?.withJamaah == true)

        let dhikr = try context.fetch(FetchDescriptor<DhikrSession>())
        #expect(dhikr.count == 1)
        #expect(dhikr.first?.count == 66)

        let pauses = try context.fetch(FetchDescriptor<PauseInterval>())
        #expect(pauses.first?.id == seededPauseID)
        #expect(pauses.first?.note == "resting")

        let settings = try #require(try context.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(settings.hasCompletedOnboarding == true)
        #expect(settings.sunnahLayerEnabled == true)
        #expect(settings.adhanPlaysInSilentMode == true)

        // Every adhkar preference lands off, exactly like the sunnah
        // layer did. Nobody is opted into a new surface by upgrading.
        #expect(settings.adhkarLayerEnabled == false)
        #expect(settings.adhkarMorningEnabled == false)
        #expect(settings.adhkarEveningEnabled == false)
        #expect(settings.adhkarPostPrayerEnabled == false)
        #expect(settings.adhkarSleepEnabled == false)
        // …except the reading aid, which is on so the surface is
        // usable the first time it is opened.
        #expect(settings.adhkarShowsTransliteration == true)
        // Neutral window bounds.
        #expect(settings.adhkarMorningEndsAfterSunriseMinutes == 90)
        #expect(settings.adhkarEveningExtendsAfterMaghribMinutes == 60)

        // The new table exists, empty and writable.
        #expect(try context.fetch(FetchDescriptor<AdhkarSession>()).isEmpty)
        context.insert(AdhkarSession(
            sessionDate: Date(timeIntervalSinceReferenceDate: 700_000_000),
            category: .morning,
            completedItemCount: 11
        ))
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<AdhkarSession>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.category == .morning)
        #expect(sessions.first?.completedItemCount == 11)
    }
}

private func assertV3StoreMigratesToV4() throws {
    try withMigratedStore(seed: seedV3Store) { context in
        // The prayer ledger comes through intact — the fasting
        // extension may not disturb a single existing record.
        let logs = try context.fetch(FetchDescriptor<PrayerLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.id == seededLogID)
        #expect(logs.first?.note == "quiet fajr")
        #expect(logs.first?.withJamaah == true)

        let ledgers = try context.fetch(FetchDescriptor<QadaLedger>())
        #expect(ledgers.count == 1)
        #expect(ledgers.first?.category == .isha)
        #expect(ledgers.first?.remainingCount == 40)
        #expect(ledgers.first?.madeUpCount == 3)

        let entries = try context.fetch(FetchDescriptor<QadaEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.id == seededQadaEntryID)
        #expect(entries.first?.reason == "first estimate")

        let nafl = try context.fetch(FetchDescriptor<NaflLog>())
        #expect(nafl.count == 1)
        #expect(nafl.first?.kind == .witr)
        #expect(nafl.first?.rakahCount == 3)

        let pauses = try context.fetch(FetchDescriptor<PauseInterval>())
        #expect(pauses.first?.note == "resting")

        let settings = try #require(try context.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(settings.hasCompletedOnboarding == true)
        #expect(settings.qadaTrackingEnabled == true)
        #expect(settings.sunnahLayerEnabled == true)
        #expect(settings.hijriCalendarOffsetDays == 1)
        // Every V4 field lands with its quiet default: rhythms and
        // overlays are off.
        #expect(settings.fastingMonThuOfferEnabled == false)
        #expect(settings.fastingWhiteDaysOfferEnabled == false)
        #expect(settings.pathDhikrOverlayEnabled == false)

        // The new tables exist, empty and writable.
        #expect(try context.fetch(FetchDescriptor<FastLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DhikrSession>()).isEmpty)

        context.insert(FastLog(
            kind: .whiteDay,
            state: .intended,
            fastDate: Date(timeIntervalSinceReferenceDate: 700_100_000)
        ))
        context.insert(DhikrSession(
            sessionDate: Date(timeIntervalSinceReferenceDate: 700_100_000),
            count: 33,
            phrase: .subhanallah
        ))
        context.insert(QadaEntry.estimated(category: .fasting, count: 12))
        try context.save()

        let fasts = try context.fetch(FetchDescriptor<FastLog>())
        #expect(fasts.first?.kind == .whiteDay)
        #expect(fasts.first?.state == .intended)
        let sessions = try context.fetch(FetchDescriptor<DhikrSession>())
        #expect(sessions.first?.count == 33)
        let fastingEntries = try context.fetch(FetchDescriptor<QadaEntry>())
            .filter { $0.category == .fasting }
        #expect(fastingEntries.count == 1)
    }
}

private func assertV1StoreMigratesToLatest() throws {
    try withMigratedStore(seed: seedV1Store) { context in
        let logs = try context.fetch(FetchDescriptor<PrayerLog>(sortBy: [SortDescriptor(\.prayerDate)]))
        #expect(logs.count == 2)
        let fajr = try #require(logs.first)
        #expect(fajr.id == seededLogID)
        #expect(fajr.prayerRaw == Prayer.fajr.rawValue)
        #expect(fajr.statusRaw == PrayerStatus.onTime.rawValue)
        #expect(fajr.withJamaah == true)
        #expect(fajr.note == "quiet fajr")
        #expect(logs.last?.lateBySeconds == 1200)

        let reflections = try context.fetch(FetchDescriptor<Reflection>())
        #expect(reflections.count == 1)
        #expect(reflections.first?.typedText == "wrote a few lines")

        let dayRecords = try context.fetch(FetchDescriptor<DayRecord>())
        #expect(dayRecords.count == 1)
        #expect(dayRecords.first?.isPaused == true)

        let pauses = try context.fetch(FetchDescriptor<PauseInterval>())
        #expect(pauses.count == 1)
        let pause = try #require(pauses.first)
        #expect(pause.id == seededPauseID)
        #expect(pause.note == "resting")
        #expect(pause.endDate == nil)
        #expect(pause.expectedEndDate == nil)

        let travels = try context.fetch(FetchDescriptor<TravelInterval>())
        #expect(travels.count == 1)
        #expect(travels.first?.toLocationLabel == "Chicago")

        let summaries = try context.fetch(FetchDescriptor<PeriodSummary>())
        #expect(summaries.count == 1)
        #expect(summaries.first?.expectedPrayerCount == 35)
        #expect(summaries.first?.loggedPrayerCount == 31)

        let allSettings = try context.fetch(FetchDescriptor<UserSettings>())
        #expect(allSettings.count == 1)
        let settings = try #require(allSettings.first)
        #expect(settings.hasCompletedOnboarding == true)
        #expect(settings.notificationsEnabled == false)
        #expect(settings.lastResolvedCityName == "Toronto")
        #expect(settings.qadaTrackingEnabled == false)
        #expect(settings.qadaTracksWitr == false)
        #expect(settings.qadaMissedFlowEnabled == false)
        #expect(settings.qadaPathCardDismissed == false)
        #expect(settings.qadaDailyIntentionEnabled == false)
        #expect(settings.qadaSetupCompletedAt == nil)

        #expect(try context.fetch(FetchDescriptor<QadaLedger>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<QadaEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<NaflLog>()).isEmpty)
    }
}

private func assertV2StoreMigratesToV3() throws {
    try withMigratedStore(seed: seedV2Store) { context in
        let logs = try context.fetch(FetchDescriptor<PrayerLog>(sortBy: [SortDescriptor(\.prayerDate)]))
        #expect(logs.count == 2)
        let fajr = try #require(logs.first)
        #expect(fajr.id == seededLogID)
        #expect(fajr.note == "quiet fajr")
        #expect(logs.last?.lateBySeconds == 1200)

        let pauses = try context.fetch(FetchDescriptor<PauseInterval>())
        #expect(pauses.count == 1)
        let pause = try #require(pauses.first)
        #expect(pause.id == seededPauseID)
        #expect(pause.note == "resting")
        #expect(pause.expectedEndDate == Date(timeIntervalSinceReferenceDate: 701_000_000))
        #expect(pause.isActive)

        let entries = try context.fetch(FetchDescriptor<QadaEntry>(sortBy: [SortDescriptor(\.categoryRaw)]))
        #expect(entries.count == 2)
        let estimate = try #require(entries.first { $0.id == seededQadaEntryID })
        #expect(estimate.category == .isha)
        #expect(estimate.kind == .estimated)
        #expect(estimate.amount == 40)
        #expect(estimate.reason == "first estimate")
        let witr = try #require(entries.first { $0.id != seededQadaEntryID })
        #expect(witr.category == .witr)
        #expect(witr.kind == .madeUp)

        let ledgers = try context.fetch(FetchDescriptor<QadaLedger>())
        #expect(ledgers.count == 1)
        #expect(ledgers.first?.category == .isha)
        #expect(ledgers.first?.remainingCount == 40)
        #expect(ledgers.first?.madeUpCount == 3)

        let settings = try #require(try context.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(settings.qadaTrackingEnabled == true)
        #expect(settings.qadaTracksWitr == true)
        // Every V3 field lands with its quiet default: the sunnah layer is off.
        #expect(settings.sunnahLayerEnabled == false)
        #expect(settings.sunnahRawatibEnabled == false)
        #expect(settings.sunnahDuhaEnabled == false)
        #expect(settings.sunnahNightEnabled == false)
        #expect(settings.sunnahRakahCountsEnabled == false)
        #expect(settings.pathNaflOverlayEnabled == false)
        #expect(settings.nightWakeEnabled == false)
        #expect(settings.nightWakeOffsetMinutes == 0)
        #expect(settings.duhaSunriseOffsetMinutes == 20)
        #expect(settings.duhaDhuhrMarginMinutes == 15)
        // Compare decoded configs, not raw JSON — encoder key order is
        // not part of the contract.
        let storedConfigs = try JSONDecoder().decode(
            [RawatibConfig].self,
            from: #require(settings.rawatibConfigJSON.data(using: .utf8))
        )
        let defaultConfigs = try JSONDecoder().decode(
            [RawatibConfig].self,
            from: #require(UserSettings.defaultRawatibConfigJSON.data(using: .utf8))
        )
        #expect(storedConfigs == defaultConfigs)

        #expect(try context.fetch(FetchDescriptor<NaflLog>()).isEmpty)
    }
}

private func assertMigratedStoreIsWritable() throws {
    try withMigratedStore(seed: seedV2Store) { context in
        context.insert(QadaEntry.estimated(category: .fajr, count: 120))
        context.insert(NaflLog(
            kind: .witr,
            naflDate: Date(timeIntervalSinceReferenceDate: 700_100_000),
            rakahCount: 3
        ))
        try context.save()

        let entries = try context.fetch(FetchDescriptor<QadaEntry>())
        #expect(entries.count == 3)

        let nafl = try #require(try context.fetch(FetchDescriptor<NaflLog>()).first)
        #expect(nafl.kind == .witr)
        #expect(nafl.rakahCount == 3)
    }
}

// MARK: - V7 → V8: the cycle reattribution
//
// A store shaped like a real pre-corrective install, where the day
// rolled at midnight: a 1 AM Isha filed on the wrong date and — having
// been judged against a window twenty hours away — stored as qadā;
// post-midnight qiyam and witr on the wrong night; a sitting at the
// tasbīḥ after midnight; and the awkward case, a post-midnight Isha
// whose rightful cycle is already occupied.
//
// The migration itself only adds a field. The repair runs afterwards
// with a schedule the caller supplies, because Fajr needs coordinates
// and coordinates are never stored.

/// A UTC calendar, so the fixture's days and the sweep's agree.
private var sweepCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func utcDay(_ year: Int, _ month: Int, _ day: Int) -> Date {
    sweepCalendar.date(from: DateComponents(year: year, month: month, day: day))!
}

private func utcAt(_ day: Date, _ hour: Int, _ minute: Int) -> Date {
    day.addingTimeInterval(TimeInterval(hour * 3600 + minute * 60))
}

/// Constant boundaries: Fajr at 04:40, Isha at 21:14. Real schedules
/// drift by minutes across a week; the rule under test does not care,
/// and a constant makes every expectation in the fixture exact.
private func fixtureBoundaries(_ day: Date) -> CycleDayBoundaries {
    CycleDayBoundaries(
        fajr: utcAt(day, 4, 40),
        isha: utcAt(day, 21, 14),
        nextFajr: utcAt(day.addingTimeInterval(86_400), 4, 40)
    )
}

private let eveningA = utcDay(2026, 8, 4)     // the cycle a 1 AM Isha belongs to
private let morningB = utcDay(2026, 8, 5)     // where the midnight rule filed it
private let plainDay = utcDay(2026, 8, 1)     // an ordinary evening Isha
private let collisionEvening = utcDay(2026, 7, 28)
private let collisionMorning = utcDay(2026, 7, 29)

private func seedV7Store(at url: URL) throws {
    let schema = Schema(versionedSchema: IhsanSchemaV7.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: configuration)
    let context = ModelContext(container)

    func isha(
        day: Date, loggedAt: Date, status: PrayerStatus, id: UUID = UUID()
    ) -> IhsanSchemaV7.PrayerLog {
        let log = IhsanSchemaV7.PrayerLog()
        log.id = id
        log.dedupKey = "isha-\(iso(day))"
        log.prayerRaw = Prayer.isha.rawValue
        log.prayerDate = day
        log.loggedTimeZoneIdentifier = "UTC"
        log.scheduledTime = utcAt(day, 21, 14)
        log.loggedAt = loggedAt
        log.statusRaw = status.rawValue
        log.createdAt = loggedAt
        log.modifiedAt = loggedAt
        return log
    }

    // 1. The defect itself: prayed at 1:05 AM inside a window that was
    //    still open, filed on the next day, and marked qadā for it.
    context.insert(isha(
        day: morningB, loggedAt: utcAt(morningB, 1, 5), status: .qada, id: seededLogID
    ))

    // 2. An ordinary evening Isha. Nothing may touch it.
    context.insert(isha(
        day: plainDay, loggedAt: utcAt(plainDay, 21, 40), status: .onTime
    ))

    // 3. The collision: a cycle that already holds its Isha, and a
    //    post-midnight entry that wants the same slot.
    context.insert(isha(
        day: collisionEvening, loggedAt: utcAt(collisionEvening, 21, 30), status: .onTime
    ))
    context.insert(isha(
        day: collisionMorning, loggedAt: utcAt(collisionMorning, 0, 50), status: .missed
    ))

    // 4. Night nafl, filed on the morning the clock had reached.
    for kind in [NaflKind.qiyam, .witr] {
        let nafl = IhsanSchemaV7.NaflLog()
        nafl.dedupKey = "\(kind.storageKey)-\(iso(morningB))"
        nafl.kindRaw = kind.storageKey
        nafl.naflDate = morningB
        nafl.loggedAt = utcAt(morningB, 2, 30)
        nafl.loggedTimeZoneIdentifier = "UTC"
        context.insert(nafl)
    }

    // 5. Duha on the same morning — a daytime kind, and untouchable.
    let duha = IhsanSchemaV7.NaflLog()
    duha.dedupKey = "duha-\(iso(morningB))"
    duha.kindRaw = NaflKind.duha.storageKey
    duha.naflDate = morningB
    duha.loggedAt = utcAt(morningB, 10, 0)
    duha.loggedTimeZoneIdentifier = "UTC"
    context.insert(duha)

    // 6. A sitting at the tasbīḥ after midnight.
    let dhikr = IhsanSchemaV7.DhikrSession()
    dhikr.sessionDate = morningB
    dhikr.startedAt = utcAt(morningB, 1, 30)
    dhikr.count = 100
    dhikr.phraseRaw = DhikrPhrase.subhanallah.rawValue
    context.insert(dhikr)

    let settings = IhsanSchemaV7.UserSettings()
    settings.hasCompletedOnboarding = true
    settings.sunnahLayerEnabled = true
    settings.lastResolvedCityName = "Toronto"
    context.insert(settings)

    try context.save()
}

private func iso(_ day: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: day)
}

@Test
func migratingSeededV7StoreToV8PreservesEveryRecordAndReattributesTheCycle() async {
    // The child's stdout is observed and echoed so the reattribution
    // report lands in THIS test's output. A repair that rewrites
    // worship records has to say what it did somewhere a person will
    // actually read.
    let result = await #expect(
        processExitsWith: .success, observing: [\.standardOutputContent]
    ) {
        try assertV7StoreMigratesToV8()
    }
    if let output = result?.standardOutputContent {
        let text = String(decoding: output, as: UTF8.self)
        for line in text.split(separator: "\n") where line.contains("[migration]") {
            print(line)
        }
    }
}

private func assertV7StoreMigratesToV8() throws {
    try withMigratedStore(seed: seedV7Store) { context in
        // Zero loss first: the field added by V8 disturbs nothing.
        #expect(try context.fetch(FetchDescriptor<PrayerLog>()).count == 4)
        #expect(try context.fetch(FetchDescriptor<NaflLog>()).count == 3)
        #expect(try context.fetch(FetchDescriptor<DhikrSession>()).count == 1)
        let settings = try #require(try context.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(settings.hasCompletedOnboarding == true)
        #expect(settings.sunnahLayerEnabled == true)
        #expect(settings.cycleReattributionVersion == 0)
        #expect(try context.fetch(FetchDescriptor<PrayerLog>()).allSatisfy { $0.reviewFlag == nil })

        let report = try #require(try CycleReattributionSweep(calendar: sweepCalendar)
            .runIfNeeded(
                now: utcAt(utcDay(2026, 8, 6), 12, 0),
                boundaries: fixtureBoundaries,
                in: context
            ))
        // The migration's own record of what it moved. Printed, not
        // just counted: a repair that rewrites worship records without
        // saying so is not one anybody should have to take on trust.
        print("[migration] \(report.summary)")

        #expect(report.prayerLogsMoved == 1)
        #expect(report.statusesRecomputed == ["qada→onTime"])
        #expect(report.naflLogsMoved == 2)
        #expect(report.dhikrSessionsMoved == 1)
        #expect(report.collisionsFlagged == 1)
        #expect(report.daysWithoutSchedule == 0)

        // Nothing was deleted.
        let logs = try context.fetch(FetchDescriptor<PrayerLog>())
        #expect(logs.count == 4)
        #expect(try context.fetch(FetchDescriptor<NaflLog>()).count == 3)
        #expect(try context.fetch(FetchDescriptor<DhikrSession>()).count == 1)

        // The 1 AM Isha now belongs to the evening it was offered in,
        // measured against the window that was open, and is no longer
        // called a makeup.
        let moved = try #require(logs.first { $0.id == seededLogID })
        #expect(moved.prayerDate == eveningA)
        #expect(moved.dedupKey == "isha-2026-08-04")
        #expect(moved.status == .onTime)
        #expect(moved.scheduledTime == utcAt(eveningA, 21, 14))
        #expect(moved.lateBySeconds == nil)
        #expect(moved.reviewFlag == nil)

        // The ordinary evening Isha was not touched.
        let ordinary = try #require(logs.first { $0.prayerDate == plainDay })
        #expect(ordinary.status == .onTime)
        #expect(ordinary.dedupKey == "isha-2026-08-01")
        #expect(ordinary.reviewFlag == nil)

        // The collision: the entry that was already there keeps its
        // place, the one that wanted it keeps its own date and carries
        // the flag, and the person decides.
        let sitting = try #require(logs.first { $0.prayerDate == collisionEvening })
        #expect(sitting.status == .onTime)
        #expect(sitting.reviewFlag == nil)
        let duplicate = try #require(logs.first { $0.prayerDate == collisionMorning })
        #expect(duplicate.reviewFlag == .cycleDuplicate)
        #expect(duplicate.dedupKey == "isha-2026-07-29")

        // Night nafl moved to the night it was offered in; duha did not
        // move, because its window closes long before midnight.
        let nafl = try context.fetch(FetchDescriptor<NaflLog>())
        #expect(nafl.filter { $0.naflDate == eveningA }.count == 2)
        #expect(nafl.first { $0.kind == .duha }?.naflDate == morningB)
        #expect(nafl.first { $0.kind == .witr }?.dedupKey == "witr-2026-08-04")

        // And the sitting at the tasbīḥ.
        #expect(try context.fetch(FetchDescriptor<DhikrSession>()).first?.sessionDate == eveningA)

        // The marker is set, so a second launch does no work.
        #expect(settings.cycleReattributionVersion == CycleReattributionSweep.currentVersion)
        let second = try CycleReattributionSweep(calendar: sweepCalendar).runIfNeeded(
            now: utcAt(utcDay(2026, 8, 6), 12, 5),
            boundaries: fixtureBoundaries,
            in: context
        )
        #expect(second == nil)
    }
}

// MARK: - V8 -> V9: the masjid arrives

private func seedV8Store(at url: URL) throws {
    let schema = Schema(versionedSchema: IhsanSchemaV8.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: configuration)
    let context = ModelContext(container)

    let log = IhsanSchemaV8.PrayerLog()
    log.dedupKey = "fajr-\(iso(plainDay))"
    log.prayerRaw = Prayer.fajr.rawValue
    log.prayerDate = plainDay
    log.loggedTimeZoneIdentifier = "UTC"
    log.scheduledTime = utcAt(plainDay, 5, 12)
    log.loggedAt = utcAt(plainDay, 5, 20)
    log.statusRaw = PrayerStatus.onTime.rawValue
    context.insert(log)

    let settings = IhsanSchemaV8.UserSettings()
    settings.hasCompletedOnboarding = true
    settings.sunnahLayerEnabled = true
    settings.sunnahNightEnabled = true
    settings.nightWakeEnabled = true
    settings.nightWakeOffsetMinutes = 15
    settings.lastResolvedCityName = "Toronto"
    context.insert(settings)

    try context.save()
}

@Test
func migratingSeededV8StoreAddsTheMasjidAndDisturbsNothing() async {
    await #expect(processExitsWith: .success) {
        try assertV8StoreMigratesToV9()
    }
}

private func assertV8StoreMigratesToV9() throws {
    try withMigratedStore(seed: seedV8Store) { context in
        // The new entity arrives empty. Nobody is given a masjid they did
        // not set, and nothing asks them to.
        #expect(try context.fetch(FetchDescriptor<MyMasjid>()).isEmpty)
        #expect(MyMasjid.fetchExisting(in: context) == nil)

        // And the upgrade touches nothing that was already there.
        #expect(try context.fetch(FetchDescriptor<PrayerLog>()).count == 1)
        let settings = try #require(try context.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(settings.hasCompletedOnboarding == true)
        #expect(settings.lastResolvedCityName == "Toronto")
        #expect(settings.nightWakeEnabled == true)
        #expect(settings.nightWakeOffsetMinutes == 15)
    }
}

// MARK: - V9 -> V10: the wake anchors, and the wake that was already set

private func seedV9Store(at url: URL, configuredWake: Bool) throws {
    let schema = Schema(versionedSchema: IhsanSchemaV9.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: configuration)
    let context = ModelContext(container)

    let settings = IhsanSchemaV9.UserSettings()
    settings.hasCompletedOnboarding = true
    settings.sunnahLayerEnabled = configuredWake
    settings.sunnahNightEnabled = configuredWake
    settings.nightWakeEnabled = configuredWake
    settings.nightWakeOffsetMinutes = configuredWake ? 15 : 0
    context.insert(settings)

    let masjid = IhsanSchemaV9.MyMasjid()
    masjid.id = MyMasjid.singletonID
    masjid.name = "Masjid al-Noor"
    masjid.reminderLeadMinutes = 10
    context.insert(masjid)

    try context.save()
}

private func seedV9StoreWithConfiguredWake(at url: URL) throws {
    try seedV9Store(at: url, configuredWake: true)
}

private func seedV9StoreWithNoWake(at url: URL) throws {
    try seedV9Store(at: url, configuredWake: false)
}

/// The one that matters: somebody who set the gentle wake still has it
/// after the upgrade that replaced it, with the same offset.
@Test
func migratingSeededV9StoreKeepsAConfiguredWake() async {
    await #expect(processExitsWith: .success) {
        try withMigratedStore(seed: seedV9StoreWithConfiguredWake) { context in
            let settings = try #require(
                try context.fetch(FetchDescriptor<UserSettings>()).first
            )

            let lastThird = settings.wakeAnchorConfig(for: .lastThird)
            #expect(lastThird.isEnabled)
            #expect(lastThird.offsetMinutes == 15)

            // Nobody is opted into an alarm by an upgrade.
            for anchor in [WakeAnchor.fajrStart, .sunrise, .maghrib] {
                #expect(settings.wakeAnchorConfig(for: anchor).isEnabled == false)
                #expect(settings.wakeAnchorConfig(for: anchor).offsetMinutes == 0)
            }

            // The suggestion has not had its turn yet.
            #expect(settings.suhoorAnchorOfferedAt == nil)

            // And the masjid crossed the stage untouched.
            let masjid = try #require(MyMasjid.fetchExisting(in: context))
            #expect(masjid.name == "Masjid al-Noor")
            #expect(masjid.reminderLeadMinutes == 10)
        }
    }
}

@Test
func migratingSeededV9StoreLeavesAnUnsetWakeOff() async {
    await #expect(processExitsWith: .success) {
        try withMigratedStore(seed: seedV9StoreWithNoWake) { context in
            let settings = try #require(
                try context.fetch(FetchDescriptor<UserSettings>()).first
            )
            for anchor in WakeAnchor.allCases {
                #expect(settings.wakeAnchorConfig(for: anchor).isEnabled == false)
            }
        }
    }
}
