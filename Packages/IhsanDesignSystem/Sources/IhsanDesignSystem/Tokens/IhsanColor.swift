import SwiftUI

/// Type-safe color tokens. The consuming app must NEVER use inline
/// `Color(red:green:blue:)` literals — every color routes through this enum.
///
/// The visual language is Islamic manuscript illumination reimagined as
/// iOS 26 software. The page background ("the page") is a saturated colour
/// that drifts through the day — Persian indigo at night, parchment cream
/// in daylight, vermillion through the maghrib window. Content sits on
/// the page as illuminated panels: warm cream / amber surfaces bordered
/// in brass, with subtle drop shadows so each panel reads as ink-on-
/// parchment rather than glass-on-sky.
///
/// The original `ground` (deep ultramarine `#0E1428`) is preserved for
/// backwards compatibility with screens that have not yet migrated to the
/// manuscript page background.
public enum IhsanColor {
    /// Legacy anchor — deep ultramarine `#0E1428`. Preserved because
    /// non-Today screens (Settings, Trajectory, Reflection, Qibla,
    /// MasjidFinder) still draw against it. Today screen uses the
    /// `nightPage` / `parchmentLight` / `dawnRose` palette via
    /// `IhsanSkyGradient`.
    public static let ground = Color(hex: 0x0E1428)

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

    // MARK: - Canonical manuscript palette
    //
    // These are the hex codes the manuscript-redirect spec commits to.
    // The whole Today screen is composed from this set; new components in
    // the manuscript aesthetic MUST sample from here rather than inventing
    // off-spec values.

    /// Persian indigo `#1A1F4A`. The night page — deep but saturated, never
    /// flat black. Used as the dominant background colour from Isha through
    /// pre-Fajr.
    public static let nightPage = Color(hex: 0x1A1F4A)

    /// Rose-tinted indigo `#2D2547`. The transitional page colour at dawn
    /// (just before Fajr) and at the maghrib→isha boundary. Also used as
    /// the `Qada` status accent.
    public static let duskPage = Color(hex: 0x2D2547)

    /// Sunset vermillion `#B85F3A`. The maghrib horizon. The most dramatic
    /// page colour of the day; visible for the ~2 hour sunset window.
    public static let dawnRose = Color(hex: 0xB85F3A)

    /// Deep amber-cream `#C9B584`. Afternoon page colour leading into Asr.
    public static let parchmentDeep = Color(hex: 0xC9B584)

    /// Warm parchment `#E8DCC0`. Late-morning page colour, slightly warmer
    /// than `parchmentLight`.
    public static let parchmentWarm = Color(hex: 0xE8DCC0)

    /// Bright parchment `#F0E5D0`. The brightest page colour of the day,
    /// visible from sunrise through mid-morning.
    public static let parchmentLight = Color(hex: 0xF0E5D0)

    /// Cream parchment `#F5EBD5` — the illuminated-panel body colour during
    /// daylight hours. Every text-on-panel pair below uses this as the
    /// surface reference.
    public static let panelDay = Color(hex: 0xF5EBD5)

    /// Amber-cream `#3D3328` — the illuminated-panel body colour at night.
    /// Bone cream reads cleanly on top of this; ink dark would disappear.
    public static let panelNight = Color(hex: 0x3D3328)

    /// Brass `#C9A876` — the illumination-border colour and the dominant
    /// accent for arc strokes, prayer-list active borders, and small-caps
    /// inscriptions. The single most-used accent in the manuscript palette.
    public static let brass = Color(hex: 0xC9A876)

    /// Light brass `#E0C99E`. Used for highlights and the inner glow on
    /// active panels.
    public static let brassLight = Color(hex: 0xE0C99E)

    /// Gold `#D4A574`. The current-time marker on the prayer arc and other
    /// "this is happening right now" highlights. Slightly warmer and more
    /// saturated than brass.
    public static let gold = Color(hex: 0xD4A574)

