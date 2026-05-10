import SwiftUI
import IhsanDesignSystem

/// Empty state when the search returns nothing. The building glyph
/// renders large at .light weight to feel monumental rather than
/// disappointing — scale + restraint, not an apology. The fallback
/// "Open Apple Maps" button hands off to a tool the user can use to
/// look further afield without leaving the moment.
struct MasjidEmptyState: View {
    let radiusLabel: String
    let onOpenMaps: () -> Void

    var body: some View {
        VStack(spacing: IhsanSpacing.lg) {
            Image(systemName: "building.2")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(IhsanColor.textMuted)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: IhsanSpacing.sm) {
                Text("No masjids found within \(radiusLabel)")
                    .font(IhsanFont.subtitle)
                    .foregroundStyle(IhsanColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Try increasing the radius or check your area in Apple Maps directly.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, IhsanSpacing.xl)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Haptics.impact(.light)
                onOpenMaps()
            } label: {
                HStack(spacing: IhsanSpacing.sm) {
                    Image(systemName: "map")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Open Apple Maps")
                        .font(IhsanFont.bodyEnglishBold)
                }
                .foregroundStyle(IhsanColor.textPrimary)
                .padding(.horizontal, IhsanSpacing.lg)
                .padding(.vertical, IhsanSpacing.sm)
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
            .buttonStyle(.plain)
            .accessibilityHint("Opens Apple Maps to your current area")
        }
        .padding(IhsanSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MasjidEmptyState(radiusLabel: "1 km") {}
        .ihsanBackground()
}
