import IhsanDesignSystem
import SwiftUI

/// The single, dismissible invitation on Path. Shown only while makeup
/// tracking is off and the card has never been dismissed; "Not now" retires
/// it permanently.
struct RepairInviteCard: View {
    let onBegin: () -> Void
    let onDismiss: () -> Void

    /// The Returning card carries the Repair identity on every
    /// ground: the sunset family's deep plum, deliberately darker
    /// than the sunset panel itself, with the sunset ink and gold.
    /// A fixed identity — the card does not follow the page's hour.
    private var tokens: SkyPaletteTokens {
        PaletteState.sunset.tokens
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
                    // Gilded: solid leaf bounded by the keyline — the
                    // same emphasis grammar as the sheet's commit.
                    Text("Begin")
                        .font(IhsanFont.bodyEnglishBold)
                        .foregroundStyle(tokens.keyline)
                        .padding(.horizontal, IhsanSpacing.md)
                        .frame(minHeight: 40)
                        .background {
                            Capsule().fill(tokens.leafGold)
                        }
                        .overlay {
                            Capsule().strokeBorder(
                                tokens.keyline.opacity(0.55), lineWidth: 0.8
                            )
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
                .fill(plumPanel)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tokens.panelStroke, lineWidth: 1)
        }
    }

    /// The sunset panel deepened toward the plum ground plane — the
    /// "plum deepened" of the spec, stable across every page phase.
    private var plumPanel: Color {
        SRGBValue.mix(
            tokens.panelFillValue,
            tokens.groundPlaneValue,
            amount: 0.30
        ).color
    }
}
