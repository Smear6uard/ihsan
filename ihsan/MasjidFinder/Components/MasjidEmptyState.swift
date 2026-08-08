import SwiftUI
import IhsanDesignSystem

struct MasjidEmptyState: View {
    let tokens: SkyPaletteTokens
    let onOpenMaps: () -> Void

    var body: some View {
        VStack(spacing: IhsanSpacing.lg) {
            EightPointedStar()
                .stroke(tokens.metal.opacity(0.6), lineWidth: 1)
                .frame(width: IhsanSpacing.xxl, height: IhsanSpacing.xxl)
                .accessibilityHidden(true)

            VStack(spacing: IhsanSpacing.sm) {
                Text("No masjids found nearby")
                    .font(IhsanFont.subtitle)
                    .foregroundStyle(tokens.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Open Maps to search a wider area.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Haptics.impact(.light)
                onOpenMaps()
            } label: {
                HStack(spacing: IhsanSpacing.sm) {
                    SettingsGlyphView(.location, color: tokens.metal)
                        .frame(width: 18, height: 18)
                    Text("OPEN MAPS")
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .foregroundStyle(tokens.ink)
                }
                .padding(.horizontal, IhsanSpacing.lg)
                .padding(.vertical, IhsanSpacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Maps at your current location")
        }
        .padding(.horizontal, IhsanSpacing.xl)
        .padding(.vertical, IhsanSpacing.lg)
        .frame(maxWidth: .infinity)
        .celestialPanel(tokens: tokens, cornerRadius: 18)
    }
}
