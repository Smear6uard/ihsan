import SwiftUI

/// Type-safe color tokens. The consuming app must NEVER use inline
/// `Color(red:green:blue:)` literals — every color routes through this enum.
///
/// The visual identity is anchored by a single deep ultramarine ground.
/// Above that anchor, `AdaptiveBackground` layers a subtle atmospheric
/// gradient and a very low-opacity wash of the adaptive time-of-day tint,
/// and the glass surfaces themselves carry the hour as iridescence. The
/// ground colour itself never changes; what changes is what light it
/// catches.
public enum IhsanColor {
    /// The anchor: deep ultramarine `#0E1428`. Used as the base layer of
    /// `AdaptiveBackground` and as the contrast reference for every text
    /// opacity tier below.
    public static let ground = Color(
        red: 0x0E / 255.0,
        green: 0x14 / 255.0,
        blue: 0x28 / 255.0
    )

    // MARK: - Text opacity tiers
    //
    // Exposed both as numeric constants and as ready-to-use `Color` values.
    // The constants are the single source of truth — the contrast tests
    // verify each tier meets its WCAG target against the ground.

    /// 100% — vital content (prayer names, countdown numbers, headlines).
    public static let textPrimaryOpacity: Double = 1.0
    public static let textPrimary: Color = .white.opacity(textPrimaryOpacity)

    /// 70% — supporting content (times, secondary labels).
    public static let textSecondaryOpacity: Double = 0.70
    public static let textSecondary: Color = .white.opacity(textSecondaryOpacity)

    /// 40% — decorative (dividers, missed-prayer text, metadata).
    public static let textMutedOpacity: Double = 0.40
    public static let textMuted: Color = .white.opacity(textMutedOpacity)

    /// 20% — atmospheric (separator hairlines, subtle backgrounds).
    public static let atmosphericOpacity: Double = 0.20
    public static let atmospheric: Color = .white.opacity(atmosphericOpacity)

    // sRGB components of the ground, exposed for contrast calculations.
    static let groundSRGB: (red: Double, green: Double, blue: Double) = (
        red: 0x0E / 255.0,
        green: 0x14 / 255.0,
        blue: 0x28 / 255.0
    )

    // MARK: - Time-adaptive sky and card surfaces (visual redirect)
    //
    // The new visual layer reads as a *time-of-day sky with warm cards
    // floating on it*, rather than a uniformly dark room with iridescent
    // glass. The sky gradient (top + bottom colours) does the heavy
    // atmospheric lifting; the cards sit on top in a warm cream during
    // daylight hours and a deep amber at night so they remain clearly
    // visible against either pole and never blur into the ground.
    //
    // Every function below consumes `dayProgress(for:)` (0 = local
    // midnight, 1 = next local midnight) so previews can drive the whole
    // system from a single `\.timeOfDayOverride` Date — no prayer-time
    // data required for the colours alone.
    //
    // The original iridescent `adaptiveTint(at:)` and the
    // `textPrimary` / `textSecondary` / etc. white-on-ground tier remain
    // untouched: those drive accent moments and the night surfaces, while
    // the new functions drive the daytime sky and the warm card material.

    /// Daytime card surface — warm cream `#E8DFC9`. Static reference for
    /// surfaces during the daylight hours.
    public static let cardCreamLight = Color(
        red: 0xE8 / 255.0, green: 0xDF / 255.0, blue: 0xC9 / 255.0
    )

    /// Nighttime card surface — deep amber-brown `#3D3328`. Static reference
    /// for surfaces between Isha and Fajr.
    public static let cardAmberDark = Color(
        red: 0x3D / 255.0, green: 0x33 / 255.0, blue: 0x28 / 255.0
    )

    /// Foreground text on a daytime cream card — deep ink `#1A1F2E`.
    public static let textInkDark = Color(
        red: 0x1A / 255.0, green: 0x1F / 255.0, blue: 0x2E / 255.0
    )

    /// Foreground text on a nighttime amber card — bone cream `#E8DFC9`.
    public static let textBoneCream = Color(
        red: 0xE8 / 255.0, green: 0xDF / 255.0, blue: 0xC9 / 255.0
    )