    // MARK: - Iridescent brass palette
    //
    // Real gold leaf on a manuscript page iridesces — it shifts from
    // honey to brass to pale champagne as light angle changes. These
    // four anchors are sampled around the perimeter of every illuminated
    // panel's border (via `IhsanIridescence.brassStroke`) and inside the
    // gold ornament radial gradients so the surfaces read as a real
    // metallic material rather than a flat brass colour.

    /// Honey-gold `#D4A574` — the warm pole of the iridescent brass cycle.
    /// Same hex as `gold`; aliased separately so call sites that thread an
    /// iridescent gradient read in palette terms.
    public static let brassHoney = Color(hex: 0xD4A574)

    /// Mid brass `#C9A876` — the neutral pole of the iridescent cycle.
    /// Same hex as `brass`.
    public static let brassMid = Color(hex: 0xC9A876)

    /// Pale champagne `#E8D9B5` — the bright pole of the iridescent cycle.
    /// The lightest brass tone in the palette; reads as a soft highlight
    /// when it lands on the top edge of a panel border.
    public static let brassPale = Color(hex: 0xE8D9B5)

    /// Deep brass `#B8956A` — the shadow pole of the iridescent cycle.
    /// Same hex as `brassText`. Anchors the warmer side of the gradient
    /// and reads as "the side of the gold leaf facing away from the
    /// light" when applied around a stroke.
    public static let brassDark = Color(hex: 0xB8956A)

    /// Bright gold `#E8C97A` — used for the active-state highlight on
    /// the eight-pointed current-prayer marker and other "this is
    /// happening right now" emphasis points. Slightly more saturated
    /// than `gold`.
    public static let goldBright = Color(hex: 0xE8C97A)

    /// Vermillion `#C73E1D`. Status indicator for missed prayers and other
    /// error states. Saturated but used sparingly so it never overwhelms.
    public static let vermillion = Color(hex: 0xC73E1D)

    /// Deep ink `#1A1F2E`. Primary text on light panels. Same colour as
    /// the legacy `textInkDark`.
    public static let inkDeep = Color(hex: 0x1A1F2E)

    /// Warm dark brown `#2D1F12`. Alternative dark text colour for moments
    /// where pure ink would feel too cold against amber-cream surfaces.
    public static let inkBrown = Color(hex: 0x2D1F12)

    /// Cream `#F5EBD5`. Primary text on dark (night) panels. Same colour as
    /// `panelDay` — the same parchment hue, used as either surface or text
    /// depending on luminance context.
    public static let boneCream = Color(hex: 0xF5EBD5)

    /// Brass-on-cream text `#B8956A`. Slightly deeper than brass; preserves
    /// legibility when used for inscription labels (small caps, location,
    /// "UNTIL ASR") on a cream panel.
    public static let brassText = Color(hex: 0xB8956A)

    /// Deep verdant `#2D5F3F`. On-Time status indicator. A deep, considered
    /// green — never bright or celebratory.
    public static let verdantGreen = Color(hex: 0x2D5F3F)

    /// Brass `#C9A876`. Late-status accent — same hue as the illumination
    /// border so the status colour feels embedded in the palette, not
    /// signalled with traffic-light semantics.
    public static let amberLate = brass

    /// Vermillion `#C73E1D`. Missed-status indicator.
    public static let vermillionMissed = vermillion

    /// Deeper indigo `#2D2547`. Qada status indicator — same hue as
    /// `duskPage`, signalling "made up later" with a calm twilight tone.
    public static let indigoQada = duskPage

    // MARK: - Backwards-compatible aliases
    //
    // Pre-redirect screens consume these names; they now resolve to the
    // canonical manuscript palette values above.

    /// Daytime card surface — alias of `panelDay` (`#F5EBD5`). The
    /// historical name is preserved so non-Today screens compile unchanged.
    public static let cardCreamLight = panelDay

    /// Nighttime card surface — alias of `panelNight` (`#3D3328`).
    public static let cardAmberDark = panelNight

    /// Foreground text on a daytime cream card — alias of `inkDeep`.
    public static let textInkDark = inkDeep

