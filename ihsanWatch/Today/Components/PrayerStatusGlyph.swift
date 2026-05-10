import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// Small status indicator used in the prayer dot row and action sheet.
/// Mirrors IhsanDesignSystem's color tiers — never red for missed,
/// brass for qada — but compact enough for watch-scale layout.
struct PrayerStatusGlyph: View {
    let status: PrayerStatus?
    let size: CGFloat
    let isSelected: Bool
    let isJamaah: Bool

    init(
        status: PrayerStatus?,
        size: CGFloat = 8,
        isSelected: Bool = false,
        isJamaah: Bool = false
    ) {
        self.status = status
        self.size = size
        self.isSelected = isSelected
        self.isJamaah = isJamaah
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: size, height: size)

            if isJamaah {
                Circle()
                    .stroke(IhsanColor.statusQada.opacity(0.9), lineWidth: 1)
                    .frame(width: size + 4, height: size + 4)
            }

            if isSelected {
                Circle()
                    .stroke(IhsanColor.textPrimary.opacity(0.85), lineWidth: 1.5)
                    .frame(width: size + 6, height: size + 6)
                    .shadow(color: IhsanColor.adaptiveTint().opacity(0.6), radius: 4)
            }
        }
        .accessibilityHidden(true)
    }

    private var fillColor: Color {
        switch status {
        case .onTime: IhsanColor.statusOnTime
        case .late: IhsanColor.statusLate
        case .missed: IhsanColor.statusMissed
        case .qada: IhsanColor.statusQada
        case nil: IhsanColor.atmospheric
        }
    }
}
