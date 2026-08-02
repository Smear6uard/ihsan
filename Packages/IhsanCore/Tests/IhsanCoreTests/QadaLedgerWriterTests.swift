import Foundation
import SwiftData
import Testing
@testable import IhsanCore

@MainActor
private func makeContext() throws -> ModelContext {
    let schema = Schema(IhsanSchemaV7.models)
    // Unique store name per test — unnamed in-memory configurations share
    // one backing store within a process, which corrupts parallel runs.
    let configuration = ModelConfiguration(
        UUID().uuidString,
        schema: schema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
    )
    let container = try ModelContainer(for: schema, configurations: configuration)
    return ModelContext(container)
}

@MainActor
private func ledger(for category: QadaCategory, in context: ModelContext) throws -> QadaLedger? {
    let raw = category.rawValue
    let descriptor = FetchDescriptor<QadaLedger>(
        predicate: #Predicate { $0.categoryRaw == raw }
    )
    return try context.fetch(descriptor).first
}

@Test
@MainActor
func recordingEstimateSeedsLedgersAndEntries() throws {
    let context = try makeContext()
    let writer = QadaLedgerWriter()

    try writer.recordEstimate(
        [.fajr: 120, .isha: 80],
        sourceSurface: .app,
        in: context
    )

    #expect(try ledger(for: .fajr, in: context)?.remainingCount == 120)
    #expect(try ledger(for: .isha, in: context)?.remainingCount == 80)
    let entries = try context.fetch(FetchDescriptor<QadaEntry>())
    #expect(entries.count == 2)
    #expect(entries.allSatisfy { $0.kind == .estimated })
}

@Test
@MainActor
func recordingMadeUpUpdatesLedgerAndAppendsEntry() throws {
    let context = try makeContext()
    let writer = QadaLedgerWriter()
    try writer.recordEstimate([.fajr: 10], sourceSurface: .app, in: context)

    try writer.recordMadeUp(category: .fajr, count: 1, in: context)

    let row = try #require(try ledger(for: .fajr, in: context))
    #expect(row.remainingCount == 9)
    #expect(row.madeUpCount == 1)
    let entries = try context.fetch(FetchDescriptor<QadaEntry>())
    #expect(entries.filter { $0.kind == .madeUp }.count == 1)
}

@Test
@MainActor
func recordingMadeUpWithoutLedgerRowCreatesOne() throws {
    let context = try makeContext()
    let writer = QadaLedgerWriter()

    try writer.recordMadeUp(category: .witr, count: 2, in: context)

    let row = try #require(try ledger(for: .witr, in: context))
    #expect(row.remainingCount == 0)
    #expect(row.madeUpCount == 2)
}

@Test
@MainActor
func undoRestoresExactPriorStateEvenAfterClamping() throws {
    let context = try makeContext()
    let writer = QadaLedgerWriter()
    try writer.recordEstimate([.asr: 1], sourceSurface: .app, in: context)
    // Clamps remaining to 0 even though 3 were logged.
    let entry = try writer.recordMadeUp(category: .asr, count: 3, in: context)

    try writer.undo(entry, in: context)

    let row = try #require(try ledger(for: .asr, in: context))
    #expect(row.remainingCount == 1)
    #expect(row.madeUpCount == 0)
    let entries = try context.fetch(FetchDescriptor<QadaEntry>())
    #expect(entries.filter { $0.kind == .madeUp }.isEmpty)
}

@Test
@MainActor
func adjustmentAppendsEntryAndMovesCount() throws {
    let context = try makeContext()
    let writer = QadaLedgerWriter()
    try writer.recordEstimate([.dhuhr: 40], sourceSurface: .app, in: context)

    try writer.recordAdjustment(category: .dhuhr, delta: -15, reason: nil, in: context)

    #expect(try ledger(for: .dhuhr, in: context)?.remainingCount == 25)
}

@Test
@MainActor
func missedFlowIsIdempotentForTheSameDay() throws {
    let context = try makeContext()
    let writer = QadaLedgerWriter()
    let day = Date(timeIntervalSinceReferenceDate: 790_000_000)

    let first = try writer.recordMissedFlow(prayer: .maghrib, date: day, in: context)
    let second = try writer.recordMissedFlow(prayer: .maghrib, date: day, in: context)

    #expect(first != nil)
    #expect(second == nil)
    #expect(try ledger(for: .maghrib, in: context)?.remainingCount == 1)
}

@Test
@MainActor
func missedFlowSkipsDaysCoveredByAPause() throws {
    let context = try makeContext()
    let writer = QadaLedgerWriter()
    let day = Date(timeIntervalSinceReferenceDate: 790_000_000)
    context.insert(PauseInterval(
        startDate: day.addingTimeInterval(-86_400),
        endDate: day.addingTimeInterval(86_400),
        loggedTimeZoneIdentifier: "UTC"
    ))
    try context.save()

    let entry = try writer.recordMissedFlow(prayer: .fajr, date: day, in: context)

    #expect(entry == nil)
    #expect(try ledger(for: .fajr, in: context) == nil)
    #expect(try context.fetch(FetchDescriptor<QadaEntry>()).isEmpty)
}

@Test
@MainActor
func missedFlowSkipsDaysCoveredByAnOpenEndedPause() throws {
    let context = try makeContext()
    let writer = QadaLedgerWriter()
    let day = Date(timeIntervalSinceReferenceDate: 790_000_000)
    context.insert(PauseInterval(
        startDate: day.addingTimeInterval(-86_400),
        loggedTimeZoneIdentifier: "UTC"
    ))
    try context.save()

    let entry = try writer.recordMissedFlow(prayer: .fajr, date: day, in: context)

    #expect(entry == nil)
}

@Test
@MainActor
func mostActiveCategoryPrefersRecentMadeUpVolume() throws {
    let context = try makeContext()
    let writer = QadaLedgerWriter()
    try writer.recordEstimate([.fajr: 50, .isha: 50], sourceSurface: .app, in: context)
    try writer.recordMadeUp(category: .isha, count: 3, in: context)
    try writer.recordMadeUp(category: .fajr, count: 1, in: context)

    #expect(try writer.mostActiveCategory(in: context) == .isha)
}

@Test
@MainActor
func mostActiveCategoryFallsBackToLargestRemaining() throws {
    let context = try makeContext()
    let writer = QadaLedgerWriter()
    try writer.recordEstimate([.dhuhr: 10, .maghrib: 90], sourceSurface: .app, in: context)

    #expect(try writer.mostActiveCategory(in: context) == .maghrib)
}

/// A widget or intent process can append entries while the app holds stale
/// materialized rows (each process saves its own ledger update — last
/// writer wins on the row, never on the log). Reconcile re-derives every
/// row from the append-only log, so the next foreground heals any drift.
@Test
@MainActor
func reconcileHealsMaterializedRowsFromTheLog() throws {
    let context = try makeContext()
    let writer = QadaLedgerWriter()
    try writer.recordEstimate([.fajr: 10], sourceSurface: .app, in: context)
    try writer.recordMadeUp(category: .fajr, count: 2, in: context)

    // Simulate another process's row clobber: the log is right, the row is
    // stale.
    let row = try #require(try ledger(for: .fajr, in: context))
    row.remainingCount = 10
    row.madeUpCount = 0
    try context.save()

    try writer.reconcile(in: context)

    let healed = try #require(try ledger(for: .fajr, in: context))
    #expect(healed.remainingCount == 8)
    #expect(healed.madeUpCount == 2)
}
