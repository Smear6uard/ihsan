import Foundation
import IhsanCore
import SwiftData
import SwiftUI

/// Drives the setup conversation. Draft state lives in memory; nothing is
/// persisted until `finish(in:)` on the closing screen, which writes the
/// settings flags and the initial ledger counts in one pass through
/// `QadaLedgerWriter`.
@MainActor @Observable
final class RepairSetupViewModel {
    var path: [RepairSetupStep] = []
    var draft = RepairSetupDraft()

    private(set) var chosePathManually = false

    /// The live estimate, recomputed from the draft on every read. The review
    /// and arithmetic views render these exact fields — the displayed math is
    /// the computed math.
    var estimate: QadaEstimate {
        QadaEstimator.estimate(
            QadaEstimateInput(
                birthDate: draft.birthDate,
                accountabilityAgeYears: draft.accountabilityAgeYears,
                consistentPrayerBegan: draft.consistentPrayerBegan,
                averageExcusedDaysPerMonth: draft.averageExcusedDaysPerMonth,
                includeWitr: draft.tracksWitr
            ),
            calendar: .current
        )
    }

    func beginManualPath() {
        chosePathManually = true
        path = [.manualCounts]
    }

    func beginEstimatePath() {
        chosePathManually = false
        path = [.birthDate]
    }

    func goNext(from step: RepairSetupStep) {
        switch step {
        case .manualCounts, .review:
            path.append(.witr)
        case .birthDate:
            path.append(.accountabilityAge)
        case .accountabilityAge:
            path.append(.prayerBegan)
        case .prayerBegan:
            path.append(.excusedDays)
        case .excusedDays:
            path.append(.review)
        case .witr:
            path.append(.missedFlow)
        case .missedFlow:
            path.append(.closing)
        case .closing:
            break
        }
    }

    /// The counts that will seed the ledger, from whichever path was taken.
    var finalCounts: [QadaCategory: Int] {
        var counts: [QadaCategory: Int]
        if chosePathManually {
            counts = draft.manualCounts
            if draft.tracksWitr {
                counts[.witr] = draft.witrManualCount
            }
        } else {
            counts = estimate.perCategory
        }
        return counts
    }

    func finish(in context: ModelContext) throws {
        let settings = try UserSettings.fetchOrCreate(in: context)
        settings.qadaTrackingEnabled = true
        settings.qadaTracksWitr = draft.tracksWitr
        settings.qadaMissedFlowEnabled = draft.missedFlowEnabled
        settings.qadaSetupCompletedAt = .now
        settings.modifiedAt = .now

        try QadaLedgerWriter().recordEstimate(
            finalCounts,
            sourceSurface: .app,
            in: context
        )
    }
}