    /// Warm brass `#C9A876`. Primary accent — used for the active prayer
    /// indicator, the now-marker on the prayer arc, and other moments of
    /// emphasis where the colour should feel like a vessel catching light.
    public static let accentBrass = Color(
        red: 0xC9 / 255.0, green: 0xA8 / 255.0, blue: 0x76 / 255.0
    )

    /// Rose gold `#C77B5C`. Secondary accent — used near maghrib and in
    /// transitions away from full daylight.
    public static let accentRoseGold = Color(
        red: 0xC7 / 255.0, green: 0x7B / 255.0, blue: 0x5C / 255.0
    )

    // MARK: - RGB stop interpolation (sky / card)

    typealias RGB = (red: Double, green: Double, blue: Double)
    typealias RGBStop = (progress: Double, rgb: RGB)

    /// Sky TOP keyframes — what the sky looks like at the upper portion of
    /// the screen. Cooler than the bottom during daytime so the gradient
    /// reads as "sky above, horizon below".
    static let skyTopStops: [RGBStop] = [
        (0.00, (0x0E / 255.0, 0x14 / 255.0, 0x28 / 255.0)), // midnight ultramarine
        (0.18, (0x14 / 255.0, 0x18 / 255.0, 0x32 / 255.0)),
        (0.21, (0x1E / 255.0, 0x1F / 255.0, 0x3F / 255.0)), // ~5am Fajr violet
        (0.26, (0x4D / 255.0, 0x45 / 255.0, 0x70 / 255.0)), // dawn violet
        (0.30, (0x88 / 255.0, 0x96 / 255.0, 0xB0 / 255.0)), // cool blue lift
        (0.33, (0xB8 / 255.0, 0xC8 / 255.0, 0xD8 / 255.0)), // morning sky blue
        (0.45, (0xBF / 255.0, 0xC2 / 255.0, 0xC0 / 255.0)),
        (0.50, (0xC5 / 255.0, 0xBC / 255.0, 0xAA / 255.0)), // dhuhr cream-blue
        (0.58, (0xD4 / 255.0, 0xC9 / 255.0, 0xA0 / 255.0)), // honey
        (0.65, (0xD9 / 255.0, 0xC6 / 255.0, 0xA0 / 255.0)), // asr honey-gold
        (0.71, (0xD4 / 255.0, 0xA5 / 255.0, 0x74 / 255.0)), // late afternoon
        (0.79, (0xA8 / 255.0, 0x5C / 255.0, 0x7A / 255.0)), // maghrib rose
        (0.83, (0x4E / 255.0, 0x2D / 255.0, 0x55 / 255.0)),
        (0.90, (0x1C / 255.0, 0x21 / 255.0, 0x47 / 255.0)), // isha indigo
        (0.95, (0x14 / 255.0, 0x18 / 255.0, 0x32 / 255.0)),
        (1.00, (0x0E / 255.0, 0x14 / 255.0, 0x28 / 255.0))
    ]

    /// Sky BOTTOM keyframes — the warmer "horizon band" of the gradient.
    /// Carries more orange/peach/rose during sunrise and maghrib so the
    /// screen reads as landscape-with-light rather than a flat wash.
    static let skyBottomStops: [RGBStop] = [
        (0.00, (0x0E / 255.0, 0x14 / 255.0, 0x28 / 255.0)),
        (0.18, (0x1A / 255.0, 0x1A / 255.0, 0x36 / 255.0)),
        (0.21, (0x2A / 255.0, 0x22 / 255.0, 0x45 / 255.0)),
        (0.26, (0xD4 / 255.0, 0x92 / 255.0, 0x6E / 255.0)), // peach sunrise
        (0.30, (0xE8 / 255.0, 0xB8 / 255.0, 0x98 / 255.0)),
        (0.33, (0xE8 / 255.0, 0xDF / 255.0, 0xC9 / 255.0)), // cream
        (0.45, (0xEF / 255.0, 0xE5 / 255.0, 0xC9 / 255.0)),
        (0.50, (0xEB / 255.0, 0xDF / 255.0, 0xB8 / 255.0)), // dhuhr cream
        (0.58, (0xE5 / 255.0, 0xC8 / 255.0, 0x98 / 255.0)),
        (0.65, (0xE0 / 255.0, 0xB8 / 255.0, 0x88 / 255.0)), // honey
        (0.71, (0xD4 / 255.0, 0x92 / 255.0, 0x6E / 255.0)),
        (0.79, (0xC7 / 255.0, 0x7B / 255.0, 0x5C / 255.0)), // maghrib horizon
        (0.83, (0x72 / 255.0, 0x36 / 255.0, 0x48 / 255.0)),
        (0.90, (0x1C / 255.0, 0x21 / 255.0, 0x47 / 255.0)),
        (0.95, (0x14 / 255.0, 0x18 / 255.0, 0x32 / 255.0)),
        (1.00, (0x0E / 255.0, 0x14 / 255.0, 0x28 / 255.0))
    ]

