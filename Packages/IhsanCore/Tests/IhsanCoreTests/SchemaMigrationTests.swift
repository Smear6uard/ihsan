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

    let schema = Schema(versionedSchema: IhsanSchemaV6.self)
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
