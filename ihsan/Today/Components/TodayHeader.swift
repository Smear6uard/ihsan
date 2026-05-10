import SwiftUI
import IhsanDesignSystem

struct TodayHeader: View {
    let cityName: String
    let date: Date
    let qiblaAction: () -> Void
    let masjidAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            HStack(alignment: .center, spacing: IhsanSpacing.md) {
                VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                    Text(cityName.uppercased())
                        .font(IhsanFont.smallCaps)
                        .foregroundStyle(IhsanColor.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: IhsanSpacing.xs) {
                        Text(HijriDateFormatter.string(from: date))
                            .font(IhsanFont.smallCaps)
                            .foregroundStyle(IhsanColor.textMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        MoonPhaseGlyph(date: date)
                    }
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

            // Atmospheric hairline separating the header from the
            // content below. The line is the adaptive tint at very low
            // opacity with a soft gradient at both ends so it never
            // reads as a hard border.
            TintedHairline()
        }
    }
}

/// Small monochrome moon-phase glyph, tinted to the adaptive
/// time-of-day colour so the day's context (location, Hijri date,
/// lunar phase) reads as one visually integrated cluster.
private struct MoonPhaseGlyph: View {
    let date: Date
    @Environment(\.timeOfDayOverride) private var override

    var body: some View {
        let bucket = MoonPhase.bucket(at: date)
        let referenceDate = override ?? .now
        let tint = IhsanColor.adaptiveTint(at: referenceDate)

        Image(systemName: bucket.symbolName)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(tint.opacity(0.75))
            .accessibilityLabel(bucket.spokenLabel)
    }
}

/// Soft horizontal hairline drawn in the adaptive tint with feathered
/// ends. Sits at ~10% opacity so it reads as atmospheric structure
/// rather than as a UI rule.
private struct TintedHairline: View {
    @Environment(\.timeOfDayOverride) private var override

    var body: some View {
        let referenceDate = override ?? .now
        let tint = IhsanColor.adaptiveTint(at: referenceDate)
        LinearGradient(
            colors: [.clear, tint.opacity(0.18), tint.opacity(0.10), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: IhsanSpacing.hairline)
        .accessibilityHidden(true)
    }
}

private struct IconChip: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.medium)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(IhsanColor.textSecondary)
                .frame(width: 36, height: 36)
                .ihsanGlass(in: Circle(), intensity: .subtle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
