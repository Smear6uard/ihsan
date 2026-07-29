import IhsanDesignSystem
import SwiftUI

/// The single, dismissible invitation on Path. Shown only while makeup
/// tracking is off and the card has never been dismissed; "Not now" retires
/// it permanently.
struct RepairInviteCard: View {
    let onBegin: () -> Void
    let onDismiss: () -> Void

    private var tokens: SkyPaletteTokens {
        RepairPalette.tokens()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            Text("RETURNING")
                .font(IhsanFont.inscription)
                .tracking(1.6)
                .foregroundStyle(tokens.metal)

            Text("If you carry prayers from another season, there is a gentle way to return to them.")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: IhsanSpacing.md) {
                Button {
                    Haptics.impact(.light)
                    onBegin()
                } label: {
                    Text("Begin")
                        .font(IhsanFont.bodyEnglishBold)
                        .foregroundStyle(tokens.ink)
                        .padding(.horizontal, IhsanSpacing.md)
                        .frame(minHeight: 40)
                        .overlay {
                            Capsule().stroke(tokens.metal, lineWidth: 1.2)
                        }
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.impact(.light)
                    onDismiss()
                } label: {
                    Text("Not now")
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(tokens.inkSecondary)
                        .padding(.horizontal, IhsanSpacing.sm)
                        .frame(minHeight: 40)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Puts this invitation away. You can begin any time from Settings.")
            }
        }
        .padding(IhsanSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tokens.panelFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tokens.panelStroke, lineWidth: 1)
        }
    }
}
