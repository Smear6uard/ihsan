import SwiftUI
import IhsanDesignSystem

/// 7D / 30D / 90D / Year segmented control. Restyled as a small caps
/// inscription strip with a brass underline marking the selected
/// option — sits above the grid like a marginal note in a manuscript
/// rather than as a standalone control element.
struct PeriodSelector: View {
    @Binding var period: TrajectoryPeriod

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var underlineNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TrajectoryPeriod.allCases) { option in
                Button {
                    guard period != option else { return }
                    Haptics.tap()
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
                        period = option
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(option.label.uppercased())
                            .font(IhsanFont.inscription)
                            .tracking(1.6)
                            .foregroundStyle(
                                period == option
                                    ? IhsanColor.brass
                                    : IhsanColor.brassDark.opacity(0.50)
                            )

                        if period == option {
                            Capsule()
                                .fill(IhsanIridescence.brassStroke(opacity: 0.95))
                                .frame(width: 18, height: 1.5)
                                .matchedGeometryEffect(id: "underline", in: underlineNamespace)
                        } else {
                            Color.clear.frame(height: 1.5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, IhsanSpacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option.label) period")
                .accessibilityAddTraits(period == option ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, IhsanSpacing.xs)
    }
}
