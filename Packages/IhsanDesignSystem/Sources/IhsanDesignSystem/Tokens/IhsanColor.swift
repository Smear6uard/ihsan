import SwiftUI

/// Type-safe color tokens. The consuming app must NEVER use inline
/// `Color(red:green:blue:)` literals — every color routes through this enum.
///
/// The visual identity locks one rule: the dark ground stays constant across
/// every screen at every time of day. Time of day is expressed only through
/// how Liquid Glass surfaces refract the adaptive tint — never by changing
/// the background.
public enum IhsanColor {
    /// The single dark ground used across every screen at every time of day.
    /// Approximate: deep ultramarine-near-black, #0E1428.
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
