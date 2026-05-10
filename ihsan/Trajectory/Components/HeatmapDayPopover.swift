import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// Sheet content shown when the user taps a day in the daily-practice
/// grid. Shows the date (both Gregorian and Hijri) and the five-prayer
/// breakdown for that day. Read-only — editing happens on the Today
/// screen.
///
/// The sheet sits on iOS 26 Liquid Glass material; each prayer row
/// inside renders as an illuminated parchment panel, the same hybrid
/// hierarchy used for the Today screen's prayer log sheet.
struct HeatmapDayPopover: View {
    let day: DayCompletion

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text(gregorianDate)
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundStyle(IhsanColor.inkDeep)
                Text(hijriDate.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .foregroundStyle(IhsanColor.brassDark)
            }

            OrnamentalDivider()

            VStack(spacing: IhsanSpacing.sm) {
                ForEach(day.prayerCompletions, id: \.prayer) { completion in
                    prayerRow(completion)
                }
            }

            if day.isPaused {
                Label("Paused day — excluded from totals", systemImage: "pause.circle")
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .foregroundStyle(IhsanColor.brassDark)
            }
            if day.isTraveling {
                Label("Traveling", systemImage: "airplane")
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .foregroundStyle(IhsanColor.brassDark)
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
            PrayerSymbol(completion.prayer, size: 18, tint: IhsanColor.brass.opacity(0.80))
                .frame(width: 28)

            HStack(spacing: IhsanSpacing.sm) {
                Text(completion.prayer.displayNameEnglish)
                    .font(IhsanFont.rowPrayerName)
                    .foregroundStyle(IhsanColor.inkDeep)
                Text(completion.prayer.displayNameArabic)
                    .font(IhsanFont.bodyArabic)
                    .foregroundStyle(IhsanColor.inkDeep.opacity(0.72))
            }

            Spacer(minLength: IhsanSpacing.sm)

            DayPrayerCell(completion: completion, size: 26)
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, IhsanSpacing.sm)
        .ihsanIlluminatedPanel(intensity: .prayerRow)
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
