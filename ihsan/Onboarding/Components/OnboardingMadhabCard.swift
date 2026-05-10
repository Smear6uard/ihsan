import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// One of the two side-by-side choice cards on the madhab step.
///
/// Selection is visually expressed by promoting the card to the hero
/// glass intensity and outlining it with a hairline border. Unselected
/// cards stay at subtle intensity so the difference between "selected"
/// and "unselected" reads even at a glance and even at the largest
/// Dynamic Type size, where copy length grows but visual hierarchy
/// must stay legible.
struct OnboardingMadhabCard: View {
    let title: String
    let arabicLabel: String
    let explanation: String
    let scholars: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(IhsanFont.bodyEnglishBold)
                        .foregroundStyle(IhsanColor.textPrimary)
                    Spacer(minLength: IhsanSpacing.xs)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(
                            isSelected
                                ? IhsanColor.textPrimary
                                : IhsanColor.atmospheric
                        )
                }

                Text(arabicLabel)
                    .font(IhsanFont.bodyArabic)
                    .foregroundStyle(IhsanColor.textMuted)

                Text(explanation)
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(scholars)
                    .font(IhsanFont.smallCaps)
                    .tracking(0.6)
                    .foregroundStyle(IhsanColor.textMuted)
            }
            .padding(IhsanSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            .ihsanGlass(
                in: RoundedRectangle(
                    cornerRadius: IhsanSpacing.cardRadius,
                    style: .continuous
                ),
                intensity: isSelected ? .hero : .subtle
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: IhsanSpacing.cardRadius,
                    style: .continuous
                )
                .strokeBorder(
                    isSelected ? IhsanColor.textSecondary : IhsanColor.atmospheric,
                    lineWidth: isSelected ? 1.0 : 0.5
                )
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: IhsanSpacing.cardRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(scale)
        .animation(animation, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(explanation). Used by \(scholars).")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var scale: CGFloat {
        guard !reduceMotion else { return 1.0 }
        return isSelected ? 1.0 : 0.985
    }

    private var animation: Animation {
        reduceMotion
            ? .linear(duration: 0.18)
            : .spring(response: 0.4, dampingFraction: 0.85)
    }
}
