import SwiftUI
import IhsanDesignSystem

/// Compact, glass-styled segmented control for the search radius.
///
/// The selected segment carries a soft white pill behind a small-caps
/// label; unselected segments live as muted text on the bare glass.
/// The whole control is itself a capsule of `.ultraThinMaterial` with
/// an atmospheric hairline border — quiet enough to vanish while the
/// list is scanned, present enough to find when needed.
struct RadiusSelector: View {
    @Binding var radius: SearchRadius

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SearchRadius.allCases) { option in
                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        radius = option
                    }
                } label: {
                    Text(option.label)
                        .font(IhsanFont.smallCaps)
                        .tracking(0.8)
                        .foregroundStyle(
                            radius == option
                                ? IhsanColor.textPrimary
                                : IhsanColor.textMuted
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, IhsanSpacing.sm)
                        .background {
                            if radius == option {
                                Capsule()
                                    .fill(IhsanColor.textPrimary.opacity(0.12))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option.label) radius")
                .accessibilityAddTraits(radius == option ? [.isSelected] : [])
            }
        }
        .padding(IhsanSpacing.xs)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            IhsanColor.atmospheric,
                            lineWidth: 0.5
                        )
                }
        }
    }
}

#Preview {
    @Previewable @State var radius: SearchRadius = .fiveKm
    return RadiusSelector(radius: $radius)
        .padding()
        .frame(maxWidth: .infinity)
        .ihsanBackground()
}
