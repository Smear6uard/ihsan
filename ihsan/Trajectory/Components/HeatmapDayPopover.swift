import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// Sheet content shown when the user taps a day label in the
/// daily-practice grid. Shows the date (both Gregorian and Hijri) and
/// the five-prayer breakdown for that day, in the dot-state language.
/// Read-only — logging happens through the cells and the Today screen.
struct HeatmapDayPopover: View {
    let day: DayCompletion

    private var tokens: SkyPaletteTokens {
        IhsanPageChrome.tokens(at: .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text(gregorianDate)
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundStyle(tokens.ink)
                Text(hijriDate.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .foregroundStyle(tokens.inkSecondary)
            }

            OrnamentalDivider(tint: tokens.metal, opacity: 0.5)

            VStack(spacing: IhsanSpacing.sm) {
                ForEach(day.prayerCompletions, id: \.prayer) { completion in
                    prayerRow(completion)
                }
            }

            if day.isPaused {
                HStack(spacing: IhsanSpacing.xs) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(tokens.inkSecondary.opacity(0.5))
                        .frame(width: 10, height: 2)
                    Text("PAUSED DAY — EXCLUDED FROM TOTALS")
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                        .foregroundStyle(tokens.inkSecondary)
                }
            }
            if day.isTraveling {
                HStack(spacing: IhsanSpacing.xs) {
                    TravelPlaneMark()
                        .fill(tokens.metal.opacity(0.7))
                        .frame(width: 10, height: 10)
                    Text("TRAVELING")
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                        .foregroundStyle(tokens.inkSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(IhsanSpacing.lg)
        .padding(.top, IhsanSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func prayerRow(_ completion: PrayerCompletion) -> some View {
        HStack(spacing: IhsanSpacing.md) {
            PrayerOrnamentShape(prayer: completion.prayer, mode: .outline)
                .stroke(tokens.metal.opacity(0.85), lineWidth: 1.0)
                .frame(width: 18, height: 18)
                .frame(width: 28)
                .accessibilityHidden(true)

            HStack(spacing: IhsanSpacing.sm) {
                Text(completion.prayer.displayNameEnglish)
                    .font(IhsanFont.rowPrayerName)
                    .foregroundStyle(tokens.ink)
                Text(completion.prayer.displayNameArabic)
                    .font(IhsanFont.bodyArabic)
                    .foregroundStyle(tokens.inkSecondary)
            }

            Spacer(minLength: IhsanSpacing.sm)

            DayPrayerCell(
                completion: completion,
                isPausedDay: day.isPaused,
                size: 26,
                tokens: tokens
            )
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, IhsanSpacing.sm)
        .celestialPanel(tokens: tokens, cornerRadius: 16)
    }

    private var gregorianDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: day.date)
    }

    private var hijriDate: String {
        HijriDateFormatter.string(from: day.date)
    }
}
