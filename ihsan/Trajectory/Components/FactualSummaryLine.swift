import SwiftUI
import IhsanDesignSystem

/// A single line of factual counts. Deliberately not a card, not a chart, not
/// a percentage — counts only, separated by middle dots, in tabular figures.
/// Each clause appears only when the count is non-zero so a perfect period
/// reads "30 of 30 logged · 30 on time" instead of "… 0 late · 0 missed".
struct FactualSummaryLine: View {
    let aggregate: TrajectoryAggregate

    var body: some View {
        Text(summary)
            .font(IhsanFont.tabular)
            .foregroundStyle(IhsanColor.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, IhsanSpacing.md)
            .accessibilityLabel(summary)
    }

    private var summary: String {
        var parts: [String] = []
        parts.append("\(aggregate.totalLogged) of \(aggregate.totalPossible) logged")
        if aggregate.onTimeCount > 0 {
            parts.append("\(aggregate.onTimeCount) on time")
        }
        if aggregate.lateCount > 0 {
            parts.append("\(aggregate.lateCount) late")
        }
        if aggregate.missedCount > 0 {
            parts.append("\(aggregate.missedCount) missed")
        }
        if aggregate.qadaCount > 0 {
            parts.append("\(aggregate.qadaCount) qada")
        }
        return parts.joined(separator: "  ·  ")
    }
}