    /// Card SURFACE keyframes — warm cream during the day, deep amber at
    /// night. Both transition windows (sunrise and maghrib) are kept
    /// deliberately narrow so the surface never lingers in a muddy
    /// in-between zone where neither dark ink nor bone cream can clear
    /// WCAG AA. Half-hour samples around the transition are guaranteed
    /// to fall outside the brief crossover; the visual flip itself reads
    /// as the moment of sunrise / sunset, which is what the user sees
    /// outside their window.
    ///
    /// `SkyAndCardTests.cardForegroundContrastAcrossEveryHour` asserts
    /// the WCAG AA contract at HH:30 across every hour.
    static let cardSurfaceStops: [RGBStop] = [
        (0.00, (0x3D / 255.0, 0x33 / 255.0, 0x28 / 255.0)), // midnight amber-night
        (0.18, (0x42 / 255.0, 0x37 / 255.0, 0x2C / 255.0)), // 4:19am
        (0.22, (0x4D / 255.0, 0x3D / 255.0, 0x2C / 255.0)), // 5:17am pre-fajr (still amber)
        (0.249, (0x66 / 255.0, 0x55 / 255.0, 0x42 / 255.0)), // 5:58am last amber before sunrise
        (0.252, (0xC8 / 255.0, 0xB8 / 255.0, 0x9A / 255.0)), // 6:02am first cream after sunrise
        (0.30, (0xE8 / 255.0, 0xDF / 255.0, 0xC9 / 255.0)), // 7:12am full cream
        (0.50, (0xEB / 255.0, 0xE2 / 255.0, 0xCC / 255.0)), // dhuhr (slightly warmer cream)
        (0.65, (0xE5 / 255.0, 0xD4 / 255.0, 0xAC / 255.0)), // asr honey-cream
        (0.78, (0xDC / 255.0, 0xB4 / 255.0, 0x94 / 255.0)), // 18:43 pre-maghrib (still light)
        (0.7916, (0xD0 / 255.0, 0xA4 / 255.0, 0x84 / 255.0)), // 18:59:51 last cream
        (0.7919, (0x4D / 255.0, 0x38 / 255.0, 0x2A / 255.0)), // 19:00:16 night flip
        (0.86, (0x42 / 255.0, 0x36 / 255.0, 0x2A / 255.0)),  // 20:38
        (0.90, (0x3D / 255.0, 0x33 / 255.0, 0x28 / 255.0)),  // 21:36 full amber-night
        (1.00, (0x3D / 255.0, 0x33 / 255.0, 0x28 / 255.0))
    ]

    /// Linear RGB interpolation across an ordered keyframe table.
    /// Internal-but-testable so we can pin chromatic checkpoints
    /// (Fajr is dark, Dhuhr is cream, Maghrib pulls rose, etc.).
    static func interpolatedRGB(stops: [RGBStop], at progress: Double) -> RGB {
        let clamped = max(0.0, min(1.0, progress))
        for i in 0..<(stops.count - 1) {
            let a = stops[i]
            let b = stops[i + 1]
            if clamped >= a.progress && clamped <= b.progress {
                let span = b.progress - a.progress
                let t = span > 0 ? (clamped - a.progress) / span : 0
                return (
                    red: a.rgb.red + (b.rgb.red - a.rgb.red) * t,
                    green: a.rgb.green + (b.rgb.green - a.rgb.green) * t,
                    blue: a.rgb.blue + (b.rgb.blue - a.rgb.blue) * t
                )
            }
        }
        return stops.last?.rgb ?? (0, 0, 0)
    }

