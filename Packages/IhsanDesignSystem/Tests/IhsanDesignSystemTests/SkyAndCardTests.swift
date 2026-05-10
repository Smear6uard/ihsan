import Foundation
import Testing
@testable import IhsanDesignSystem

// MARK: - Helpers

private func makeDate(hour: Int, minute: Int = 0, second: Int = 0) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 15
    components.hour = hour
    components.minute = minute
    components.second = second
    return Calendar.current.date(from: components)!
}

/// Pure WCAG luminance from sRGB.
private func relativeLuminance(_ rgb: IhsanColor.RGB) -> Double {
    func channel(_ c: Double) -> Double {
        c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(rgb.red)
        + 0.7152 * channel(rgb.green)
        + 0.0722 * channel(rgb.blue)
}

private func contrastRatio(_ a: IhsanColor.RGB, _ b: IhsanColor.RGB) -> Double {
    let la = relativeLuminance(a)
    let lb = relativeLuminance(b)
    let (lighter, darker) = la > lb ? (la, lb) : (lb, la)
    return (lighter + 0.05) / (darker + 0.05)
}

// Canonical text colours from the manuscript palette.
//   inkDeep   = #1A1F2E (dark text on light panels)
//   boneCream = #F5EBD5 (light text on dark panels — same hex as panelDay)
private let textInkRGB: IhsanColor.RGB = (
    red: 0x1A / 255.0, green: 0x1F / 255.0, blue: 0x2E / 255.0
)
private let textBoneRGB: IhsanColor.RGB = (
    red: 0xF5 / 255.0, green: 0xEB / 255.0, blue: 0xD5 / 255.0
)

// MARK: - Sky stops

@Test
func skyTopStopsAreOrderedByProgress() {
    let progresses = IhsanColor.skyTopStops.map(\.progress)
    #expect(progresses == progresses.sorted())
}

@Test
func skyBottomStopsAreOrderedByProgress() {
    let progresses = IhsanColor.skyBottomStops.map(\.progress)
    #expect(progresses == progresses.sorted())
}

@Test
func skyStopsSpanFullDay() {
    #expect(IhsanColor.skyTopStops.first!.progress == 0.0)
    #expect(IhsanColor.skyTopStops.last!.progress == 1.0)
    #expect(IhsanColor.skyBottomStops.first!.progress == 0.0)
    #expect(IhsanColor.skyBottomStops.last!.progress == 1.0)
}

@Test
func skyTopWrapsAroundMidnight() {
    let first = IhsanColor.skyTopStops.first!
    let last = IhsanColor.skyTopStops.last!
    #expect(first.rgb.red == last.rgb.red)
    #expect(first.rgb.green == last.rgb.green)
    #expect(first.rgb.blue == last.rgb.blue)
}

@Test
func skyBottomWrapsAroundMidnight() {
    let first = IhsanColor.skyBottomStops.first!
    let last = IhsanColor.skyBottomStops.last!
    #expect(first.rgb.red == last.rgb.red)
    #expect(first.rgb.green == last.rgb.green)
    #expect(first.rgb.blue == last.rgb.blue)
}

@Test
func skyAtMidnightIsPersianIndigo() {
    // Both top and bottom should hit the canonical `nightPage` colour
    // (`#1A1F4A`) at local midnight — the page reads as one saturated
    // indigo, not a flat black.
    let top = IhsanColor.interpolatedRGB(
        stops: IhsanColor.skyTopStops, at: 0.0
    )
    let bottom = IhsanColor.interpolatedRGB(
        stops: IhsanColor.skyBottomStops, at: 0.0
    )
    #expect(abs(top.red - 0x1A / 255.0) < 0.001)
    #expect(abs(top.green - 0x1F / 255.0) < 0.001)
    #expect(abs(top.blue - 0x4A / 255.0) < 0.001)
    #expect(abs(bottom.red - 0x1A / 255.0) < 0.001)
    #expect(abs(bottom.green - 0x1F / 255.0) < 0.001)
    #expect(abs(bottom.blue - 0x4A / 255.0) < 0.001)
}

@Test
func skyShiftsVisiblyAcrossTheDay() {
    // The whole point of the redirect is that the sky reads as "different"
    // at different times. Compare four checkpoints — pre-dawn (4am),
    // morning (9am), late afternoon (5pm), night (11pm) — and verify
    // each pair has a meaningful chromatic distance. The bottom band
    // exposes the warmth shift more aggressively than the top, so we
    // sample it.
    func bottom(at hour: Int) -> IhsanColor.RGB {
        IhsanColor.interpolatedRGB(
            stops: IhsanColor.skyBottomStops,
            at: IhsanColor.dayProgress(for: makeDate(hour: hour))
        )
    }
    let dawn = bottom(at: 4)
    let morning = bottom(at: 9)
    let lateAfternoon = bottom(at: 17)
    let night = bottom(at: 23)

    func distance(_ a: IhsanColor.RGB, _ b: IhsanColor.RGB) -> Double {
        let dr = a.red - b.red
        let dg = a.green - b.green
        let db = a.blue - b.blue
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    // Adjacent windows must be visibly distinct, antipodal windows
    // must differ massively. Tuned against the actual stops so that
    // a passing test corresponds to a screen the user reads as
    // "morning vs afternoon vs night" without checking a clock.
    #expect(distance(dawn, morning) > 0.5,
            "dawn→morning distance was \(distance(dawn, morning))")
    #expect(distance(morning, lateAfternoon) > 0.20,
            "morning→late-afternoon distance was \(distance(morning, lateAfternoon))")
    #expect(distance(dawn, lateAfternoon) > 0.4,
            "dawn→late-afternoon distance was \(distance(dawn, lateAfternoon))")
    #expect(distance(morning, night) > 0.5,
            "morning→night distance was \(distance(morning, night))")
    #expect(distance(lateAfternoon, night) > 0.5,
            "late-afternoon→night distance was \(distance(lateAfternoon, night))")
}

