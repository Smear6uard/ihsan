import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// Sheet content shown when the user taps a heatmap dot. Shows the date in
/// both Gregorian and Hijri, then the five-prayer breakdown for that day.
/// Read-only — editing happens on the Today screen.
struct HeatmapDayPopover: View {
    let day: DayCompletion

    var body: some View {
        ZStack {
            IhsanColor.ground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                Text(formattedDate)
                    .font(IhsanFont.smallCaps)
                    .tracking(0.8)
                    .foregroundStyle(IhsanColor.textMuted)

                VStack(spacing: IhsanSpacing.sm) {
                    ForEach(day.prayerCompletions, id: \.prayer) { completion in
                        prayerRow(completion)
                    }
                }

                if day.isPaused {
                    Label("Paused day — excluded from totals", systemImage: "pause.circle")
                        .font(IhsanFont.smallCaps)
                        .tracking(0.8)
                        .foregroundStyle(IhsanColor.textMuted)
                }
                if day.isTraveling {
                    Label("Traveling", systemImage: "airplane")
                        .font(IhsanFont.smallCaps)
                        .tracking(0.8)
                        .foregroundStyle(IhsanColor.textMuted)
                }

                Spacer(minLength: 0)
            }
            .padding(IhsanSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func prayerRow(_ completion: PrayerCompletion) -> some View {
        HStack(spacing: IhsanSpacing.md) {
            PrayerSymbol(completion.prayer, size: 18)
                .frame(width: 28)

            HStack(spacing: IhsanSpacing.sm) {
                Text(completion.prayer.displayNameEnglish)
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(IhsanColor.textPrimary)
                Text(completion.prayer.displayNameArabic)
                    .font(IhsanFont.bodyArabic)
                    .foregroundStyle(IhsanColor.textSecondary)
            }

            Spacer(minLength: IhsanSpacing.sm)

            if let status = completion.status {
                StatusPill(status)
            } else {
                Text("—")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.textMuted)
            }
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, IhsanSpacing.sm)
        .ihsanGlass(intensity: .subtle)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        let gregorian = f.string(from: day.date)
        let hijri = HijriDateFormatter.string(from: day.date)
        return "\(gregorian)  ·  \(hijri)"
    }
}
