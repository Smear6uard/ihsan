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
            let countingDownToIftar = isCountingDownToIftar(at: context.date)

            VStack(spacing: IhsanSpacing.md) {
                HStack(spacing: IhsanSpacing.sm) {
                    Text(snapshot.nextPrayerTime.prayer.displayNameEnglish)
                        .font(IhsanFont.subtitle)
                        .foregroundStyle(IhsanColor.textPrimary)
                    Text(snapshot.nextPrayerTime.prayer.displayNameArabic)
                        .font(IhsanFont.bodyArabic)
                        .foregroundStyle(IhsanColor.textSecondary)
                    if countingDownToIftar {
                        Text("Iftar")
                            .font(IhsanFont.smallCaps)
                            .foregroundStyle(IhsanColor.textPrimary.opacity(0.82))
                            .padding(.horizontal, IhsanSpacing.sm)
                            .padding(.vertical, IhsanSpacing.xs)
                            .background {
                                Capsule()
                                    .fill(IhsanColor.textPrimary.opacity(0.08))
                                    .overlay {
                                        Capsule()
                                            .strokeBorder(IhsanColor.atmospheric, lineWidth: 0.5)
                                    }
                            }
                            .accessibilityHidden(true)
                    }
                }

                Text(countdown)
                    .font(IhsanFont.heroCountdown)
                    .foregroundStyle(IhsanColor.textPrimary)
                    .monospacedDigit()
                    // Allow the hero countdown to shrink rather than wrap or
                    // truncate at the largest Dynamic Type sizes — wrapping a
                    // tabular timer breaks the visual cadence of the digits.
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.25), value: remaining)
                    .accessibilityLabel(accessibilityLabel(for: countdown, at: context.date))

                Text(effectiveLabel(at: context.date).uppercased())
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

    private func effectiveLabel(at date: Date) -> String {
        if snapshot.isWithinFajrToSunriseWindow {
            return "Fajr ends in"
        }
        if isCountingDownToIftar(at: date) {
            return "Iftar in · until Maghrib"
        }
        return "Until \(snapshot.nextPrayerTime.prayer.displayNameEnglish.lowercased())"
    }

    private func isCountingDownToIftar(at date: Date) -> Bool {
        snapshot.isCountingDownToIftar && date < snapshot.nextPrayerTime.scheduledTime
    }

    private func formatted(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "−%02d:%02d:%02d", h, m, s)
    }

    private func accessibilityLabel(for countdown: String, at date: Date) -> String {
        let prayerName = snapshot.nextPrayerTime.prayer.displayNameEnglish
        if snapshot.isWithinFajrToSunriseWindow {
            return "\(countdown) until Fajr's window ends at sunrise"
        }
        if isCountingDownToIftar(at: date) {
            return "\(countdown) until iftar at Maghrib"
        }
        return "\(countdown) until \(prayerName)"
    }
}
