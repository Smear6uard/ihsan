import SwiftUI
import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes

struct TodayHeroSection: View {
    let snapshot: TodayState.Snapshot

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let target = effectiveTargetTime
            let remaining = max(0, target.timeIntervalSince(context.date))
            let countdown = formatted(seconds: remaining)

            VStack(spacing: IhsanSpacing.md) {
                HStack(spacing: IhsanSpacing.sm) {
                    Text(snapshot.nextPrayerTime.prayer.displayNameEnglish)
                        .font(IhsanFont.subtitle)
                        .foregroundStyle(IhsanColor.textPrimary)
                    Text(snapshot.nextPrayerTime.prayer.displayNameArabic)
                        .font(IhsanFont.bodyArabic)
                        .foregroundStyle(IhsanColor.textSecondary)
                }

                Text(countdown)
                    .font(IhsanFont.heroCountdown)
                    .foregroundStyle(IhsanColor.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.25), value: remaining)
                    .accessibilityLabel(accessibilityLabel(for: countdown))

                Text(effectiveLabel.uppercased())
                    .font(IhsanFont.smallCaps)
                    .foregroundStyle(IhsanColor.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, IhsanSpacing.lg)
            .padding(.horizontal, IhsanSpacing.md)
            .ihsanGlassHero()
        }
    }

    /// During the Fajr→sunrise window the countdown anchors to sunrise (the
    /// practical end of Fajr's window) instead of the next listed prayer.
    private var effectiveTargetTime: Date {
        if snapshot.isWithinFajrToSunriseWindow {
            return snapshot.dayTimes.sunrise
        }
        return snapshot.nextPrayerTime.scheduledTime
    }

    private var effectiveLabel: String {
        if snapshot.isWithinFajrToSunriseWindow {
            return "Fajr ends in"
        }
        return "Until \(snapshot.nextPrayerTime.prayer.displayNameEnglish.lowercased())"
    }

    private func formatted(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "−%02d:%02d:%02d", h, m, s)
    }

    private func accessibilityLabel(for countdown: String) -> String {
        let prayerName = snapshot.nextPrayerTime.prayer.displayNameEnglish
        if snapshot.isWithinFajrToSunriseWindow {
            return "\(countdown) until Fajr's window ends at sunrise"
        }
        return "\(countdown) until \(prayerName)"
    }
}
