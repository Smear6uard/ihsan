import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// One of five status dots on the medium home widget. A small
/// circle whose fill encodes the logged status:
/// - on-time / late: filled bone-white at the corresponding opacity tier
/// - missed: hollow ring (atmospheric)
/// - qada: filled muted brass
/// - not-yet-logged: hollow ring (textMuted)
///
/// Wraps the dot in a subtle "active prayer" halo so the user can locate
/// the current prayer at a glance even before reading the label.
struct PrayerStatusDot: View {
    let prayer: Prayer
    let status: PrayerStatus?
    let isActive: Bool
    let size: CGFloat

    init(prayer: Prayer, status: PrayerStatus?, isActive: Bool = false, size: CGFloat = 14) {
        self.prayer = prayer
        self.status = status
        self.isActive = isActive
        self.size = size
    }

    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .strokeBorder(IhsanColor.atmospheric, lineWidth: 1)
                    .frame(width: size + 8, height: size + 8)
            }
            shape
                .frame(width: size, height: size)
        }
        .frame(width: size + 8, height: size + 8)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var shape: some View {
        switch status {
        case .onTime:
            Circle().fill(IhsanColor.statusOnTime)
        case .late:
            Circle().fill(IhsanColor.statusLate)
        case .missed:
            Circle().strokeBorder(IhsanColor.statusMissed, lineWidth: 1.5)
        case .qada:
            Circle().fill(IhsanColor.statusQada)
        case .none:
            Circle().strokeBorder(IhsanColor.textMuted, lineWidth: 1.5)
        }
    }

    private var accessibilityLabel: String {
        switch status {
        case .onTime: return "\(prayer.displayNameEnglish) on time"
        case .late: return "\(prayer.displayNameEnglish) late"
        case .missed: return "\(prayer.displayNameEnglish) missed"
        case .qada: return "\(prayer.displayNameEnglish) qada"
        case .none: return "\(prayer.displayNameEnglish) not logged"
        }
    }
}