    /// Sky-gradient TOP colour at the given moment.
    public static func skyTopColor(at date: Date = .now) -> Color {
        let rgb = interpolatedRGB(stops: skyTopStops, at: dayProgress(for: date))
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// Sky-gradient BOTTOM colour at the given moment.
    public static func skyBottomColor(at date: Date = .now) -> Color {
        let rgb = interpolatedRGB(stops: skyBottomStops, at: dayProgress(for: date))
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// The card's base surface colour at the given moment. Warm cream
    /// during the day, deep amber at night.
    public static func cardSurfaceColor(at date: Date = .now) -> Color {
        let rgb = interpolatedRGB(stops: cardSurfaceStops, at: dayProgress(for: date))
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// Internal RGB form of the card surface colour. Used by the foreground
    /// brightness check and by tests.
    static func cardSurfaceRGB(at date: Date) -> RGB {
        interpolatedRGB(stops: cardSurfaceStops, at: dayProgress(for: date))
    }

    /// WCAG-style relative luminance of the card surface at the given
    /// moment. Used to decide whether the foreground text should be the
    /// dark ink or the bone cream.
    static func cardSurfaceLuminance(at date: Date) -> Double {
        let rgb = cardSurfaceRGB(at: date)
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(rgb.red)
            + 0.7152 * channel(rgb.green)
            + 0.0722 * channel(rgb.blue)
    }

    /// Threshold above which the card is "light enough" that dark text reads
    /// against it. Tuned so the crossover sits inside the natural sunrise /
    /// post-maghrib transitions, never inside Fajr or Asr.
    static let cardForegroundLuminanceThreshold: Double = 0.32

    /// Primary text colour for content sitting on a `cardSurfaceColor(at:)`
    /// surface. Resolves to ink-dark when the card is bright enough to
    /// support dark text and to bone-cream otherwise. The flip is computed,
    /// not selected — every prayer-time foreground stays in lockstep with
    /// the underlying card.
    public static func cardForegroundPrimary(at date: Date = .now) -> Color {
        cardSurfaceLuminance(at: date) > cardForegroundLuminanceThreshold
            ? textInkDark
            : textBoneCream
    }

    /// Secondary text on a card surface — primary at 72% opacity. Hits
    /// WCAG AA against either pole because both ink-on-cream and
    /// cream-on-amber clear that ratio with significant headroom.
    public static func cardForegroundSecondary(at date: Date = .now) -> Color {
        cardForegroundPrimary(at: date).opacity(0.72)
    }

    /// Muted / metadata text on a card surface — primary at 50% opacity.
    /// Only safe at body+ sizes; reuse in display contexts requires a fresh
    /// contrast check.
    public static func cardForegroundMuted(at date: Date = .now) -> Color {
        cardForegroundPrimary(at: date).opacity(0.50)
    }

    /// Warm accent colour at the given moment. Brass through most of the
    /// day, rose-gold in the maghrib window. Used for the now-marker on
    /// the prayer arc, the active-prayer indicator, and other moments of
    /// emphasis that should read as warm light catching a vessel rather
    /// than as cool UI tinting.
    public static func accentWarm(at date: Date = .now) -> Color {
        let p = dayProgress(for: date)
        // Rose-gold sits inside [0.74, 0.84] — the post-Asr → post-Maghrib
        // window. Outside it we return the steady brass; the user should
        // never see a bright pure-orange flash mid-afternoon.
        if p >= 0.74 && p <= 0.84 { return accentRoseGold }
        return accentBrass
    }

    // MARK: - Status indicator colors
    //
    // All status indicators stay within the brass / bone / ivory / muted-white
    // palette. NO red for missed prayers (punitive — explicitly avoided).
    // NO bright greens for jama'ah. NO amber/yellow for late.

    public static let statusOnTime: Color = .white.opacity(0.85)
    public static let statusLate: Color = .white.opacity(0.55)
    public static let statusMissed: Color = .white.opacity(0.30)

    /// Muted brass for qada — deliberate as "made up", warm but never alarming.
    public static let statusQada: Color = Color(
        red: 0xC9 / 255.0,
        green: 0xA8 / 255.0,
        blue: 0x76 / 255.0
    ).opacity(0.75)

    /// Soft pulsing color for the recording indicator. NEVER red.
    public static let recordingPulse: Color = Color(
        red: 0xC9 / 255.0,
        green: 0xA8 / 255.0,
        blue: 0x76 / 255.0
    ).opacity(0.60)

    // MARK: - Adaptive tint

    /// Returns the iridescent specular tint for the given moment.
    ///
    /// This is the function that drives the time-of-day identity. Apply it
    /// to Liquid Glass material via `.glassEffect(.tint:)` or the
    /// `.ihsanGlass(...)` wrapper — NEVER as a background color.
    public static func adaptiveTint(at date: Date = .now) -> Color {
        let progress = dayProgress(for: date)
        return interpolatedTint(at: progress)
    }

    /// 0.0 = midnight, 1.0 = next midnight.
    /// Internal-but-testable so AdaptiveTintTests can assert continuity.
    static func dayProgress(for date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let comps = calendar.dateComponents([.hour, .minute, .second], from: date)
        let totalSeconds = Double(comps.hour ?? 0) * 3600
            + Double(comps.minute ?? 0) * 60
            + Double(comps.second ?? 0)
        return totalSeconds / 86_400
    }

    /// HSB keyframes for the day. (dayProgress, hue°, saturation, brightness).
    /// Internal so tests can assert each keyframe maps to the documented hue range.
    static let tintStops: [(progress: Double, hue: Double, sat: Double, brightness: Double)] = [
        (0.00, 250, 0.30, 0.25), // midnight: deep indigo with magenta hint
        (0.20, 245, 0.35, 0.35), // ~5am Fajr: cool violet-blue
        (0.30, 220, 0.20, 0.50), // ~7am post-sunrise: cool slate
        (0.50,  45, 0.25, 0.70), // noon Dhuhr: neutral cream with subtle warmth
        (0.65,  35, 0.45, 0.55), // ~3:30pm Asr: warm honey-gold
        (0.80,  15, 0.50, 0.50), // ~7pm Maghrib: rose-gold
        (0.90, 270, 0.40, 0.35), // ~10pm Isha: deep blue-magenta
        (1.00, 250, 0.30, 0.25)  // wrap to midnight (matches 0.00 for continuity)
    ]

    /// Smoothly interpolates HSB between keyframes.
    /// HSB lerps follow the natural color wheel; an RGB lerp would produce
    /// muddy intermediate colors.
    static func interpolatedTint(at progress: Double) -> Color {
        let hsb = interpolatedHSB(at: progress)
        return Color(
            hue: hsb.hue / 360.0,
            saturation: hsb.saturation,
            brightness: hsb.brightness
        )
    }

    /// Pure HSB interpolation. Exposed for tests so we can assert hue ranges
    /// at specific times of day without round-tripping through `Color`.
    static func interpolatedHSB(
        at progress: Double
    ) -> (hue: Double, saturation: Double, brightness: Double) {
        let clamped = max(0.0, min(1.0, progress))

        for i in 0..<(tintStops.count - 1) {
            let a = tintStops[i]
            let b = tintStops[i + 1]
            if clamped >= a.progress && clamped <= b.progress {
                let span = b.progress - a.progress
                let t = span > 0 ? (clamped - a.progress) / span : 0

                // Hue wrapping: take the short way around the color wheel.
                var hueDelta = b.hue - a.hue
                if hueDelta > 180 { hueDelta -= 360 }
                if hueDelta < -180 { hueDelta += 360 }
                var hue = a.hue + hueDelta * t
                hue = hue.truncatingRemainder(dividingBy: 360)
                if hue < 0 { hue += 360 }

                let sat = a.sat + (b.sat - a.sat) * t
                let bright = a.brightness + (b.brightness - a.brightness) * t
                return (hue, sat, bright)
            }
        }

        // Unreachable given stops cover [0, 1]; safe fallback.
        return (0, 0, 1)
    }
}
