import SwiftUI
import IhsanDesignSystem

/// 7D / 30D / 90D / Year segmented control. Same visual language as
/// `RadiusSelector` on the masjid finder — a quiet capsule of ultra-thin
/// material so it can sit above the heatmap without competing with it.
struct PeriodSelector: View {
    @Binding var period: TrajectoryPeriod

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TrajectoryPeriod.allCases) { option in
                Button {
                    guard period != option else { return }
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        period = option
                    }
                } label: {
                    Text(option.label)
                        .font(IhsanFont.smallCaps)
                        .tracking(0.8)
                        .foregroundStyle(
                            period == option
                                ? IhsanColor.textPrimary
                                : IhsanColor.textMuted
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, IhsanSpacing.sm)
                        .background {
                            if period == option {
                                Capsule()
                                    .fill(IhsanColor.textPrimary.opacity(0.12))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option.label) period")
                .accessibilityAddTraits(period == option ? [.isSelected] : [])
            }
        }
        .padding(IhsanSpacing.xs)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(IhsanColor.atmospheric, lineWidth: 0.5)
                }
        }
    }
}
