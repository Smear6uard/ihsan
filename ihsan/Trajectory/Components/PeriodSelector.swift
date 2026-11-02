import SwiftUI
import IhsanDesignSystem

/// The period strip: a brass underline marks the selected option, and
/// the options say what they are.
struct PeriodSelector: View {
    @Binding var period: TrajectoryPeriod
    let tokens: SkyPaletteTokens

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
                        Text(option.title)
                            .font(.system(.subheadline, weight: period == option ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(
                                period == option
                                    ? tokens.ink
                                    : tokens.inkSecondary.opacity(0.75)
                            )

                        if period == option {
                            Capsule()
                                .fill(tokens.metal.opacity(0.95))
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
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(period == option ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, IhsanSpacing.xs)
    }
}
