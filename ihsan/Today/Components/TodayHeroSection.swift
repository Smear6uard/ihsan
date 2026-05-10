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
            let now = effectiveDate(at: context.date)
            let target = effectiveTargetTime
            let remaining = max(0, target.timeIntervalSince(context.date))
            let countdown = formatted(seconds: remaining)
            let spokenCountdown = spokenCountdown(seconds: remaining)
            let countingDownToIftar = isCountingDownToIftar(at: context.date)

            let foreground = IhsanColor.cardForegroundPrimary(at: now)
            let foregroundSecondary = IhsanColor.cardForegroundSecondary(at: now)
            let foregroundMuted = IhsanColor.cardForegroundMuted(at: now)
            let accent = IhsanColor.accentWarm(at: now)
            let sunriseOpacity = sunriseTextureOpacity(at: context.date)
            let maghribOpacity = maghribTextureOpacity(at: context.date)

            VStack(spacing: IhsanSpacing.md) {
                HStack(spacing: IhsanSpacing.sm) {
                    Text(snapshot.nextPrayerTime.prayer.displayNameEnglish)
                        .font(IhsanFont.subtitle)
                        .foregroundStyle(foreground)
                    Text(snapshot.nextPrayerTime.prayer.displayNameArabic)
                        .font(IhsanFont.bodyArabic)
                        .foregroundStyle(foregroundSecondary)
                    if countingDownToIftar {
                        Text("Iftar")
                            .font(IhsanFont.smallCaps)
                            .foregroundStyle(foreground.opacity(0.88))
                            .padding(.horizontal, IhsanSpacing.sm)
                            .padding(.vertical, IhsanSpacing.xs)
                            .background {
                                Capsule()
                                    .fill(accent.opacity(0.18))
                                    .overlay {
                                        Capsule()
                                            .strokeBorder(accent.opacity(0.55), lineWidth: 0.6)
                                    }
                            }
                            .accessibilityHidden(true)
                    }
                }

                // Thin tinted hairline separating the prayer name from
                // the countdown. The line picks up the card foreground
                // colour at low opacity so it reads as paper-rule on a
                // cream card during the day and as a faint cream line on
                // the amber night card.
                LinearGradient(
                    colors: [.clear, foreground.opacity(0.28), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: IhsanSpacing.hairline)
                .frame(maxWidth: 220)
                .accessibilityHidden(true)

                Text(countdown)
                    .font(IhsanFont.heroCountdown)
                    .foregroundStyle(foreground)
                    .monospacedDigit()
                    // The hero countdown shrinks rather than wrapping
                    // at the largest Dynamic Type sizes — wrapping a
                    // tabular timer would break the visual cadence of
                    // the digits.
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .snappy(duration: 0.25),
                               value: remaining)
                    .accessibilityLabel(accessibilityLabel(for: spokenCountdown, at: context.date))

                Text(effectiveLabel(at: context.date).uppercased())
                    .font(IhsanFont.smallCaps)
                    .foregroundStyle(foregroundMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, IhsanSpacing.lg)
            .padding(.horizontal, IhsanSpacing.md)
            // The daylight image sits BETWEEN the warm card material and
            // the foreground content. It only contributes inside the
            // sunrise / maghrib windows; outside them the layer renders
            // nothing and the card reads as solid warm cream / amber.
            .background {
                DaylightTexture(
                    sunriseOpacity: sunriseOpacity,
                    maghribOpacity: maghribOpacity
                )
            }
            .ihsanWarmCardHero()
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

    private func effectiveDate(at clock: Date) -> Date {
        timeOverride ?? clock
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

    // MARK: - Daylight texture windows
    //
    // The two photographic assets sit INSIDE the hero card during the
    // ±15 min sunrise window and the ±10 min maghrib window. Outside
    // those windows they contribute nothing visually, so the card
    // reads as solid warm cream / amber glass.

    private func sunriseTextureOpacity(at date: Date) -> Double {
        let now = effectiveDate(at: date)
        return triangularOpacity(
            at: now,
            center: snapshot.dayTimes.sunrise,
            halfWidthSeconds: 15 * 60,
            peak: 0.38
        )
    }

    private func maghribTextureOpacity(at date: Date) -> Double {
        let now = effectiveDate(at: date)
        return triangularOpacity(
            at: now,
            center: snapshot.dayTimes.maghrib.scheduledTime,
            halfWidthSeconds: 10 * 60,
            peak: 0.40
        )
    }

    /// Linear 0 → peak → 0 ramp across `[center − halfWidth, center +
    /// halfWidth]`. Returns 0 outside the window so the layer renders
    /// nothing.
    private func triangularOpacity(
        at date: Date,
        center: Date,
        halfWidthSeconds: TimeInterval,
        peak: Double
    ) -> Double {
        let delta = abs(date.timeIntervalSince(center))
        guard delta < halfWidthSeconds else { return 0 }
        let ramp = max(0, min(1, 1 - delta / halfWidthSeconds))
        return ramp * peak
    }
}

/// Photographic texture layer for the hero card. Renders the
/// `daylight-sunrise` and `daylight-maghrib` assets at their computed
/// opacities (zero outside their windows) clipped to the card shape,
/// with `.overlay` blend so the warmth of the horizon band lifts the
/// cream card without ever dominating it.
private struct DaylightTexture: View {
    let sunriseOpacity: Double
    let maghribOpacity: Double

    var body: some View {
        ZStack {
            if sunriseOpacity > 0 {
                Image("daylight-sunrise")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(sunriseOpacity)
                    .blendMode(.overlay)
            }
            if maghribOpacity > 0 {
                Image("daylight-maghrib")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(maghribOpacity)
                    .blendMode(.overlay)
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: IhsanSpacing.cardRadius, style: .continuous)
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
