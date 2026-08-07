import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import SwiftUI

/// One stable door for every remembrance action on Today.
///
/// When a time-bound set is available, its context is disclosed inside
/// this same panel rather than adding a second card to the stack. The
/// title remains stable, the set gets a direct Begin action, and tapping
/// the title still opens the complete remembrance menu.
struct RemembranceBand: View {
    /// False under the scholar-review gate, when only free tasbīḥ can open.
    let showsHub: Bool
    let offer: AdhkarOffer.Offer?
    let timeZone: TimeZone
    let tokens: SkyPaletteTokens
    let onOpen: () -> Void
    let onOpenOffer: (AdhkarCategory) -> Void
    let onDismissOffer: (AdhkarCategory) -> Void

    var body: some View {
        Group {
            if let offer {
                contextualBand(offer)
            } else {
                standardBand
            }
        }
        .celestialPanel(tokens: tokens, cornerRadius: IhsanSpacing.smallCardRadius)
        .padding(.horizontal, IhsanSpacing.md)
        .animation(.easeInOut(duration: 0.24), value: offer?.category)
    }

    private var standardBand: some View {
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tokens.inkSecondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }

    private func contextualBand(_ offer: AdhkarOffer.Offer) -> some View {
        HStack(spacing: 6) {
            Button {
                Haptics.impact(.soft)
                onOpen()
            } label: {
                HStack(spacing: IhsanSpacing.sm) {
                    SequenceMark(state: .current, tokens: tokens)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remembrance")
                            .font(IhsanFont.bodyEnglish)
                            .foregroundStyle(tokens.ink)
                            .lineLimit(1)

                        Text(contextLine(for: offer))
                            .font(IhsanFont.inscription)
                            .tracking(1.05)
                            .foregroundStyle(tokens.inkSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remembrance, \(spokenContext(for: offer))")
            .accessibilityHint("Opens all remembrance options.")

            Button {
                Haptics.impact(.soft)
                onOpenOffer(offer.category)
            } label: {
                Text("BEGIN")
                    .font(IhsanFont.inscription)
                    .tracking(1.3)
                    .foregroundStyle(tokens.ink)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
                    .background(tokens.metal.opacity(0.11), in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(tokens.metal.opacity(0.30), lineWidth: 0.7)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Begin \(offer.category.displayName) adhkār")

            Button {
                Haptics.impact(.light)
                onDismissOffer(offer.category)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tokens.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Not now")
            .accessibilityHint("Puts this suggestion away until tomorrow.")
        }
        .padding(.leading, 14)
        .padding(.trailing, 2)
        .padding(.vertical, 5)
    }

    private var title: String { showsHub ? "Remembrance" : "Tasbīḥ" }

    private var hint: String {
        showsHub
            ? "Opens the adhkār sets and the tasbīḥ counter."
            : "Opens the tasbīḥ counter."
    }

    private func contextLine(for offer: AdhkarOffer.Offer) -> String {
        "\(offer.category.displayName.uppercased()) · UNTIL \(endTime(for: offer))"
    }

    private func spokenContext(for offer: AdhkarOffer.Offer) -> String {
        "\(offer.category.displayName) adhkār available until \(endTime(for: offer))"
    }

    private func endTime(for offer: AdhkarOffer.Offer) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return offer.window.end.formatted(style)
    }
}

#Preview("Remembrance band") {
    let window = AdhkarWindow(
        start: .now,
        end: .now.addingTimeInterval(3_600)
    )
    VStack {
        Spacer()
        RemembranceBand(
            showsHub: true,
            offer: window.map { AdhkarOffer.Offer(category: .evening, window: $0) },
            timeZone: .current,
            tokens: PaletteState.night.tokens,
            onOpen: {},
            onOpenOffer: { _ in },
            onDismissOffer: { _ in }
        )
        RemembranceBand(
            showsHub: true,
            offer: nil,
            timeZone: .current,
            tokens: PaletteState.night.tokens,
            onOpen: {},
            onOpenOffer: { _ in },
            onDismissOffer: { _ in }
        )
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanManuscriptPage()
}
