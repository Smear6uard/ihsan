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
///   middle dot. The "NEXT" inscription refreshes once per minute via
///   `TimelineView` so the user can glance at the screen and see when
///   the next prayer is without tapping anything.
/// - **Moon-phase glyph** in the top-right corner. Shows the current
///   lunar phase as a small brass icon — AND is the tap target for
///   the celestial reference / qibla compass overlay. A 44pt
///   invisible bounding box keeps the tap target comfortable even
///   though the visible glyph is ~22pt.
struct TodayHeader: View {
    let cityName: String
    let date: Date
    /// The day's five fardh times, used to compute the "NEXT: …"
    /// inscription. Optional so non-ready states can render the
    /// header without prayer data.
    let dayTimes: DayPrayerTimes?
    /// Tap callback for the moon-phase glyph — opens the celestial
    /// reference / qibla compass overlay.
    let onMoonPhaseTap: () -> Void

    @Environment(\.timeOfDayOverride) private var override
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let override {
            renderHeader(referenceDate: override)
        } else if reduceMotion {
            renderHeader(referenceDate: date)
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                renderHeader(referenceDate: context.date)
            }
        }
    }

    @ViewBuilder
    private func renderHeader(referenceDate: Date) -> some View {
        let foreground = IhsanColor.skyForegroundPrimary(at: referenceDate)
        let foregroundSecondary = IhsanColor.skyForegroundSecondary(at: referenceDate)
        let shadowColor = legibilityShadowColor(for: foreground)
        let nextInscription = nextPrayerInscription(at: referenceDate)

        HStack(alignment: .top, spacing: IhsanSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cityName)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: shadowColor, radius: 2, x: 0, y: 0.5)

                inscriptionLine(
                    referenceDate: referenceDate,
                    nextInscription: nextInscription,
                    foreground: foregroundSecondary,
                    shadowColor: shadowColor
                )
            }

            Spacer(minLength: IhsanSpacing.sm)

            MoonPhaseTapTarget(
                date: referenceDate,
                onTap: onMoonPhaseTap
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(referenceDate: referenceDate, nextInscription: nextInscription))
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func inscriptionLine(
        referenceDate: Date,
        nextInscription: String?,
        foreground: Color,
        shadowColor: Color
    ) -> some View {
        let hijri = HijriDateFormatter.string(from: referenceDate)
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

    /// "NEXT: DHUHR 12:50 PM" — the next-upcoming prayer with its
    /// scheduled time. Returns `nil` when no day times are available
    /// (loading state) or, theoretically, when every prayer has
    /// passed (last fallback covers Isha→Fajr-tomorrow).
    private func nextPrayerInscription(at referenceDate: Date) -> String? {
        guard let dayTimes else { return nil }
        let next = dayTimes.allFardh.first { $0.scheduledTime > referenceDate }
            ?? dayTimes.allFardh.first
        guard let next else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = formatter.string(from: next.scheduledTime).uppercased()
        let name = next.prayer.displayNameEnglish.uppercased()
        return "NEXT: \(name) \(time)"
    }

    private func legibilityShadowColor(for foreground: Color) -> Color {
        foreground == IhsanColor.inkDeep
            ? .white.opacity(0.42)
            : .black.opacity(0.48)
    }

    private func accessibilityLabel(referenceDate: Date, nextInscription: String?) -> String {
        let hijri = HijriDateFormatter.string(from: referenceDate)
        var parts = ["Location: \(cityName)", "Hijri date: \(hijri)"]
        if let dayTimes,
           let next = dayTimes.allFardh.first(where: { $0.scheduledTime > referenceDate }) ?? dayTimes.allFardh.first {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            parts.append("Next prayer: \(next.prayer.displayNameEnglish) at \(formatter.string(from: next.scheduledTime))")
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
            .shadow(color: IhsanColor.brass.opacity(0.35), radius: 2, x: 0, y: 0)
            .accessibilityLabel(bucket.spokenLabel)
    }
}
