import SwiftUI
import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes

struct TodayHeroSection: View {
    let snapshot: TodayState.Snapshot

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.timeOfDayOverride) private var timeOverride

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let target = effectiveTargetTime
            let remaining = max(0, target.timeIntervalSince(context.date))
            let countdown = formatted(seconds: remaining)
            let spokenCountdown = spokenCountdown(seconds: remaining)
            let countingDownToIftar = isCountingDownToIftar(at: context.date)
            // Source the tint from the same Date that the glass material
            // uses, so the digit glow, divider, and label colour all sit
            // in the same chromatic key as the surface they live on.
            let tintReferenceDate = timeOverride ?? context.date
            let tint = IhsanColor.adaptiveTint(at: tintReferenceDate)

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

                // Thin tinted hairline separating the prayer name from
                // the countdown. The line is the adaptive tint at 30%
                // opacity, with a softer gradient at the ends so it
                // doesn't read as a hard border.
                LinearGradient(
                    colors: [.clear, tint.opacity(0.30), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: IhsanSpacing.hairline)
                .frame(maxWidth: 220)
                .accessibilityHidden(true)

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
                    .animation(reduceMotion ? nil : .snappy(duration: 0.25),
                               value: remaining)
                    // Soft luminous halo behind the digits. The same tint
                    // that colours the glass surface here radiates from
                    // the numbers — the hero card reads as a vessel
                    // catching the light of the hour rather than a
                    // surface displaying a number.
                    .shadow(color: tint.opacity(0.55), radius: 12, x: 0, y: 0)
                    .shadow(color: tint.opacity(0.30), radius: 24, x: 0, y: 0)
                    .accessibilityLabel(accessibilityLabel(for: spokenCountdown, at: context.date))

                Text(effectiveLabel(at: context.date).uppercased())
                    .font(IhsanFont.smallCaps)
                    .foregroundStyle(tint.opacity(0.65))
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

    /// Human-readable countdown for VoiceOver. The visible "−02:34:15"
    /// reads as "minus zero two colon..." which is useless; this returns
    /// "2 hours, 34 minutes, 15 seconds".
    private func spokenCountdown(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hour\(h == 1 ? "" : "s")") }
        if m > 0 { parts.append("\(m) minute\(m == 1 ? "" : "s")") }
        if h == 0 { parts.append("\(s) second\(s == 1 ? "" : "s")") }
        return parts.isEmpty ? "0 seconds" : parts.joined(separator: ", ")
    }

    private func accessibilityLabel(for spokenCountdown: String, at date: Date) -> String {
        let prayerName = snapshot.nextPrayerTime.prayer.displayNameEnglish
        if snapshot.isWithinFajrToSunriseWindow {
            return "\(spokenCountdown) until Fajr's window ends at sunrise"
        }
        if isCountingDownToIftar(at: date) {
            return "\(spokenCountdown) until iftar at Maghrib"
        }
        return "\(spokenCountdown) until \(prayerName)"
    }
}
