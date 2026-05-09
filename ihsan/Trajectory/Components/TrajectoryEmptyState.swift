import SwiftUI
import IhsanDesignSystem

/// Shown the first time someone opens Trajectory before any prayers are
/// logged. The tone is invitational, not corrective: "Begin your record."
/// — not "You haven't logged anything yet."
struct TrajectoryEmptyState: View {
    var body: some View {
        VStack(spacing: IhsanSpacing.lg) {
            Image(systemName: "chart.dots.scatter")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(IhsanColor.textMuted)
                .accessibilityHidden(true)

            VStack(spacing: IhsanSpacing.sm) {
                Text("Begin your record.")
                    .font(IhsanFont.subtitle)
                    .foregroundStyle(IhsanColor.textPrimary)
                Text("Log your first prayer on the Today screen to start your trajectory.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, IhsanSpacing.xl)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