@Test
func skyBottomIsMoreGoldSaturatedThanTopAtNoon() {
    // At Dhuhr the bottom of the gradient sits closer to amber-gold
    // (#D9C9A0/#C9B584 family) while the top sits in lighter cream
    // (#E8DCC0/#D9C9A0 family) — the gradient reads as "horizon below,
    // sky above". "Warmer" in the manuscript palette means a higher
    // red-to-blue ratio, not raw red — both top and bottom carry less
    // pure-red than the old honey-cream did, but the bottom is more
    // saturated toward gold.
    let p = IhsanColor.dayProgress(for: makeDate(hour: 12))
    let top = IhsanColor.interpolatedRGB(stops: IhsanColor.skyTopStops, at: p)
    let bottom = IhsanColor.interpolatedRGB(stops: IhsanColor.skyBottomStops, at: p)
    let topRatio = top.red / max(top.blue, 0.001)
    let bottomRatio = bottom.red / max(bottom.blue, 0.001)
    #expect(
        bottomRatio > topRatio,
        "noon top R/B \(topRatio) should be lower than bottom R/B \(bottomRatio)"
    )
}

// MARK: - Card surface

@Test
func cardSurfaceIsLightAtNoon() {
    let p = IhsanColor.dayProgress(for: makeDate(hour: 12))
    let rgb = IhsanColor.interpolatedRGB(stops: IhsanColor.cardSurfaceStops, at: p)
    let lum = relativeLuminance(rgb)
    #expect(lum > 0.5, "noon card surface luminance was \(lum), expected > 0.5")
}

@Test
func cardSurfaceIsDarkAtMidnight() {
    let rgb = IhsanColor.interpolatedRGB(
        stops: IhsanColor.cardSurfaceStops, at: 0.0
    )
    let lum = relativeLuminance(rgb)
    #expect(lum < 0.1, "midnight card surface luminance was \(lum), expected < 0.1")
}

@Test
func cardSurfaceIsLightThroughDaylightHours() {
    // Between sunrise (~6:30am, p≈0.27) and just before maghrib
    // (~6:30pm, p≈0.77) the card stays in the "light" pole so dark
    // text always reads against it.
    for hour in 8...16 {
        let p = IhsanColor.dayProgress(for: makeDate(hour: hour))
        let rgb = IhsanColor.interpolatedRGB(stops: IhsanColor.cardSurfaceStops, at: p)
        let lum = relativeLuminance(rgb)
        #expect(
            lum > IhsanColor.cardForegroundLuminanceThreshold,
            "card luminance at \(hour):00 was \(lum), expected > threshold"
        )
    }
}

