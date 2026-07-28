import Foundation

public struct QadaCategoryTotals: Equatable, Sendable {
    /// Never negative — made-up or adjusted amounts beyond the remaining
    /// count floor at zero rather than going into credit.
    public var remaining: Int
    /// Total prayers made up, unclamped; this drives the Repair thread's
    /// length.
    public var madeUp: Int

    public init(remaining: Int = 0, madeUp: Int = 0) {
        self.remaining = remaining
        self.madeUp = madeUp
    }
}

public enum QadaMath {
    /// Replays the entry log in `createdAt` order and returns totals for
    /// every category that appears in it.
    public static func materialize(_ entries: [QadaEntry]) -> [QadaCategory: QadaCategoryTotals] {
        var totals: [QadaCategory: QadaCategoryTotals] = [:]

        for entry in entries.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard let category = entry.category, let kind = entry.kind else {
                continue
            }

            var current = totals[category] ?? QadaCategoryTotals()
            applyKind(kind, amount: entry.amount, to: &current)
            totals[category] = current
        }

        return totals
    }

    /// Applies a single new entry to its materialized ledger row — the
    /// optimistic-update path. Equivalent to re-materializing with the entry
    /// appended.
    public static func apply(_ entry: QadaEntry, to ledger: QadaLedger) {
        guard let kind = entry.kind else {
            return
        }

        var current = QadaCategoryTotals(
            remaining: ledger.remainingCount,
            madeUp: ledger.madeUpCount
        )
        applyKind(kind, amount: entry.amount, to: &current)
        ledger.remainingCount = current.remaining
        ledger.madeUpCount = current.madeUp
        ledger.modifiedAt = entry.createdAt
    }

    private static func applyKind(
        _ kind: QadaEntryKind,
        amount: Int,
        to totals: inout QadaCategoryTotals
    ) {
        switch kind {
        case .estimated:
            totals.remaining = max(0, amount)
        case .adjusted:
            totals.remaining = max(0, totals.remaining + amount)
        case .madeUp:
            totals.remaining = max(0, totals.remaining - amount)
            totals.madeUp += amount
        case .missedFlowedIn:
            totals.remaining += 1
        }
    }
}
