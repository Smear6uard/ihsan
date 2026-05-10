import SwiftUI
import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes

/// Hero countdown — the principal illumination on the Today screen.
///
/// Composed as a single illuminated panel: parchment body, brass
/// illumination border, four-pointed corner ornaments, a refined serif
/// prayer-name header, an ornamental brass divider with a centred star
/// flourish, the tabular countdown digits, and a small-caps brass
/// inscription beneath. During the ±15 min sunrise window and the
/// ±10 min maghrib window the `daylight-sunrise` / `daylight-maghrib`
/// photographs surface as a subtle textural layer inside the card —
/// quiet atmospheric warmth, never dominant.
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
            let sunriseOpacity = sunriseTextureOpacity(at: context.date)
            let maghribOpacity = maghribTextureOpacity(at: context.date)

            ZStack {
                VStack(spacing: IhsanSpacing.md) {
                    // Prayer name in refined serif. Arabic and English
                    // share the baseline; the iftar pill (Ramadan only)
                    // sits to the right as a small brass capsule.
                    HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
                        Text(snapshot.nextPrayerTime.prayer.displayNameEnglish)
                            .font(IhsanFont.heroPrayerName)
                            .foregroundStyle(foreground)
                        Text(snapshot.nextPrayerTime.prayer.displayNameArabic)
                            .font(IhsanFont.bodyArabic)
                            .foregroundStyle(foregroundSecondary)
                        if countingDownToIftar {
                            iftarPill(foreground: foreground)
                        }
                    }

                    // Ornamental brass divider — feathered rule with a
                    // small four-pointed star flourish at its centre.
                    // The single most distinctive detail inside the
                    // hero panel; it's what reads as "illuminated page"
                    // rather than "tinted card".
                    OrnamentalDivider(
                        tint: IhsanColor.brass,
                        opacity: 0.40,
                        starSize: 7,
                        ruleWidth: 220
                    )

                    // Tabular countdown — the visual heart of the card.
                    Text(countdown)
                        .font(IhsanFont.heroCountdown)
                        .foregroundStyle(foreground)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .snappy(duration: 0.25),
                                   value: remaining)
                        .accessibilityLabel(accessibilityLabel(for: spokenCountdown, at: context.date))

                    // Small-caps brass inscription — "UNTIL ASR".
                    // Letter-spaced so it reads as inscribed text, not
                    // as a UI label.
                    Text(effectiveLabel(at: context.date).uppercased())
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .foregroundStyle(IhsanColor.brass.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, IhsanSpacing.xl)
                .padding(.horizontal, IhsanSpacing.lg)
                .overlay(alignment: .topLeading) {
                    cornerOrnament
                        .padding(IhsanSpacing.sm + 2)
                }
                .overlay(alignment: .topTrailing) {
                    cornerOrnament
                        .padding(IhsanSpacing.sm + 2)
                }
                .overlay(alignment: .bottomLeading) {
                    cornerOrnament
                        .padding(IhsanSpacing.sm + 2)
                }
                .overlay(alignment: .bottomTrailing) {
                    cornerOrnament
                        .padding(IhsanSpacing.sm + 2)
                }
                .background {
                    DaylightTexture(
                        sunriseOpacity: sunriseOpacity,
                        maghribOpacity: maghribOpacity
                    )
                }
                .ihsanIlluminatedPanel(intensity: .hero)
            }
        }
    }

    /// Small four-pointed star at each corner of the panel — the only
    /// ornamental device on the hero card besides the divider flourish.
    /// Kept deliberately small (5pt) and low-opacity so it reads as
    /// illumination, not decoration.
    private var cornerOrnament: some View {
        OrnamentalFlourish(
            size: 5,
            tint: IhsanColor.brass,
            opacity: 0.55
        )
    }

    private func iftarPill(foreground: Color) -> some View {
        Text("Iftar")
            .font(IhsanFont.inscription)
            .tracking(1.2)
            .foregroundStyle(IhsanColor.brass)
            .padding(.horizontal, IhsanSpacing.sm)
            .padding(.vertical, IhsanSpacing.xs)
            .background {
                Capsule()
                    .fill(IhsanColor.brass.opacity(0.14))
                    .overlay {
                        Capsule()
                            .strokeBorder(IhsanColor.brass.opacity(0.55), lineWidth: 0.6)
                    }
            }
            .accessibilityHidden(true)
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

    private func sunriseTextureOpacity(at date: Date) -> Double {
        let now = effectiveDate(at: date)
        return triangularOpacity(
            at: now,
            center: snapshot.dayTimes.sunrise,
            halfWidthSeconds: 15 * 60,
            peak: 0.25
        )
    }

    private func maghribTextureOpacity(at date: Date) -> Double {
        let now = effectiveDate(at: date)
        return triangularOpacity(
            at: now,
            center: snapshot.dayTimes.maghrib.scheduledTime,
            halfWidthSeconds: 10 * 60,
            peak: 0.25
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

/// Photographic texture layer for the hero panel. Renders the
/// `daylight-sunrise` and `daylight-maghrib` assets at their computed
/// opacities (zero outside their windows). The image sits behind the
/// countdown content as page texture, not as a foreground photograph —
/// 25% peak opacity, multiplied so the warmth lifts the cream / amber
/// surface without overwhelming the text contrast.
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
                    .blendMode(.multiply)
            }
            if maghribOpacity > 0 {
                Image("daylight-maghrib")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(maghribOpacity)
                    .blendMode(.multiply)
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
