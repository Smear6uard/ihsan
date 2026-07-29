import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The estimate's arithmetic, shown as it assembles. Every value here is a
/// field of `QadaEstimate` — the display cannot drift from the computation
/// because it *is* the computation, formatted.
struct RepairArithmeticCard: View {
    /// Which rows have been earned so far in the conversation.
    enum Stage: Int, Comparable {
        case began, span, excused, obligated

        static func < (lhs: Stage, rhs: Stage) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    let estimate: QadaEstimate
    let averageExcusedDaysPerMonth: Int
    let stage: Stage
    let tokens: SkyPaletteTokens

    var body: some View {
        VStack(spacing: 0) {
            row(
                label: "Accountability began",
                value: estimate.accountabilityBegan.formatted(.dateTime.month(.abbreviated).year())
            )
            if stage >= .span {
                row(label: "Days since", value: formatted(estimate.spanDays))
            }
            if stage >= .excused, averageExcusedDaysPerMonth > 0 {
                row(
                    label: "Excused · \(formatted(estimate.wholeMonths)) mo × \(averageExcusedDaysPerMonth)",
                    value: "− \(formatted(estimate.excusedDaysDeducted))"
                )
            }
            if stage >= .obligated {
                row(label: "Days to repair", value: formatted(estimate.obligatedDays), emphasized: true)
            }
        }
        .padding(IhsanSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tokens.panelFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tokens.panelStroke, lineWidth: 1)
        }
    }

    private func row(label: String, value: String, emphasized: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(tokens.inkSecondary)
            Spacer(minLength: IhsanSpacing.sm)
            Text(value)
                .font(IhsanFont.tabular)
                .foregroundStyle(emphasized ? tokens.ink : tokens.inkSecondary)
        }
        .padding(.vertical, IhsanSpacing.xs + 2)
        .accessibilityElement(children: .combine)
    }

    private func formatted(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }
}
