import Foundation
import SwiftData
import Testing
@testable import IhsanCore

private let seededLogID = UUID()
private let seededPauseID = UUID()

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

@Test
func migratingSeededV1StoreToV2PreservesEveryRecord() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ihsan-migration-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeURL = directory.appendingPathComponent("Ihsan.sqlite")

    try seedV1Store(at: storeURL)

    let schema = Schema(versionedSchema: IhsanSchemaV2.self)
    let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
    let container = try ModelContainer(
        for: schema,
        migrationPlan: IhsanMigrationPlan.self,
        configurations: configuration
    )
    let context = ModelContext(container)

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
}

@Test
func migratedStoreAcceptsNewQadaRecords() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ihsan-migration-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeURL = directory.appendingPathComponent("Ihsan.sqlite")

    try seedV1Store(at: storeURL)

    let schema = Schema(versionedSchema: IhsanSchemaV2.self)
    let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
    let container = try ModelContainer(
        for: schema,
        migrationPlan: IhsanMigrationPlan.self,
        configurations: configuration
    )
    let context = ModelContext(container)

    let ledger = QadaLedger(category: .fajr, remainingCount: 120)
    context.insert(ledger)
    context.insert(QadaEntry.estimated(category: .fajr, count: 120))
    try context.save()

    let ledgers = try context.fetch(FetchDescriptor<QadaLedger>())
    #expect(ledgers.first?.category == .fajr)
    #expect(ledgers.first?.remainingCount == 120)
    let entries = try context.fetch(FetchDescriptor<QadaEntry>())
    #expect(entries.first?.kind == .estimated)
    #expect(entries.first?.amount == 120)
}
