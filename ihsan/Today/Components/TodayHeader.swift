import SwiftUI
import IhsanDesignSystem

struct TodayHeader: View {
    let cityName: String
    let date: Date
    let qiblaAction: () -> Void
    let masjidAction: () -> Void

    @Environment(\.timeOfDayOverride) private var override

    var body: some View {
        // The header sits directly on the sky gradient — not on a card —
        // so foreground colours route through `skyForegroundPrimary(at:)`
        // (which always picks the better-contrast pole) rather than
        // through the warm-card helpers used by the prayer rows below.
        // A subtle opposite-tinted text shadow boosts effective
        // legibility through the brief sunrise / maghrib transition
        // windows where the sky top sits at mid-tone.
        let referenceDate = override ?? date
        let foreground = IhsanColor.skyForegroundPrimary(at: referenceDate)
        let foregroundSecondary = IhsanColor.skyForegroundSecondary(at: referenceDate)
        let accent = IhsanColor.accentWarm(at: referenceDate)
        let shadowColor = legibilityShadowColor(for: foreground)

        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.md) {
                VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                    // City name now reads in `bodyEnglishBold` (17 pt
                    // semibold default) instead of the previous 13 pt
                    // smallCaps — gives the header a real typographic
                    // anchor rather than a row of small-caps run-on
                    // labels.
                    Text(cityName)
                        .font(IhsanFont.bodyEnglishBold)
                        .foregroundStyle(foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .shadow(color: shadowColor, radius: 2, x: 0, y: 0.5)

                    HStack(spacing: IhsanSpacing.xs + IhsanSpacing.xxs) {
                        Text(HijriDateFormatter.string(from: referenceDate))
                            .font(IhsanFont.smallCaps)
                            .foregroundStyle(foregroundSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .shadow(color: shadowColor, radius: 1.5, x: 0, y: 0.5)
                        MoonPhaseGlyph(date: referenceDate, accent: accent)
                    }
                }

                Spacer(minLength: IhsanSpacing.sm)

                HStack(spacing: IhsanSpacing.sm) {
                    IconChip(
                        systemName: "location.north.line.fill",
                        accessibilityLabel: "Qibla compass",
                        tint: foreground,
                        action: qiblaAction
                    )
                    IconChip(
                        systemName: "mappin.and.ellipse.circle.fill",
                        accessibilityLabel: "Find nearest masjid",
                        tint: foreground,
                        action: masjidAction
                    )
                }
            }

            // Atmospheric hairline separating the header from the
            // content below. The line carries the warm accent at low
            // opacity so it reads as a thread laid across the sky
            // rather than as a hard UI rule.
            AccentHairline(accent: accent)
        }
    }

    /// Returns the opposite-tinted shadow colour used to boost the
    /// header's effective legibility during the brief windows where
    /// the sky top sits at mid-tone (around sunrise and maghrib).
    /// Ink-dark text gets a soft white halo; bone-cream text gets a
    /// soft dark halo.
    private func legibilityShadowColor(for foreground: Color) -> Color {
        foreground == IhsanColor.textInkDark
            ? .white.opacity(0.40)
            : .black.opacity(0.45)
    }
}

/// Small monochrome moon-phase glyph, tinted to the warm accent so the
/// header reads in one chromatic key with the prayer arc's now-marker
/// and the active-prayer indicator below.
private struct MoonPhaseGlyph: View {
    let date: Date
    let accent: Color

    var body: some View {
        let bucket = MoonPhase.bucket(at: date)
        Image(systemName: bucket.symbolName)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(accent.opacity(0.85))
            .shadow(color: accent.opacity(0.35), radius: 2, x: 0, y: 0)
            .accessibilityLabel(bucket.spokenLabel)
    }
}

/// Soft horizontal hairline drawn in the warm accent with feathered
/// ends. Slightly stronger at the centre than at the edges so it
/// reads as atmospheric structure rather than as a UI rule.
private struct AccentHairline: View {
    let accent: Color

    var body: some View {
        LinearGradient(
            colors: [
                .clear,
                accent.opacity(0.28),
                accent.opacity(0.18),
                .clear
            ],
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
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.medium)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint.opacity(0.92))
                .frame(width: 36, height: 36)
                // Sits on the sky directly, so we tint a subtle warm
                // glass disc rather than reusing the dark
                // `.ihsanGlass(.subtle)` material which would read as a
                // cool patch on a warm sky.
                .ihsanWarmCard(in: Circle(), intensity: .subtle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
