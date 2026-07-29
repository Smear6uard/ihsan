import Foundation
import SwiftData

/// The single mutation funnel for the makeup ledger. Every surface — setup,
/// the Repair screen, widgets, intents — writes through here so the
/// materialized `QadaLedger` rows and the append-only `QadaEntry` log can
/// never drift apart, missed-flow stays idempotent per day, and paused days
/// never reach the ledger.
@MainActor
public struct QadaLedgerWriter {
    public init() {}

    /// Writes setup's initial per-category counts.
    @discardableResult
    public func recordEstimate(
        _ counts: [QadaCategory: Int],
        sourceSurface: SourceSurface,
        in context: ModelContext
    ) throws -> [QadaEntry] {
        var entries: [QadaEntry] = []
        for (category, count) in counts {
            let entry = QadaEntry.estimated(
                category: category,
                count: count,
                sourceSurface: sourceSurface
            )
            context.insert(entry)
            QadaMath.apply(entry, to: try fetchOrCreateLedger(for: category, in: context))
            entries.append(entry)
        }
        try context.save()
        return entries
    }

    @discardableResult
    public func recordMadeUp(
        category: QadaCategory,
        count: Int = 1,
        date: Date = .now,
        sourceSurface: SourceSurface = .app,
        in context: ModelContext
    ) throws -> QadaEntry {
        let entry = QadaEntry.madeUp(
            category: category,
            count: count,
            date: date,
            sourceSurface: sourceSurface
        )
        context.insert(entry)
        QadaMath.apply(entry, to: try fetchOrCreateLedger(for: category, in: context))
        try context.save()
        return entry
    }

    /// Removes an entry and re-derives its category's ledger row from the
    /// remaining log. Replaying (rather than reverse-applying) restores the
    /// exact prior state even when the entry's application had clamped at
    /// zero.
    public func undo(_ entry: QadaEntry, in context: ModelContext) throws {
        guard let category = entry.category else {
            return
        }

        context.delete(entry)
        let remaining = try entries(for: category, in: context)
        let totals = QadaMath.materialize(remaining)[category] ?? QadaCategoryTotals()
        let ledger = try fetchOrCreateLedger(for: category, in: context)
        ledger.remainingCount = totals.remaining
        ledger.madeUpCount = totals.madeUp
        ledger.modifiedAt = .now
        try context.save()
    }

    @discardableResult
    public func recordAdjustment(
        category: QadaCategory,
        delta: Int,
        reason: String?,
        sourceSurface: SourceSurface = .app,
        in context: ModelContext
    ) throws -> QadaEntry {
        let entry = QadaEntry.adjusted(
            category: category,
            delta: delta,
            reason: reason,
            sourceSurface: sourceSurface
        )
        context.insert(entry)
        QadaMath.apply(entry, to: try fetchOrCreateLedger(for: category, in: context))
        try context.save()
        return entry
    }

    /// Flows one unlogged prayer into the ledger. Returns nil — and writes
    /// nothing — when the day already flowed for this prayer, or when a
    /// pause covers the day.
    @discardableResult
    public func recordMissedFlow(
        prayer: Prayer,
        date: Date,
        sourceSurface: SourceSurface = .app,
        in context: ModelContext
    ) throws -> QadaEntry? {
        let pauses = try context.fetch(FetchDescriptor<PauseInterval>())
        guard !pauses.contains(where: { $0.contains(date) }) else {
            return nil
        }

        let category = QadaCategory(prayer: prayer)
        let alreadyFlowed = try entries(for: category, in: context).contains {
            $0.kind == .missedFlowedIn && $0.forDate.map { flowed in
                Calendar.current.isDate(flowed, inSameDayAs: date)
            } == true
        }
        guard !alreadyFlowed else {
            return nil
        }

        let entry = QadaEntry.missedFlowedIn(
            prayer: prayer,
            date: date,
            sourceSurface: sourceSurface
        )
        context.insert(entry)
        QadaMath.apply(entry, to: try fetchOrCreateLedger(for: category, in: context))
        try context.save()
        return entry
    }

    /// The category to preselect for one-tap logging: highest recent made-up
    /// volume, else the largest remaining count, else nil (nothing tracked).
    public func mostActiveCategory(in context: ModelContext) throws -> QadaCategory? {
        let windowStart = Date.now.addingTimeInterval(-Double(QadaPace.windowDays) * 86_400)
        let allEntries = try context.fetch(FetchDescriptor<QadaEntry>())

        var madeUpByCategory: [QadaCategory: Int] = [:]
        for entry in allEntries where entry.kind == .madeUp && entry.createdAt >= windowStart {
            guard let category = entry.category else { continue }
            madeUpByCategory[category, default: 0] += entry.amount
        }
        if let busiest = madeUpByCategory.max(by: { $0.value < $1.value }) {
            return busiest.key
        }

        let ledgers = try context.fetch(FetchDescriptor<QadaLedger>())
        return ledgers.max { $0.remainingCount < $1.remainingCount }?.category
    }

    /// Re-derives every materialized row from the append-only log. Entries
    /// are the source of truth: a widget or intent process may have
    /// appended while this process held stale rows, and row updates are
    /// last-writer-wins. Called on app foreground so external writes
    /// reconcile instantly.
    public func reconcile(in context: ModelContext) throws {
        let allEntries = try context.fetch(FetchDescriptor<QadaEntry>())
        let totals = QadaMath.materialize(allEntries)

        var touched = false
        for (category, expected) in totals {
            let ledger = try fetchOrCreateLedger(for: category, in: context)
            if ledger.remainingCount != expected.remaining || ledger.madeUpCount != expected.madeUp {
                ledger.remainingCount = expected.remaining
                ledger.madeUpCount = expected.madeUp
                ledger.modifiedAt = .now
                touched = true
            }
        }
        if touched {
            try context.save()
        }
    }

    private func fetchOrCreateLedger(
        for category: QadaCategory,
        in context: ModelContext
    ) throws -> QadaLedger {
        let raw = category.rawValue
        let descriptor = FetchDescriptor<QadaLedger>(
            predicate: #Predicate { $0.categoryRaw == raw }
        )
        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let ledger = QadaLedger(category: category)
        context.insert(ledger)
        return ledger
    }

    private func entries(
        for category: QadaCategory,
        in context: ModelContext
    ) throws -> [QadaEntry] {
        let raw = category.rawValue
        let descriptor = FetchDescriptor<QadaEntry>(
            predicate: #Predicate { $0.categoryRaw == raw }
        )
        return try context.fetch(descriptor)
    }
}
