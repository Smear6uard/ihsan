import SwiftUI
import IhsanDesignSystem

/// Shown the first time someone opens Trajectory before any prayers are
/// logged. The tone is invitational, not corrective: "Begin your record."
/// — not "You haven't logged anything yet."
struct TrajectoryEmptyState: View {
    var body: some View {
        VStack(spacing: IhsanSpacing.lg) {
            FourPointedStar()
                .fill(IhsanColor.brass.opacity(0.55))
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            VStack(spacing: IhsanSpacing.sm) {
                Text("Begin your record.")
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundStyle(IhsanColor.inkDeep)
                Text("Log your first prayer on the Today screen to start your trajectory.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.inkDeep.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, IhsanSpacing.xl)
            }
        }
        .padding(IhsanSpacing.xl)
        .frame(maxWidth: .infinity)
        .ihsanIlluminatedPanel(intensity: .regular)
        .padding(.horizontal, IhsanSpacing.md)
        .accessibilityElement(children: .combine)
    }
}
