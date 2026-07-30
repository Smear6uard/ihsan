import IhsanDesignSystem
import SwiftUI

/// The one time the app mentions the sunnah layer.
///
/// The layer is invisible until turned on, which is the right default
/// and also means nobody finds it. So it says so — once, after a
/// fortnight of logging, in the Returning card's pattern and register.
/// Either answer retires it forever: "Show me" opens Set, "Not now"
/// puts it away, and the app never raises it again either way.
///
/// Fourteen days because the invitation only makes sense to someone who
/// already has a habit here. Offered to a person on their third day it
/// would read as the app asking for more.
struct SunnahInviteCard: View {
    let onShow: () -> Void
    let onDismiss: () -> Void

    /// A fixed identity, like the Returning card: the same deep plum
    /// whatever hour the page is at.
    private var tokens: SkyPaletteTokens {
        PaletteState.sunset.tokens
    }

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            Text("IF YOU WANT IT")
                .font(IhsanFont.inscription)
                .tracking(1.6)
                .foregroundStyle(tokens.metal)

            Text("There is more to the day than the five — the rawatib, duha, the night. It waits in Set, and stays off until you turn it on.")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: IhsanSpacing.md) {
                Button {
                    Haptics.impact(.light)
                    onShow()
                } label: {
                    Text("Show me")
                        .font(IhsanFont.bodyEnglishBold)
                        .foregroundStyle(tokens.keyline)
                        .padding(.horizontal, IhsanSpacing.md)
                        .frame(minHeight: 40)
                        .background { Capsule().fill(tokens.leafGold) }
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(IhsanSpacing.md)
        .celestialPanel(tokens: tokens, cornerRadius: 18)
        .accessibilityElement(children: .contain)
    }
}

/// When the invitation is due.
///
/// Every condition is a reason to stay quiet. It appears once, for
/// someone with a fortnight of days behind them, who has not already
/// found the layer and has not already been asked.
enum SunnahInvite {
    /// Days of logging before the app says anything.
    static let requiredDays = 14

    static func shouldOffer(
        distinctLoggedDays: Int,
        sunnahLayerEnabled: Bool,
        hasBeenDismissed: Bool
    ) -> Bool {
        guard !sunnahLayerEnabled else { return false }
        guard !hasBeenDismissed else { return false }
        return distinctLoggedDays >= requiredDays
    }
}