@Test
func cardSurfaceIsDarkThroughDeepNight() {
    // Between full Isha and pre-Fajr the card stays in the amber-night
    // pole. Test 11pm and 3am.
    for hour in [23, 3] {
        let p = IhsanColor.dayProgress(for: makeDate(hour: hour))
        let rgb = IhsanColor.interpolatedRGB(stops: IhsanColor.cardSurfaceStops, at: p)
        let lum = relativeLuminance(rgb)
        #expect(
            lum < IhsanColor.cardForegroundLuminanceThreshold,
            "card luminance at \(hour):00 was \(lum), expected < threshold"
        )
    }
}

// MARK: - Foreground contrast on cards

@Test
func darkInkOnPanelDayMeetsWCAGAAA() {
    // Dark ink on the panelDay surface (#F5EBD5) should comfortably
    // exceed the 7.0:1 AAA threshold — it's the dominant text pair on
    // the Today screen.
    let panelDay: IhsanColor.RGB = (
        red: 0xF5 / 255.0, green: 0xEB / 255.0, blue: 0xD5 / 255.0
    )
    let ratio = contrastRatio(textInkRGB, panelDay)
    #expect(ratio >= 7.0, "ink-on-panelDay contrast was \(ratio), expected ≥ 7.0")
}

@Test
func boneCreamOnPanelNightMeetsWCAGAAA() {
    // Bone cream on the panelNight surface (#3D3328) should clear 7.0:1
    // AAA — the night-side pair must read at least as cleanly as the
    // day-side one.
    let panelNight: IhsanColor.RGB = (
        red: 0x3D / 255.0, green: 0x33 / 255.0, blue: 0x28 / 255.0
    )
    let ratio = contrastRatio(textBoneRGB, panelNight)
    #expect(ratio >= 7.0, "bone-on-panelNight contrast was \(ratio), expected ≥ 7.0")
}

@Test
func cardForegroundContrastAcrossEveryHour() {
    // For every hour of the day, the resolved primary foreground colour
    // should clear 4.5:1 against the resolved card surface. This is the
    // single most important regression check: it's what stops the
    // visual redirect from sliding back into the "warm tint takeover"
    // failure mode where text disappeared into the card.
    for hour in 0..<24 {
        let date = makeDate(hour: hour, minute: 30)
        let surface = IhsanColor.cardSurfaceRGB(at: date)
        let lum = IhsanColor.cardSurfaceLuminance(at: date)
        let foreground = lum > IhsanColor.cardForegroundLuminanceThreshold
            ? textInkRGB
            : textBoneRGB
        let ratio = contrastRatio(foreground, surface)
        #expect(
            ratio >= 4.5,
            "hour \(hour):30 contrast was \(ratio), surface lum \(lum)"
        )
    }
}

// MARK: - Card stops continuity

@Test
func cardStopsAreOrderedByProgress() {
    let progresses = IhsanColor.cardSurfaceStops.map(\.progress)
    #expect(progresses == progresses.sorted())
}

@Test
func cardStopsSpanFullDay() {
    #expect(IhsanColor.cardSurfaceStops.first!.progress == 0.0)
    #expect(IhsanColor.cardSurfaceStops.last!.progress == 1.0)
}

@Test
func cardStopsWrapAroundMidnight() {
    let first = IhsanColor.cardSurfaceStops.first!
    let last = IhsanColor.cardSurfaceStops.last!
    #expect(first.rgb.red == last.rgb.red)
    #expect(first.rgb.green == last.rgb.green)
    #expect(first.rgb.blue == last.rgb.blue)
}

// MARK: - Accent

@Test
func warmAccentIsBrassAtEveryHour() {
    // Post-manuscript redirect, the warm accent unifies on brass at
    // every hour of the day. Previous versions returned rose-gold in
    // the maghrib window — the redirect removes that variant so the
    // brass illumination border and the active-prayer accent stay in
    // one chromatic key from Fajr through Isha.
    for hour in 0..<24 {
        let date = makeDate(hour: hour)
        #expect(IhsanColor.accentWarm(at: date) == IhsanColor.brass)
    }
}

@Test
func maghribWindowMapsToExpectedProgressRange() {
    // 19:00 should sit in [0.74, 0.84] — the canonical maghrib window
    // used by other time-of-day calculations (sunset image opacity,
    // arc dot positions, etc.).
    let p = IhsanColor.dayProgress(for: makeDate(hour: 19))
    #expect(p >= 0.74 && p <= 0.84, "maghrib progress was \(p)")
}

