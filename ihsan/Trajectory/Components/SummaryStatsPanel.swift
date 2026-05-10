import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// The "Completed" stats panel at the top of the Trajectory screen.
///
/// Reads as one illuminated parchment page: a small-caps COMPLETED
/// header, then the two headline numbers (overall on-time percentage
/// and jamaʿah count) on either side of a brass ornamental flourish,
/// then a row of three smaller secondary counts beneath (ON TIME,
/// MISSED, QADĀ).
///
/// Replaces the single-line `FactualSummaryLine` from the pre-redirect
/// design. Same data — just presented as a manuscript inscription
/// rather than a dense factual sentence.
struct SummaryStatsPanel: View {
    let aggregate: TrajectoryAggregate

    var body: some View {
        VStack(spacing: IhsanSpacing.md) {
            Text("COMPLETED")
                .font(IhsanFont.inscription)
                .tracking(2.4)
                .foregroundStyle(IhsanColor.brassDark)
                .frame(maxWidth: .infinity, alignment: .leading)

            headlineRow

            OrnamentalDivider()
                .frame(maxWidth: 240)
                .frame(maxWidth: .infinity)

            secondaryRow
        }
        .padding(IhsanSpacing.lg)
        .frame(maxWidth: .infinity)
        .ihsanIlluminatedPanel(intensity: .regular)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Headline metrics

    private var headlineRow: some View {
        HStack(alignment: .top, spacing: IhsanSpacing.lg) {
            metric(
                value: completedPercentText,
                label: "ON TIME"
            )

            Divider()
                .frame(width: 0.5, height: 56)
                .overlay(IhsanColor.brass.opacity(0.30))

            metric(
                value: jamaahCountText,
                label: "JAMAʿAH"
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(value)
                .font(.system(size: 36, weight: .light, design: .serif))
                .monospacedDigit()
                .foregroundStyle(IhsanColor.inkDeep)
            Text(label)
                .font(IhsanFont.inscription)
                .tracking(1.8)
                .foregroundStyle(IhsanColor.brassDark.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Secondary metrics

    private var secondaryRow: some View {
        HStack(spacing: 0) {
            secondaryMetric(count: aggregate.onTimeCount, label: "ON TIME")
            secondaryMetric(count: aggregate.missedCount, label: "MISSED")
            secondaryMetric(count: aggregate.qadaCount, label: "QADĀ")
        }
    }

    private func secondaryMetric(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(IhsanFont.tabular)
                .foregroundStyle(IhsanColor.inkDeep.opacity(0.85))
            Text(label)
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(IhsanColor.brassDark.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var completedPercent: Int {
        guard aggregate.totalPossible > 0 else { return 0 }
        let fraction = Double(aggregate.onTimeCount) / Double(aggregate.totalPossible)
        return Int((fraction * 100).rounded())
    }

    private var completedPercentText: String {
        "\(completedPercent)%"
    }

    private var jamaahCountText: String {
        "\(aggregate.jamaahCount)/\(aggregate.totalPossible)"
    }

    private var accessibilityLabel: String {
        "Completed: \(completedPercent) percent on time, "
        + "\(aggregate.onTimeCount) prayers on time, "
        + "\(aggregate.missedCount) missed, "
        + "\(aggregate.qadaCount) qada."
    }
}

#Preview("Summary stats — typical month") {
    let perPrayer = Prayer.allCases.map { prayer in
        TrajectoryAggregate.PrayerAggregate(
            prayer: prayer,
            onTimeCount: 26,
            lateCount: 2,
            missedCount: 1,
            qadaCount: 1,
            totalActiveDays: 30,
            dailyFractions: []
        )
    }
    let aggregate = TrajectoryAggregate(
        totalActiveDays: 30,
        pausedDays: 0,
        travelingDays: 2,
        totalLogged: 142,
        totalPossible: 150,
        onTimeCount: 132,
        lateCount: 6,
        missedCount: 4,
        qadaCount: 2,
        jamaahCount: 28,
        perPrayer: perPrayer
    )
    return ScrollView {
        SummaryStatsPanel(aggregate: aggregate)
            .padding()
    }
    .ihsanManuscriptPage()
}
