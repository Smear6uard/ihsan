import Foundation
import Testing
@testable import IhsanCore

private func at(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSinceReferenceDate: seconds)
}

@Test
func estimatedEntrySetsRemaining() {
    let entries = [
        QadaEntry.estimated(category: .fajr, count: 120, createdAt: at(0))
    ]

    let totals = QadaMath.materialize(entries)

    #expect(totals[.fajr]?.remaining == 120)
    #expect(totals[.fajr]?.madeUp == 0)
    #expect(totals[.dhuhr] == nil)
}

@Test
func adjustedDeltaAddsAndSubtracts() {
    let entries = [
        QadaEntry.estimated(category: .asr, count: 50, createdAt: at(0)),
        QadaEntry.adjusted(category: .asr, delta: 10, reason: nil, createdAt: at(1)),
        QadaEntry.adjusted(category: .asr, delta: -20, reason: "recount", createdAt: at(2))
    ]

    let totals = QadaMath.materialize(entries)

    #expect(totals[.asr]?.remaining == 40)
}

@Test
func adjustedDeltaClampsRemainingAtZero() {
    let entries = [
        QadaEntry.estimated(category: .isha, count: 5, createdAt: at(0)),
        QadaEntry.adjusted(category: .isha, delta: -30, reason: nil, createdAt: at(1))
    ]

    let totals = QadaMath.materialize(entries)

    #expect(totals[.isha]?.remaining == 0)
}

@Test
func madeUpDecrementsRemainingAndAccumulates() {
    let entries = [
        QadaEntry.estimated(category: .maghrib, count: 10, createdAt: at(0)),
        QadaEntry.madeUp(category: .maghrib, count: 1, date: at(100), createdAt: at(1)),
        QadaEntry.madeUp(category: .maghrib, count: 3, date: at(200), createdAt: at(2))
    ]

    let totals = QadaMath.materialize(entries)

    #expect(totals[.maghrib]?.remaining == 6)
    #expect(totals[.maghrib]?.madeUp == 4)
}

@Test
func madeUpBeyondRemainingClampsRemainingAtZero() {
    let entries = [
        QadaEntry.estimated(category: .fajr, count: 2, createdAt: at(0)),
        QadaEntry.madeUp(category: .fajr, count: 5, date: at(100), createdAt: at(1))
    ]

    let totals = QadaMath.materialize(entries)

    #expect(totals[.fajr]?.remaining == 0)
    #expect(totals[.fajr]?.madeUp == 5)
}

@Test
func missedFlowedInIncrementsRemainingByOne() {
    let entries = [
        QadaEntry.estimated(category: .dhuhr, count: 0, createdAt: at(0)),
        QadaEntry.missedFlowedIn(prayer: .dhuhr, date: at(100), createdAt: at(1)),
        QadaEntry.missedFlowedIn(prayer: .dhuhr, date: at(200), createdAt: at(2))
    ]

    let totals = QadaMath.materialize(entries)

    #expect(totals[.dhuhr]?.remaining == 2)
}

@Test
func materializeAppliesEntriesInCreationOrderRegardlessOfArrayOrder() {
    let estimated = QadaEntry.estimated(category: .fajr, count: 3, createdAt: at(0))
    let madeUp = QadaEntry.madeUp(category: .fajr, count: 3, date: at(50), createdAt: at(1))
    let flowedIn = QadaEntry.missedFlowedIn(prayer: .fajr, date: at(100), createdAt: at(2))

    let totals = QadaMath.materialize([flowedIn, madeUp, estimated])

    #expect(totals[.fajr]?.remaining == 1)
    #expect(totals[.fajr]?.madeUp == 3)
}

/// The app mutates the materialized ledger row optimistically per entry; this
/// pins that incremental path to the from-scratch derivation.
@Test
func applyingEntriesOneByOneMatchesMaterialize() {
    let entries = [
        QadaEntry.estimated(category: .witr, count: 40, createdAt: at(0)),
        QadaEntry.adjusted(category: .witr, delta: -5, reason: nil, createdAt: at(1)),
        QadaEntry.madeUp(category: .witr, count: 2, date: at(100), createdAt: at(2)),
        QadaEntry.madeUp(category: .witr, count: 50, date: at(200), createdAt: at(3)),
        QadaEntry.adjusted(category: .witr, delta: 4, reason: "found more", createdAt: at(4))
    ]

    let ledger = QadaLedger(category: .witr)
    for entry in entries {
        QadaMath.apply(entry, to: ledger)
    }

    let totals = QadaMath.materialize(entries)

    #expect(ledger.remainingCount == totals[.witr]?.remaining)
    #expect(ledger.madeUpCount == totals[.witr]?.madeUp)
}
