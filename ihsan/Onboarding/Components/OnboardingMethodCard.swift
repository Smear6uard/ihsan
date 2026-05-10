import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// Read-only summary card displayed on the calculation-method step.
///
/// Tapping anywhere on the card raises the picker sheet — the card
/// is the affordance, not just the "Change method" link below it. The
/// link is kept so screen readers and Dynamic Type users at the
/// largest sizes still have an obvious textual call-to-action.
struct OnboardingMethodCard: View {
    let method: CalculationMethodChoice
    let detectedFromCountry: Bool
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            Text(detectedFromCountry ? "AUTO-DETECTED" : "DEFAULT")
                .font(IhsanFont.smallCaps)
                .tracking(1.2)
                .foregroundStyle(IhsanColor.textMuted)

            Text(method.displayName)
                .font(IhsanFont.subtitle)
                .foregroundStyle(IhsanColor.textPrimary)

            Text(method.regionHint)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onChange) {
                HStack(spacing: IhsanSpacing.xs) {
                    Text("Change method")
                        .font(IhsanFont.bodyEnglishBold)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(IhsanColor.textPrimary)
                .padding(.top, IhsanSpacing.xs)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens a list of all calculation methods")
        }
        .padding(IhsanSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ihsanGlass(
            in: RoundedRectangle(
                cornerRadius: IhsanSpacing.cardRadius,
                style: .continuous
            ),
            intensity: .regular
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: IhsanSpacing.cardRadius,
                style: .continuous
            )
            .strokeBorder(IhsanColor.atmospheric, lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
    }
}
