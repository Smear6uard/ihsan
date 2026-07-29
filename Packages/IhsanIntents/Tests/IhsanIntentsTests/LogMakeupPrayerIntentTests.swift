import IhsanCore
@testable import IhsanIntents
import SwiftData
import XCTest

final class LogMakeupPrayerIntentTests: XCTestCase {
    @MainActor
    func testLogsOneMakeupThroughTheLedgerFunnel() async throws {
        let context = try await makeContext()
        let settings = try UserSettings.fetchOrCreate(in: context)
        settings.qadaTrackingEnabled = true
        try QadaLedgerWriter().recordEstimate([.fajr: 5], sourceSurface: .app, in: context)

        _ = try await LogMakeupPrayerIntent(category: .fajr).perform()

        let ledgers = try context.fetch(FetchDescriptor<QadaLedger>())
        XCTAssertEqual(ledgers.first?.remainingCount, 4)
        XCTAssertEqual(ledgers.first?.madeUpCount, 1)
        let entries = try context.fetch(FetchDescriptor<QadaEntry>())
            .filter { $0.kind == .madeUp }
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.sourceSurface, .shortcuts)
    }

    @MainActor
    func testDefaultsToTheMostActiveCategory() async throws {
        let context = try await makeContext()
        let settings = try UserSettings.fetchOrCreate(in: context)
        settings.qadaTrackingEnabled = true
        let writer = QadaLedgerWriter()
        try writer.recordEstimate([.fajr: 50, .isha: 50], sourceSurface: .app, in: context)
        try writer.recordMadeUp(category: .isha, count: 3, in: context)

        _ = try await LogMakeupPrayerIntent().perform()

        let raw = QadaCategory.isha.rawValue
        let isha = try context.fetch(FetchDescriptor<QadaLedger>(
            predicate: #Predicate { $0.categoryRaw == raw }
        )).first
        XCTAssertEqual(isha?.remainingCount, 46)
    }

    @MainActor
    func testWritesNothingWhenTrackingIsOff() async throws {
        let context = try await makeContext()

        _ = try await LogMakeupPrayerIntent(category: .fajr).perform()

        XCTAssertTrue(try context.fetch(FetchDescriptor<QadaEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<QadaLedger>()).isEmpty)
    }

    /// The race: a widget-process tap lands while the app is backgrounded
    /// holding its own optimistic edit. The row is last-writer-wins, but
    /// the log is append-only — so the app's next-foreground reconcile
    /// must surface both makeups.
    @MainActor
    func testWidgetTapWhileAppHoldsStaleRowsReconcilesOnForeground() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ihsan-race-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Ihsan.sqlite")

        let schema = Schema(IhsanSchemaV2.models)
        func openContainer() throws -> ModelContainer {
            try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            )
        }

        // The app process seeds and logs one makeup.
        let appContainer = try openContainer()
        let appContext = ModelContext(appContainer)
        let settings = try UserSettings.fetchOrCreate(in: appContext)
        settings.qadaTrackingEnabled = true
        try appContext.save()
        let writer = QadaLedgerWriter()
        try writer.recordEstimate([.fajr: 10], sourceSurface: .app, in: appContext)
        try writer.recordMadeUp(category: .fajr, count: 1, in: appContext)

        // The widget process (its own container on the shared store) runs
        // the intent while the app is backgrounded.
        let widgetContainer = try openContainer()
        await ModelContainerAccess.shared.reset()
        await ModelContainerAccess.shared.setContainer(widgetContainer)
        _ = try await LogMakeupPrayerIntent(category: .fajr).perform()

        // Foreground: a fresh app context reconciles rows from the log.
        let foregroundContext = ModelContext(appContainer)
        try writer.reconcile(in: foregroundContext)

        let raw = QadaCategory.fajr.rawValue
        let row = try XCTUnwrap(foregroundContext.fetch(FetchDescriptor<QadaLedger>(
            predicate: #Predicate { $0.categoryRaw == raw }
        )).first)
        XCTAssertEqual(row.remainingCount, 8)
        XCTAssertEqual(row.madeUpCount, 2)
        let madeUpEntries = try foregroundContext.fetch(FetchDescriptor<QadaEntry>())
            .filter { $0.kind == .madeUp }
        XCTAssertEqual(madeUpEntries.count, 2)
    }
}
