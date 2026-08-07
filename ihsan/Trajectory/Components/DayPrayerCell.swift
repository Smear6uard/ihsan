import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// One cell in the Daily Practice grid — the intersection of a day
/// (row) and a fardh prayer (column), speaking exactly the gestalt
/// pattern's dot-state language in a rounded square:
///
/// - On time — filled leaf gold bounded by the keyline
/// - Jamāʿah — the gilded fill ringed inside with bright metal
/// - Delayed — the warm metal outline
/// - Missed — the quiet secondary-ink outline (never vermillion)
/// - Qadā — lapis pigment bounded by metal
/// - Unlogged — the faintest metal outline
/// - Excused pause — the calm neutral dash
///
/// No letter glyphs, ever: the states are form and metal, the same
/// vocabulary the plate and the sheet teach.
struct DayPrayerCell: View {
    let completion: PrayerCompletion
    var isPausedDay: Bool = false
    let size: CGFloat
    let tokens: SkyPaletteTokens

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        ZStack {
            if isPausedDay {
                shape.strokeBorder(tokens.inkSecondary.opacity(0.22), lineWidth: 0.6)
                RoundedRectangle(cornerRadius: size, style: .continuous)
                    .fill(tokens.inkSecondary.opacity(0.35))
                    .frame(width: size * 0.5, height: max(1, size * 0.10))
            } else {
                switch (completion.status, completion.withJamaah) {
                case (.onTime, true):
                    shape.fill(tokens.leafGold)
                    shape.strokeBorder(tokens.keyline.opacity(0.9), lineWidth: keylineWidth)
                    RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                        .strokeBorder(
                            tokens.metalHighlight.opacity(0.95),
                            lineWidth: max(0.6, size * 0.05)
                        )
                        .padding(size * 0.14)
                case (.onTime, _):
                    shape.fill(tokens.leafGold)
                    shape.strokeBorder(tokens.keyline.opacity(0.9), lineWidth: keylineWidth)
                case (.qada, _):
                    shape.fill(GestaltDot.qadaBodyValue(for: tokens).color)
                    shape.strokeBorder(tokens.metal.opacity(0.9), lineWidth: keylineWidth)
                case (.late, _):
                    shape.strokeBorder(
                        GestaltDot.lateOutlineValue(for: tokens).color.opacity(0.95),
                        lineWidth: max(0.8, size * 0.09)
                    )
                case (.missed, _):
                    shape.strokeBorder(
                        GestaltDot.missedOutlineValue(for: tokens).color.opacity(0.60),
                        lineWidth: max(0.6, size * 0.07)
                    )
                case (.none, _):
                    shape.strokeBorder(tokens.metal.opacity(0.28), lineWidth: 0.6)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var keylineWidth: CGFloat { max(0.5, size * 0.045) }
}

#Preview("Day prayer cells") {
    let tokens = PaletteState.afternoon.tokens
    return HStack(spacing: 8) {
        DayPrayerCell(
            completion: PrayerCompletion(prayer: .fajr, status: .onTime, withJamaah: true),
            size: 28, tokens: tokens
        )
        DayPrayerCell(
            completion: PrayerCompletion(prayer: .fajr, status: .onTime, withJamaah: false),
            size: 28, tokens: tokens
        )
        DayPrayerCell(
            completion: PrayerCompletion(prayer: .fajr, status: .late, withJamaah: false),
            size: 28, tokens: tokens
        )
        DayPrayerCell(
            completion: PrayerCompletion(prayer: .fajr, status: .missed, withJamaah: false),
            size: 28, tokens: tokens
        )
        DayPrayerCell(
            completion: PrayerCompletion(prayer: .fajr, status: .qada, withJamaah: false),
            size: 28, tokens: tokens
        )
        DayPrayerCell(
            completion: PrayerCompletion(prayer: .fajr, status: nil, withJamaah: false),
            size: 28, tokens: tokens
        )
        DayPrayerCell(
            completion: PrayerCompletion(prayer: .fajr, status: nil, withJamaah: false),
            isPausedDay: true,
            size: 28, tokens: tokens
        )
    }
    .padding()
    .background(tokens.pageGroundFlat)
}
