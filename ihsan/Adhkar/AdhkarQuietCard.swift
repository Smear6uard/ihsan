import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import SwiftUI

/// The offer: a small quiet card beneath the focused card while a
/// remembrance window is open. It names the set and its window and
/// takes one tap. No countdown, no urgency, nothing owed — and a
/// dismissal that lasts the day, so a person who has already sat with
/// the morning is not asked again at ten.
///
/// Deliberately the duha card's shape, because it is the same kind of
/// thing: a window is open, and the app is mentioning it once.
struct AdhkarQuietCard: View {
    let category: AdhkarCategory
    let window: AdhkarWindow
    let timeZone: TimeZone
    let tokens: SkyPaletteTokens
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: IhsanSpacing.sm) {
            Button {
                Haptics.impact(.soft)
                onOpen()
            } label: {
                HStack(spacing: IhsanSpacing.sm) {
                    SequenceMark(state: .current, tokens: tokens)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(category.displayName) adhkār")
                            .font(IhsanFont.bodyEnglish)
                            .foregroundStyle(tokens.ink)
                            .lineLimit(1)

                        Text("OPEN UNTIL \(endTime)")
                            .font(IhsanFont.inscription)
                            .tracking(1.15)
                            .foregroundStyle(tokens.inkSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Text("BEGIN")
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                        .foregroundStyle(tokens.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(tokens.metal.opacity(0.11), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(
                                tokens.metal.opacity(0.30), lineWidth: 0.7
                            )
                        }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(category.displayName) adhkār, open until \(endTime)")
            .accessibilityHint("Double-tap to begin.")

            Button {
                Haptics.impact(.light)
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tokens.inkSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Not now")
            .accessibilityHint("Puts this away until tomorrow.")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .celestialPanel(tokens: tokens, cornerRadius: IhsanSpacing.smallCardRadius)
        .padding(.horizontal, IhsanSpacing.md)
    }

    private var endTime: String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return window.end.formatted(style)
    }
}
