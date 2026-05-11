import IhsanDesignSystem
import SwiftUI

/// The celestial Today screen header — a quiet annotation sitting on
/// the page above the celestial scene.
///
/// Per the celestial redesign the header is a small, considered
/// detail rather than a prominent UI bar. The whole screen IS the
/// celestial scene; the location reads as a marginal annotation on
/// the page rather than a page title.
///
/// Layout:
///
/// - **Location** in refined serif (~16pt), `.system(.title3,
///   design: .serif)`. The whole iPhone is the page; this is a
///   quiet label.
/// - **Hijri date** in small caps inscription (~10pt) beneath the
///   location, letter-spaced.
/// - **Moon-phase glyph** in the top-right corner — the current
///   lunar phase rendered as a small SF Symbol at brass tint. A
///   quiet detail, not a major element.
///
/// Qibla and masjid affordances are intentionally NOT in the header
/// per the new spec — those interactions move to Settings → Practice
/// (and a future long-press on the celestial scene) so the Today
/// screen stays a contemplative single composition.
struct TodayHeader: View {
    let cityName: String
    let date: Date

    @Environment(\.timeOfDayOverride) private var override

    var body: some View {
        let referenceDate = override ?? date
        let foreground = IhsanColor.skyForegroundPrimary(at: referenceDate)
        let foregroundSecondary = IhsanColor.skyForegroundSecondary(at: referenceDate)
        let shadowColor = legibilityShadowColor(for: foreground)

        HStack(alignment: .top, spacing: IhsanSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cityName)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: shadowColor, radius: 2, x: 0, y: 0.5)

                Text(HijriDateFormatter.string(from: referenceDate))
                    .font(.system(size: 10, weight: .semibold).smallCaps())
                    .tracking(1.4)
                    .foregroundStyle(foregroundSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: shadowColor, radius: 1.5, x: 0, y: 0.5)
            }

            Spacer(minLength: IhsanSpacing.sm)

            MoonPhaseGlyph(date: referenceDate)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(cityName), \(HijriDateFormatter.string(from: referenceDate))")
    }

    /// Returns the opposite-tinted shadow colour used to boost the
    /// header's effective legibility during the brief windows where
    /// the sky top sits at mid-tone (around sunrise and maghrib).
    private func legibilityShadowColor(for foreground: Color) -> Color {
        foreground == IhsanColor.inkDeep
            ? .white.opacity(0.42)
            : .black.opacity(0.48)
    }
}

/// Small monochrome moon-phase glyph in the header's top-right
/// corner. Reads as a quiet detail — the user can glance at it to
/// see the current lunar phase without it competing with the
/// celestial scene's much larger moon ornament below.
private struct MoonPhaseGlyph: View {
    let date: Date

    var body: some View {
        let bucket = MoonPhase.bucket(at: date)
        Image(systemName: bucket.symbolName)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(IhsanColor.brass.opacity(0.85))
            .shadow(color: IhsanColor.brass.opacity(0.35), radius: 2, x: 0, y: 0)
            .accessibilityLabel(bucket.spokenLabel)
    }
}