    /// Foreground text on a nighttime amber card — alias of `boneCream`.
    public static let textBoneCream = boneCream

    /// Primary brass accent — alias of `brass` (`#C9A876`).
    public static let accentBrass = brass

    /// Rose-gold accent `#C77B5C`. Retained as a public token; no longer
    /// returned by `accentWarm(at:)` (the manuscript redirect unifies the
    /// active accent on brass at all times of day).
    public static let accentRoseGold = Color(hex: 0xC77B5C)

    // MARK: - RGB stop interpolation (sky / card)

    typealias RGB = (red: Double, green: Double, blue: Double)
    typealias RGBStop = (progress: Double, rgb: RGB)

    /// Sky TOP keyframes — the page colour at the top edge of the screen
    /// at each moment of the day. The keyframe progression encodes the
    /// manuscript-page sequence: Persian indigo at night, parchment cream
    /// through daylight, deeper parchment into the afternoon, vermillion
    /// at maghrib, dusk indigo trailing into night.
    ///
    /// The sunrise flip from indigo to parchment is intentionally tight
    /// (`0.250 → 0.252` = ~3 minutes of clock time) so the user reads it
    /// as "the moment of sunrise" rather than a long pastel transition.
    static let skyTopStops: [RGBStop] = [
        (0.000, hexRGB(0x1A1F4A)),  // 00:00 — Persian indigo (night)
        (0.167, hexRGB(0x1A1F4A)),  // 04:00 — still night
        (0.250, hexRGB(0x2D2547)),  // 05:59:48 — dusk top, last moment before sunrise
        (0.252, hexRGB(0xF0E5D0)),  // 06:02:53 — SUNRISE flip to parchment
        (0.417, hexRGB(0xE8DCC0)),  // 10:00 — warming parchment
        (0.542, hexRGB(0xD9C9A0)),  // 13:00 — Dhuhr golden cream
        (0.667, hexRGB(0xC9B584)),  // 16:00 — Asr deeper parchment
        (0.792, hexRGB(0xB85F3A)),  // 19:00 — Maghrib vermillion
        (0.875, hexRGB(0x2D2547)),  // 21:00 — Isha dusk indigo
        (0.958, hexRGB(0x1A1F4A)),  // 23:00 — full night indigo
        (1.000, hexRGB(0x1A1F4A))   // 24:00 — Persian indigo
    ]

    /// Sky BOTTOM keyframes — the page colour at the bottom edge of the
    /// screen. Each window's bottom is one step warmer than its top, so
    /// the gradient reads as "sky above, horizon below" without ever
    /// becoming a hard band. The bottom holds vermillion through the
    /// asr→maghrib window (so the page reads as uniform sunset, not
    /// muddy crimson at 17:00) and only descends to indigo across the
    /// maghrib→isha hours.
    static let skyBottomStops: [RGBStop] = [
        (0.000, hexRGB(0x1A1F4A)),  // 00:00 — uniform night
        (0.167, hexRGB(0x1A1F4A)),  // 04:00
        (0.250, hexRGB(0x2D2547)),  // 05:59:48 — dusk bottom
        (0.252, hexRGB(0xE8DCC0)),  // 06:02:53 — sunrise warm parchment
        (0.417, hexRGB(0xD9C9A0)),  // 10:00 — warming gold
        (0.542, hexRGB(0xC9B584)),  // 13:00 — Dhuhr amber
        (0.667, hexRGB(0xB85F3A)),  // 16:00 — Asr horizon already vermillion
        (0.792, hexRGB(0xB85F3A)),  // 19:00 — Maghrib uniform vermillion bottom
        (0.875, hexRGB(0x1A1F4A)),  // 21:00 — Isha night settled at horizon
        (0.958, hexRGB(0x1A1F4A)),  // 23:00
        (1.000, hexRGB(0x1A1F4A))   // 24:00
    ]

