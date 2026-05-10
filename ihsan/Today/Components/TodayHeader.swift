import SwiftUI
import IhsanDesignSystem

/// Page header for the Today screen. Sits directly on the manuscript
/// page gradient with refined typography:
///
/// - Location name in large small caps, letter-spaced, contrast-picked
///   against the page colour so it reads at every hour.
/// - Hijri date below in inscription small caps with a brass moon-phase
///   glyph.
/// - An ornamental brass divider — feathered rule with a tiny four-
///   pointed star at centre — separating the header from the content
///   below.
/// - Qibla and masjid affordances on the right as small circular
///   illuminated chips: cream / amber disc bordered in brass, with the
///   icon glyph rendered in the same contrast-picked colour as the
///   location text.
struct TodayHeader: View {
    let cityName: String
    let date: Date
    let qiblaAction: () -> Void
    let masjidAction: () -> Void

    @Environment(\.timeOfDayOverride) private var override

    var body: some View {
        let referenceDate = override ?? date
        let foreground = IhsanColor.skyForegroundPrimary(at: referenceDate)
        let foregroundSecondary = IhsanColor.skyForegroundSecondary(at: referenceDate)
        let shadowColor = legibilityShadowColor(for: foreground)

        VStack(alignment: .leading, spacing: IhsanSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.md) {
                VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                    // Location as a small-caps inscription — letter-
                    // spaced and prominent, the way a manuscript page's
                    // place name reads as a header.
                    Text(cityName.uppercased())
                        .font(IhsanFont.inscriptionLarge)
                        .tracking(2.4)
                        .foregroundStyle(foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .shadow(color: shadowColor, radius: 2, x: 0, y: 0.5)

                    HStack(spacing: IhsanSpacing.xs + IhsanSpacing.xxs) {
                        Text(HijriDateFormatter.string(from: referenceDate))
                            .font(IhsanFont.inscription)
                            .tracking(1.4)
                            .foregroundStyle(foregroundSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .shadow(color: shadowColor, radius: 1.5, x: 0, y: 0.5)
                        MoonPhaseGlyph(date: referenceDate)
                    }
                }

                Spacer(minLength: IhsanSpacing.sm)

                HStack(spacing: IhsanSpacing.sm) {
                    IlluminatedIconChip(
                        systemName: "location.north.line.fill",
                        accessibilityLabel: "Qibla compass",
                        action: qiblaAction
                    )
                    IlluminatedIconChip(
                        systemName: "mappin.and.ellipse.circle.fill",
                        accessibilityLabel: "Find nearest masjid",
                        action: masjidAction
                    )
                }
            }

            // Ornamental brass divider with a centred four-pointed
            // star flourish — the page's section break, echoing the
            // divider inside the hero countdown card.
            OrnamentalDivider(
                tint: IhsanColor.brass,
                opacity: 0.34,
                starSize: 7,
                ruleWidth: nil
            )
        }
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

/// Small monochrome moon-phase glyph, tinted in brass so it belongs to
/// the same chromatic key as the dividers and corner ornaments
/// elsewhere on the page.
private struct MoonPhaseGlyph: View {
    let date: Date

    var body: some View {
        let bucket = MoonPhase.bucket(at: date)
        Image(systemName: bucket.symbolName)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(IhsanColor.brass.opacity(0.88))
            .shadow(color: IhsanColor.brass.opacity(0.35), radius: 2, x: 0, y: 0)
            .accessibilityLabel(bucket.spokenLabel)
    }
}

/// A circular illuminated chip used for the Qibla and masjid
/// affordances at the top right of the page header. Built like a
/// miniature illuminated panel: a solid cream / amber disc bordered
/// in brass, with the icon glyph contrast-picked against that surface
/// so it always reads cleanly regardless of the page colour beneath.
private struct IlluminatedIconChip: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    @Environment(\.timeOfDayOverride) private var override

    var body: some View {
        let now = override ?? .now
        let surface = IhsanColor.panelSurface(at: now)
        let iconColor = IhsanColor.cardForegroundPrimary(at: now)

        Button {
            Haptics.impact(.medium)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(iconColor.opacity(0.88))
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(surface)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    IhsanColor.brass.opacity(0.55),
                                    lineWidth: 0.75
                                )
                        }
                }
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
