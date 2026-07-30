import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import SwiftUI

/// The celestial Today screen header — a quiet annotation sitting on
/// the page above the celestial scene.
///
/// Layout:
///
/// - **Location** in refined serif at title3 scale. The whole iPhone
///   is the page; this is a quiet label, not a page title.
/// - **Inscription line** beneath the location combining the Hijri
///   date and the next-prayer indicator:
///
///         DHU'L-QI'DAH 24, 1447 AH · NEXT: DHUHR 12:50 PM
///
///   Small caps in brass with letter-spacing, separated by a brass
///   middle dot. The "NEXT" prayer comes from the same resolved
///   `PrayerMoment` the plate markers and the focused card use, and
///   its time goes through the same `PlateTimeFormat` as the marker
///   labels — one data source, one formatter, no disagreement.
/// - **Moon-phase glyph** in the top-right corner. Shows the current
///   lunar phase as a small brass icon — AND is the tap target for
///   the celestial reference / qibla compass overlay. A 44pt
///   invisible bounding box keeps the tap target comfortable even
///   though the visible glyph is ~22pt.
///
/// The header owns no clock: the screen's single timeline hands it
/// the resolved moment.
struct TodayHeader: View {
    let cityName: String
    /// The resolved moment from the screen's single clock.
    let now: Date
    /// The resolved prayer state at `now` — source of the "NEXT: …"
    /// inscription. Optional so non-ready states can render the
    /// header without prayer data.
    let moment: PrayerMoment?
    /// Timezone of the place the times belong to.
    let timeZone: TimeZone
    /// Resolved v2 palette tokens for this moment — the same set the
    /// plate and card read, so the header's ink can never disagree
    /// with the scene it annotates.
    let tokens: SkyPaletteTokens
    /// Tap callback for the moon-phase glyph — opens the celestial
    /// reference / qibla compass overlay.
    let onMoonPhaseTap: () -> Void
    /// Tap callback for the Hijri date — opens the Hijri month sheet.
    var onHijriTap: (() -> Void)? = nil
    /// A curated significant-day inscription for today ("WHITE DAY ·
    /// SAFAR 14"), quiet and dismissible. `nil` renders nothing.
    var significantDayInscription: String? = nil
    /// Tapping the line dismisses it for the day.
    var onSignificantDayTap: (() -> Void)? = nil

    var body: some View {
        let foreground = tokens.ink
        let foregroundSecondary = tokens.inkSecondary
        let shadowColor = legibilityShadowColor()
        let nextInscription = nextPrayerInscription

        HStack(alignment: .top, spacing: IhsanSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    Haptics.impact(.light)
                    onHijriTap?()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cityName)
                            .font(.system(.title3, design: .serif))
                            .foregroundStyle(foreground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .shadow(color: shadowColor, radius: 2, x: 0, y: 0.5)

                        inscriptionLine(
                            nextInscription: nextInscription,
                            foreground: foregroundSecondary,
                            shadowColor: shadowColor
                        )
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onHijriTap == nil)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(nextInscription: nextInscription))
                .accessibilityHint(onHijriTap == nil ? "" : "Opens the Hijri month.")
                .accessibilityAddTraits(.isHeader)

                if let significantDayInscription {
                    Button {
                        Haptics.impact(.light)
                        onSignificantDayTap?()
                    } label: {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(tokens.metal.opacity(0.75))
                                .frame(width: 10, height: 1.2)
                            Text(significantDayInscription)
                                .font(.system(size: 10, weight: .semibold).smallCaps())
                                .tracking(1.4)
                                .foregroundStyle(foregroundSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .shadow(color: shadowColor, radius: 1.5, x: 0, y: 0.5)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(significantDayInscription)
                    .accessibilityHint("Dismisses this note for today.")
                }
            }

            Spacer(minLength: IhsanSpacing.sm)

            MoonPhaseTapTarget(
                date: now,
                onTap: onMoonPhaseTap
            )
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func inscriptionLine(
        nextInscription: String?,
        foreground: Color,
        shadowColor: Color
    ) -> some View {
        let hijri = HijriDateFormatter.string(from: now)
        let combined: String = {
            if let nextInscription {
                return "\(hijri) · \(nextInscription)"
            }
            return hijri
        }()

        Text(combined)
            .font(.system(size: 10, weight: .semibold).smallCaps())
            .tracking(1.4)
            .foregroundStyle(foreground)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .shadow(color: shadowColor, radius: 1.5, x: 0, y: 0.5)
    }

    /// "NEXT: DHUHR 12:50 PM" — the moment's next prayer, formatted by
    /// the same `PlateTimeFormat` the plate's marker labels use.
    private var nextPrayerInscription: String? {
        guard let moment else { return nil }
        let time = PlateTimeFormat.time(moment.next.scheduledTime, in: timeZone).uppercased()
        let name = moment.next.prayer.displayNameEnglish.uppercased()
        return "NEXT: \(name) \(time)"
    }

    private func legibilityShadowColor() -> Color {
        tokens.inkValue.relativeLuminance < 0.5
            ? .white.opacity(0.42)
            : .black.opacity(0.48)
    }

    private func accessibilityLabel(nextInscription: String?) -> String {
        let hijri = HijriDateFormatter.string(from: now)
        var parts = ["Location: \(cityName)", "Hijri date: \(hijri)"]
        if let moment {
            let time = PlateTimeFormat.time(moment.next.scheduledTime, in: timeZone)
            parts.append(
                "Next prayer: \(moment.next.prayer.displayNameEnglish) at \(time)"
            )
        }
        _ = nextInscription
        parts.append("Tap the moon phase indicator for the celestial reference and qibla compass.")
        return parts.joined(separator: ". ") + "."
    }
}

/// Tap target wrapping the moon-phase glyph. The visible glyph is
/// ~22pt; the tap target extends to 44pt so the affordance is
/// comfortable even though the visual is small.
private struct MoonPhaseTapTarget: View {
    let date: Date
    let onTap: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            onTap()
        } label: {
            MoonPhaseGlyph(date: date)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Celestial reference")
        .accessibilityHint("Opens the qibla compass and sun and moon details")
        .accessibilityAddTraits(.isButton)
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
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(IhsanColor.brass.opacity(0.85))
            .accessibilityLabel(bucket.spokenLabel)
    }
}
