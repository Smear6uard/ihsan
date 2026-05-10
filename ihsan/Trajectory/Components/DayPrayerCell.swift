import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// One cell in the Daily Practice grid — the intersection of a day
/// (row) and a fardh prayer (column). The visual carries both the
/// status and the jamaʿah modifier in a single 22pt square:
///
/// - Jamaʿah (status = .onTime, withJamaah = true): brass fill, "J"
/// - On Time (status = .onTime): cream parchment fill, no glyph
/// - Late (status = .late): muted brass fill, no glyph
/// - Missed (status = .missed): vermillion fill
/// - Qadā (status = .qada): brass fill, "Q"
/// - Unlogged (status = nil): outlined empty square
///
/// Each cell sits on its own rounded square with a 0.6pt iridescent
/// brass stroke so the grid reads as 70 illuminated panels arranged
/// in a matrix, all in one chromatic key with the page borders.
struct DayPrayerCell: View {
    let completion: PrayerCompletion
    let size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(fillColor)
            shape.strokeBorder(
                IhsanIridescence.brassStroke(opacity: strokeOpacity),
                lineWidth: strokeWidth
            )
            if let glyph {
                Text(glyph)
                    .font(.system(size: size * 0.5, weight: .bold, design: .serif))
                    .foregroundStyle(glyphColor)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var cornerRadius: CGFloat { size * 0.22 }

    private var strokeWidth: CGFloat {
        completion.status == nil ? 0.6 : 0.8
    }

    private var strokeOpacity: Double {
        completion.status == nil ? 0.45 : 0.70
    }

    private var fillColor: Color {
        switch completion.status {
        case .onTime where completion.withJamaah:
            return IhsanColor.brassMid.opacity(0.92)
        case .onTime:
            return IhsanColor.panelDay.opacity(0.92)
        case .late:
            return IhsanColor.brassDark.opacity(0.55)
        case .missed:
            return IhsanColor.vermillion.opacity(0.85)
        case .qada:
            return IhsanColor.brassMid.opacity(0.92)
        case .none:
            return .clear
        }
    }

    private var glyph: String? {
        switch completion.status {
        case .onTime where completion.withJamaah:
            return "J"
        case .qada:
            return "Q"
        default:
            return nil
        }
    }

    private var glyphColor: Color {
        IhsanColor.inkDeep
    }
}

#Preview("Day prayer cells") {
    HStack(spacing: 8) {
        DayPrayerCell(
            completion: PrayerCompletion(prayer: .fajr, status: .onTime, withJamaah: true),
            size: 28
        )
        DayPrayerCell(
            completion: PrayerCompletion(prayer: .fajr, status: .onTime, withJamaah: false),
            size: 28
        )
        DayPrayerCell(
            completion: PrayerCompletion(prayer: .fajr, status: .late, withJamaah: false),
            size: 28
        )
        DayPrayerCell(
            completion: PrayerCompletion(prayer: .fajr, status: .missed, withJamaah: false),
            size: 28
        )
        DayPrayerCell(
            completion: PrayerCompletion(prayer: .fajr, status: .qada, withJamaah: false),
            size: 28
        )
        DayPrayerCell(
            completion: PrayerCompletion(prayer: .fajr, status: nil, withJamaah: false),
            size: 28
        )
    }
    .padding()
    .background(IhsanColor.panelDay)
}
