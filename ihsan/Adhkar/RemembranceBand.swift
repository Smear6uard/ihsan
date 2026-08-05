import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The door to remembrance that is always open.
///
/// A slim band beneath the focused card, in `AdhkarQuietCard`'s shape
/// because it is a near relation — but a different thing. The offer
/// card says *this window is open, once, and you may put it away*. The
/// band says *any set, any time*, and never goes away.
///
/// It exists because remembrance used to be reachable only through that
/// offer card. A person who wanted the evening adhkār at midnight, or
/// the morning set in the afternoon, or the tasbīḥ instrument at any
/// hour without first logging a prayer, had no way in.
///
/// It sits outside the pause branch on Today, for the reason written
/// down in `AdhkarOffer.pauseSuppresses`: a pause suspends salah and
/// fasting, because those are what a person in that state is excused
/// from. It does not suspend dhikr, which is precisely what remains.
struct RemembranceBand: View {
    /// False under the scholar-review gate, when no set can be shown.
    /// The band then names the one thing it can still open.
    let showsHub: Bool
    let tokens: SkyPaletteTokens
    let onOpen: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.soft)
            onOpen()
        } label: {
            HStack(spacing: IhsanSpacing.sm) {
                SequenceMark(state: .pending, tokens: tokens)

                Text(title)
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.ink)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tokens.inkSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .celestialPanel(tokens: tokens, cornerRadius: IhsanSpacing.smallCardRadius)
        .padding(.horizontal, IhsanSpacing.md)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }

    private var title: String { showsHub ? "Remembrance" : "Tasbīḥ" }

    private var hint: String {
        showsHub
            ? "Opens the adhkār sets and the tasbīḥ counter."
            : "Opens the tasbīḥ counter."
    }
}

#Preview("Remembrance band") {
    VStack {
        Spacer()
        RemembranceBand(showsHub: true, tokens: PaletteState.night.tokens, onOpen: {})
        RemembranceBand(showsHub: false, tokens: PaletteState.night.tokens, onOpen: {})
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanManuscriptPage()
}
