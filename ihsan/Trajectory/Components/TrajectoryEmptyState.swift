import SwiftUI
import IhsanDesignSystem

/// Shown the first time someone opens Trajectory before any prayers are
/// logged. The tone is invitational, not corrective: "Begin your record."
/// — not "You haven't logged anything yet."
struct TrajectoryEmptyState: View {
    let tokens: SkyPaletteTokens

    var body: some View {
        VStack(spacing: IhsanSpacing.lg) {
            FourPointedStar()
                .fill(tokens.metal.opacity(0.70))
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            VStack(spacing: IhsanSpacing.sm) {
                Text("Begin your record.")
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundStyle(tokens.ink)
                Text("Log your first prayer on the Today screen to start your trajectory.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, IhsanSpacing.xl)
            }
        }
        .padding(IhsanSpacing.xl)
        .frame(maxWidth: .infinity)
        .celestialPanel(tokens: tokens, cornerRadius: 18)
        .padding(.horizontal, IhsanSpacing.md)
        .accessibilityElement(children: .combine)
    }
}