    /// Card SURFACE keyframes — `panelDay` parchment during daylight,
    /// `panelNight` amber-cream at night. The crossover at sunrise
    /// (`0.2496 → 0.2503`) and at maghrib (`0.7916 → 0.7920`) is sub-minute
    /// so users read each flip as the literal moment of sunrise / sunset.
    /// Half-hour test samples never fall inside the crossover, so the
    /// `SkyAndCardTests.cardForegroundContrastAcrossEveryHour` WCAG AA
    /// contract holds.
    static let cardSurfaceStops: [RGBStop] = [
        (0.0000, hexRGB(0x3D3328)),  // 00:00 — panelNight
        (0.1667, hexRGB(0x3D3328)),  // 04:00
        (0.2496, hexRGB(0x3D3328)),  // 05:59:25 — last night moment
        (0.2503, hexRGB(0xF5EBD5)),  // 06:00:25 — SUNRISE flip to panelDay
        (0.7916, hexRGB(0xF5EBD5)),  // 18:59:51 — last day moment
        (0.7920, hexRGB(0x3D3328)),  // 19:00:29 — MAGHRIB flip to panelNight
        (0.8750, hexRGB(0x3D3328)),  // 21:00
        (1.0000, hexRGB(0x3D3328))   // 24:00
    ]