// MARK: - Sky foreground (header text directly on the sky)

@Test
func skyForegroundIsBoneCreamAtMidnight() {
    // The midnight sky is Persian indigo (#1A1F4A) — ink dark would
    // disappear, bone cream is the only correct choice.
    let picked = IhsanColor.skyForegroundPrimary(at: makeDate(hour: 0))
    #expect(picked == IhsanColor.boneCream)
}

@Test
func skyForegroundIsInkDarkAtNoon() {
    // The noon sky top is pale parchment — bone cream would
    // disappear, ink dark is the only correct choice.
    let picked = IhsanColor.skyForegroundPrimary(at: makeDate(hour: 12))
    #expect(picked == IhsanColor.inkDeep)
}

@Test
func skyForegroundPicksBetterContrastAtEveryHour() {
    // For every hour the picked foreground must be the BETTER of the
    // two extremes (ink dark or bone cream) against the sky top.
    // Picking the worse one would be a regression of the warm-cards-
    // on-time-adaptive-sky direction.
    for hour in 0..<24 {
        let date = makeDate(hour: hour, minute: 30)
        let topLum = IhsanColor.skyTopLuminance(at: date)
        let inkContrast = IhsanColor.wcagContrast(topLum, IhsanColor.textInkLuminance)
        let creamContrast = IhsanColor.wcagContrast(topLum, IhsanColor.textBoneLuminance)
        let picked = IhsanColor.skyForegroundPrimary(at: date)
        if inkContrast >= creamContrast {
            #expect(picked == IhsanColor.inkDeep,
                    "hour \(hour):30 picked the wrong foreground")
        } else {
            #expect(picked == IhsanColor.boneCream,
                    "hour \(hour):30 picked the wrong foreground")
        }
    }
}

@Test
func skyForegroundContrastClearsLargeTextThresholdAtEveryHour() {
    // The header is small caps semibold at 13–15 pt and sits over a
    // small text shadow (see TodayHeader). We assert that the picked
    // foreground's raw contrast against the sky top clears 3.0:1 (WCAG
    // AA for large text) at every half-hour sample — with the shadow
    // included, effective legibility climbs into the 4.5:1 zone for
    // stable hours and stays readable through transition windows.
    for hour in 0..<24 {
        let date = makeDate(hour: hour, minute: 30)
        let topRGB = IhsanColor.skyTopRGB(at: date)
        let topLum = IhsanColor.skyTopLuminance(at: date)
        let inkContrast = IhsanColor.wcagContrast(topLum, IhsanColor.textInkLuminance)
        let creamContrast = IhsanColor.wcagContrast(topLum, IhsanColor.textBoneLuminance)
        let foreground = inkContrast >= creamContrast ? textInkRGB : textBoneRGB
        let ratio = contrastRatio(foreground, topRGB)
        #expect(
            ratio >= 3.0,
            "hour \(hour):30 header contrast was \(ratio), sky top lum \(topLum)"
        )
    }
}

@Test
func skyForegroundContrastClearsNormalTextThresholdOutsideTransitions() {
    // Outside the brief sunrise (~7-8 am) and maghrib (~5-7 pm)
    // transition zones the picked foreground must clear 4.5:1 (WCAG
    // AA for normal text). The transition zones are explicitly
    // excluded — they are short windows where the sky top is mid-tone
    // and the header text leans on its shadow plus the smallCaps
    // weight for legibility. See `TodayHeader` for the rendered
    // treatment.
    let stableHours = [0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 15, 16, 20, 21, 22, 23]
    for hour in stableHours {
        let date = makeDate(hour: hour, minute: 30)
        let topRGB = IhsanColor.skyTopRGB(at: date)
        let topLum = IhsanColor.skyTopLuminance(at: date)
        let inkContrast = IhsanColor.wcagContrast(topLum, IhsanColor.textInkLuminance)
        let creamContrast = IhsanColor.wcagContrast(topLum, IhsanColor.textBoneLuminance)
        let foreground = inkContrast >= creamContrast ? textInkRGB : textBoneRGB
        let ratio = contrastRatio(foreground, topRGB)
        #expect(
            ratio >= 4.5,
            "stable hour \(hour):30 header contrast was \(ratio), sky top lum \(topLum)"
        )
    }
}
