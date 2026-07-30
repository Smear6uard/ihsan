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

    // The rust-brown page ramp (`nightPage` / `duskPage` / `dawnRose` /
    // the parchment triplet) and the olive-taupe panel pair
    // (`panelDay` / `panelNight`) are DELETED. The page ground and
    // panel material now come exclusively from palette v2
    // (`IhsanPageChrome`, `SkyPaletteTokens`) — no page-local
    // overrides, no parallel ground system.

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

    /// Deeper indigo `#2D2547`. Qada status indicator — a calm
    /// twilight tone for "made up later".
    public static let indigoQada = Color(hex: 0x2D2547)

    /// Primary brass accent — alias of `brass` (`#C9A876`).
    public static let accentBrass = brass

    /// Rose-gold accent `#C77B5C`. Retained as a public token; no longer
    /// returned by `accentWarm(at:)` (the manuscript redirect unifies the
    /// active accent on brass at all times of day).
    public static let accentRoseGold = Color(hex: 0xC77B5C)

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
