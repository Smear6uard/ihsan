import SwiftUI
import IhsanDesignSystem

struct TodayHeader: View {
    let cityName: String
    let date: Date
    let qiblaAction: () -> Void
    let masjidAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: IhsanSpacing.md) {
            VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                Text(cityName.uppercased())
                    .font(IhsanFont.smallCaps)
                    .foregroundStyle(IhsanColor.textSecondary)
                    .lineLimit(1)
                Text(HijriDateFormatter.string(from: date))
                    .font(IhsanFont.smallCaps)
                    .foregroundStyle(IhsanColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: IhsanSpacing.sm)

            HStack(spacing: IhsanSpacing.sm) {
                IconChip(systemName: "location.north.line.fill",
                         accessibilityLabel: "Qibla compass",
                         action: qiblaAction)
                IconChip(systemName: "mappin.and.ellipse.circle.fill",
                         accessibilityLabel: "Find nearest masjid",
                         action: masjidAction)
            }
        }
    }
}

private struct IconChip: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(IhsanColor.textSecondary)
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle().strokeBorder(IhsanColor.atmospheric, lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
