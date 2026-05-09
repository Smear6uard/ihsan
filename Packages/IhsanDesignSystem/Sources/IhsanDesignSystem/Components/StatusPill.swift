import SwiftUI
import IhsanCore

/// 4-state prayer status indicator. Quiet visual treatment — no bright
/// colors, no traffic-light semantics. The whole pill stays within the
/// muted brass / bone / ivory palette so the screen never feels punitive
/// for missed prayers or rewarding for on-time ones.
public struct StatusPill: View {
    public let status: PrayerStatus

    public init(_ status: PrayerStatus) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: IhsanSpacing.xs) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(IhsanFont.smallCaps)
        }
        .foregroundStyle(textColor)
        .padding(.horizontal, IhsanSpacing.sm + IhsanSpacing.xxs)
        .padding(.vertical, IhsanSpacing.xs + IhsanSpacing.xxs)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 0.5)
                }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconName: String {
        switch status {
        case .onTime: return "checkmark"
        case .late: return "clock"
        case .missed: return "circle"
        case .qada: return "arrow.uturn.backward"
        }
    }

    private var label: String {
        switch status {
        case .onTime: return "On Time"
        case .late: return "Late"
        case .missed: return "Missed"
        case .qada: return "Qada"
        }
    }

    private var textColor: Color {
        switch status {
        case .onTime: return IhsanColor.statusOnTime
        case .late: return IhsanColor.statusLate
        case .missed: return IhsanColor.statusMissed
        case .qada: return IhsanColor.statusQada
        }
    }

    private var borderColor: Color {
        textColor.opacity(0.3)
    }

    private var accessibilityLabel: String {
        "Status: \(label)"
    }
}

#Preview("Status pills") {
    VStack(spacing: IhsanSpacing.md) {
        ForEach(PrayerStatus.allCases, id: \.self) { status in
            StatusPill(status)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanBackground()
}