    private static func hexRGB(_ hex: Int) -> RGB {
        (
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

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
    /// against it. The sub-minute card flips at sunrise and maghrib keep
    /// HH:30 samples firmly on one side of this threshold so contrast
    /// stays in the AAA zone at every test hour.
    static let cardForegroundLuminanceThreshold: Double = 0.32

    /// Primary text colour for content sitting on a `cardSurfaceColor(at:)`
    /// surface. Resolves to `inkDeep` when the panel is light and to
    /// `boneCream` when the panel is dark. Both poles clear WCAG AA with
    /// significant headroom.
    public static func cardForegroundPrimary(at date: Date = .now) -> Color {
        cardSurfaceLuminance(at: date) > cardForegroundLuminanceThreshold
            ? inkDeep
            : boneCream
    }

    /// The illuminated-panel body colour at the given moment — `panelDay`
    /// during daylight hours, `panelNight` at night. Resolves via the same
    /// luminance threshold used by `cardForegroundPrimary`, so the surface
    /// and its text foreground stay in lockstep across the sunrise /
    /// maghrib flips. Use this when composing a custom illuminated
    /// surface (e.g. a small chip) that needs to match the page's
    /// dominant card material without going through the
    /// `.ihsanIlluminatedPanel` modifier.
    public static func panelSurface(at date: Date = .now) -> Color {
        cardSurfaceLuminance(at: date) > cardForegroundLuminanceThreshold
            ? panelDay
            : panelNight
    }

    /// Secondary text on a card surface — primary at 72% opacity.
    public static func cardForegroundSecondary(at date: Date = .now) -> Color {
        cardForegroundPrimary(at: date).opacity(0.72)
    }

    /// Muted / metadata text on a card surface — primary at 50% opacity.
    /// Only safe at body+ sizes; reuse in display contexts requires a fresh
    /// contrast check.
    public static func cardForegroundMuted(at date: Date = .now) -> Color {
        cardForegroundPrimary(at: date).opacity(0.50)
    }

    /// Warm brass accent at the given moment. The manuscript redirect
    /// unifies the active accent on brass throughout the day; previous
    /// versions returned rose-gold in the maghrib window, which fought
    /// the brass illumination borders elsewhere on the screen.
    public static func accentWarm(at date: Date = .now) -> Color {
        // Date is currently unused — kept in the signature so callers do
        // not need to be rewritten and so a future iteration can re-introduce
        // a warmer maghrib accent without API churn.
        _ = date
        return brass
    }

    // MARK: - Foreground colours for content sitting on the sky
    //
    // The header (city name, Hijri date, icon chips) sits directly on the
    // page gradient near the top of the screen. The card-foreground helpers
    // above don't apply: the sky transitions between dark and light at
    // different clock times than the cards do, so reusing
    // `cardForegroundPrimary` would give a dark-text-on-dark-sky moment
    // around sunrise.
    //
    // These helpers consult sky-TOP luminance specifically because that's
    // where the header actually sits.

    /// Internal RGB form of the sky top colour. Drives the foreground
    /// brightness check below and is reused by tests to assert the
    /// daylight / night flip happens at the right hour.
    static func skyTopRGB(at date: Date) -> RGB {
        interpolatedRGB(stops: skyTopStops, at: dayProgress(for: date))
    }

    /// WCAG-style relative luminance of the sky top at the given moment.
    static func skyTopLuminance(at date: Date) -> Double {
        let rgb = skyTopRGB(at: date)
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(rgb.red)
            + 0.7152 * channel(rgb.green)
            + 0.0722 * channel(rgb.blue)
    }

    /// Approximate WCAG luminance of the two foreground extremes. Hard-
    /// coded so the picker below doesn't have to recompute them per call.
    /// `inkDeep` is `#1A1F2E` (luminance ≈ 0.0130). `boneCream` is `#F5EBD5`
    /// (luminance ≈ 0.8372).
    static let textInkLuminance: Double = 0.0130
    static let textBoneLuminance: Double = 0.8372

    /// Primary text colour for content sitting DIRECTLY on the sky
    /// (header, status overlays, anything not inside a warm card).
    ///
    /// Instead of using a single threshold (which would pick the wrong
    /// pole near the mid-tone transition zones around sunrise and
    /// maghrib), this returns whichever of ink-dark or bone-cream has
    /// the BETTER WCAG contrast against the current sky top. Callers
    /// should still pair the colour with a small opposite-tinted text
    /// shadow when their text would otherwise sit on a mid-tone sky.
    public static func skyForegroundPrimary(at date: Date = .now) -> Color {
        let skyLum = skyTopLuminance(at: date)
        let inkContrast = wcagContrast(skyLum, textInkLuminance)
        let creamContrast = wcagContrast(skyLum, textBoneLuminance)
        return inkContrast >= creamContrast ? inkDeep : boneCream
    }

    /// WCAG contrast ratio between two relative luminances.
    static func wcagContrast(_ a: Double, _ b: Double) -> Double {
        let lighter = max(a, b)
        let darker = min(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }

    public static func skyForegroundSecondary(at date: Date = .now) -> Color {
        skyForegroundPrimary(at: date).opacity(0.72)
    }

    public static func skyForegroundMuted(at date: Date = .now) -> Color {
        skyForegroundPrimary(at: date).opacity(0.50)
    }

    // MARK: - Status indicator colors
    //
    // Status indicators stay within the muted brass / bone / ivory palette
    // so the screen never feels punitive for missed prayers or rewarding
    // for on-time ones. The bright `vermillion` / `verdantGreen` tokens
    // exist for future use but are NOT currently routed through
    // `StatusPill`, which keeps its monochrome treatment.

    public static let statusOnTime: Color = .white.opacity(0.85)
    public static let statusLate: Color = .white.opacity(0.55)
    public static let statusMissed: Color = .white.opacity(0.30)

    /// Muted brass for qada — deliberate as "made up", warm but never alarming.
    public static let statusQada: Color = brass.opacity(0.75)

    /// Soft pulsing color for the recording indicator. NEVER red.
    public static let recordingPulse: Color = brass.opacity(0.60)

    // MARK: - Adaptive tint (legacy iridescent treatment)
    //
    // Returned by `IhsanGlassModifier` for the dark-glass surfaces that
    // pre-redirect screens still draw. The Today screen no longer consumes
    // this — its panels are solid illuminated cream / amber, not glass.

    /// Returns the iridescent specular tint for the given moment.
    ///
    /// This is the function that drives the time-of-day identity of the
    /// LEGACY glass treatment. Apply it via `.glassEffect(.tint:)` or the
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

// MARK: - Color hex initializer (file-private)

private extension Color {
    /// Build a sRGB color from a 24-bit hex literal (`0xRRGGBB`).
    init(hex: Int) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
