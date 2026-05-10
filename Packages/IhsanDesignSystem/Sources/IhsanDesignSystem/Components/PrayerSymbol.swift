import SwiftUI
import IhsanCore

/// SF Symbol mapping for each daily prayer. The icons are decorative — the
/// prayer name carries the meaning — so they are hidden from VoiceOver to
/// avoid double-reading.
public struct PrayerSymbol: View {
    public let prayer: Prayer
    public let size: CGFloat
    public let tint: Color?
    public let weight: Font.Weight

    public init(
        _ prayer: Prayer,
        size: CGFloat = 22,
        tint: Color? = nil,
        weight: Font.Weight = .regular
    ) {
        self.prayer = prayer
        self.size = size
        self.tint = tint
        self.weight = weight
    }

    public var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(tint ?? IhsanColor.textSecondary)
            .accessibilityHidden(true)
    }

    private var symbolName: String {
        switch prayer {
        case .fajr: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.haze.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }
}

#Preview("Prayer symbols") {
    HStack(spacing: IhsanSpacing.lg) {
        ForEach(Prayer.allCases, id: \.self) { prayer in
            VStack(spacing: IhsanSpacing.sm) {
                PrayerSymbol(prayer, size: 28)
                Text(prayer.displayNameEnglish)
                    .font(IhsanFont.smallCaps)
                    .foregroundStyle(IhsanColor.textMuted)
            }
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanBackground()
}
