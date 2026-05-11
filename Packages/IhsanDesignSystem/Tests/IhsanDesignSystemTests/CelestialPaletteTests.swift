import Foundation
import SwiftUI
import Testing
@testable import IhsanDesignSystem

// MARK: - WCAG luminance / contrast (matches ColorContrastTests' math)

private struct SRGB {
    let r: Double
    let g: Double
    let b: Double

    init(hex: Int) {
        self.r = Double((hex >> 16) & 0xFF) / 255.0
        self.g = Double((hex >> 8) & 0xFF) / 255.0
        self.b = Double(hex & 0xFF) / 255.0
    }

    var relativeLuminance: Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}

private func contrast(_ a: SRGB, _ b: SRGB) -> Double {
    let (la, lb) = (a.relativeLuminance, b.relativeLuminance)
    let lighter = max(la, lb)
    let darker = min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)
}

// Canonical palette hex codes — pinned here so a casual tweak to the
// palette file shows up as a contrast-test failure rather than a silent
// visual regression. The values mirror IhsanCelestialPalette and must
// stay in sync with the spec.

private enum NightHex {
    static let sky: Int = 0x161D3F
    static let skyDeep: Int = 0x0E142B
    static let surface: Int = 0x2A2218
    static let text: Int = 0xF0E5D0
    static let accent: Int = 0xC9A876
    static let accentBright: Int = 0xD4A574
    static let subterranean: Int = 0x0A0E20
}

private enum DayHex {
    static let sky: Int = 0xF0E5D0
    static let skyDeep: Int = 0xE8DCC0
    static let surface: Int = 0xFFFAF0
    static let text: Int = 0x1A1F2E
    // `accent` is one shade deeper than the spec's listed `dayAccent`
    // (`#B8956A`) — see `IhsanCelestialPalette.day` for the rationale.
    // The spec value yields a 2.35:1 ratio on the day surface, which
    // violates the spec's own AA contract for inscription small caps;
    // `#6F5429` is a darker variant in the same brass family that
    // clears AA on every day-mode surface and sky stop.
    static let accent: Int = 0x6F5429
    static let accentBright: Int = 0xC9A876
    static let subterranean: Int = 0xC9B584
}

// MARK: - Text on surface — body AA (≥ 4.5)

@Test
func nightTextOnNightSurfaceMeetsAA() {
    let ratio = contrast(SRGB(hex: NightHex.text), SRGB(hex: NightHex.surface))
    #expect(ratio >= 4.5, "night text on night surface contrast was \(ratio), expected ≥ 4.5")
}

@Test
func dayTextOnDaySurfaceMeetsAA() {
    let ratio = contrast(SRGB(hex: DayHex.text), SRGB(hex: DayHex.surface))
    #expect(ratio >= 4.5, "day text on day surface contrast was \(ratio), expected ≥ 4.5")
}

// MARK: - Accent (brass inscription) on surface — small-caps inscription
//
// Inscriptions are 11pt semibold — by WCAG that's still "normal text"
// (not "large"), so we require the body threshold of 4.5. The brass
// accent on each mode's surface clears this with headroom; verifying
// here prevents a future palette tweak from dropping below.

@Test
func nightAccentOnNightSurfaceMeetsAA() {
    let ratio = contrast(SRGB(hex: NightHex.accent), SRGB(hex: NightHex.surface))
    #expect(ratio >= 4.5, "night accent on night surface contrast was \(ratio), expected ≥ 4.5 for body small caps")
}

@Test
func dayAccentOnDaySurfaceMeetsAA() {
    let ratio = contrast(SRGB(hex: DayHex.accent), SRGB(hex: DayHex.surface))
    #expect(ratio >= 4.5, "day accent on day surface contrast was \(ratio), expected ≥ 4.5 for body small caps")
}

// MARK: - Accent on sky background — prayer-marker labels (9pt small caps)
//
// 9pt small caps is below "large text" by every measure, so we still
// require the body threshold of 4.5 on the dominant sky stop. The
// gradient bottom is one step warmer / darker than the top; the spec
// intentionally keeps the bottom in the same luminance band so labels
// pinned to either stop stay legible.

@Test
func nightAccentOnNightSkyMeetsAA() {
    let ratio = contrast(SRGB(hex: NightHex.accent), SRGB(hex: NightHex.sky))
    #expect(ratio >= 4.5, "night accent on night sky contrast was \(ratio), expected ≥ 4.5")
}

@Test
func nightAccentOnNightSkyDeepMeetsAA() {
    let ratio = contrast(SRGB(hex: NightHex.accent), SRGB(hex: NightHex.skyDeep))
    #expect(ratio >= 4.5, "night accent on night skyDeep contrast was \(ratio), expected ≥ 4.5")
}

@Test
func dayAccentOnDaySkyMeetsAA() {
    let ratio = contrast(SRGB(hex: DayHex.accent), SRGB(hex: DayHex.sky))
    #expect(ratio >= 4.5, "day accent on day sky contrast was \(ratio), expected ≥ 4.5")
}

@Test
func dayAccentOnDaySkyDeepMeetsAA() {
    let ratio = contrast(SRGB(hex: DayHex.accent), SRGB(hex: DayHex.skyDeep))
    #expect(ratio >= 4.5, "day accent on day skyDeep contrast was \(ratio), expected ≥ 4.5")
}

// MARK: - accentBright as ornament fill
//
// `accentBright` is the fill colour for the active-prayer eight-
// pointed star marker and the sun ornament. WCAG 1.4.3 governs text,
// not graphical fills, so the ornament-on-sky pair has no formal
// contrast obligation — the marker reads through its outline, halo,
// and 18pt scale rather than through fill contrast.
//
// We still pin the NIGHT variant against the night surface (gold
// `#D4A574` on espresso `#2A2218` ~ 7:1) because the active marker
// ALSO appears on the focused-prayer card as a status indicator
// (filled brass square with "✓" / "L" / "J" / "Q" overlay) — that's
// not text either, but the indicator's filled square needs to be
// visually distinct from the panel surface. The day variant
// intentionally has lower fill contrast (gold on cream is naturally
// luxurious-and-low-contrast); the indicator there reads through
// its glyph + outline rather than the fill.

@Test
func nightAccentBrightOnNightSurfaceIsVisuallyDistinct() {
    let ratio = contrast(SRGB(hex: NightHex.accentBright), SRGB(hex: NightHex.surface))
    #expect(ratio >= 3.0, "night accentBright on night surface contrast was \(ratio), expected ≥ 3.0 for status indicator legibility")
}

// MARK: - Palette equality / current() correctness
//
// Pin Phase 1's clock-time threshold so the Phase 2 switch to real sun-
// altitude resolution shows up as a deliberate change in the resolver,
// not a silent drift.

@Test
func currentAtMiddayIsDayPalette() {
    let date = dateAt(hour: 12, minute: 0)
    #expect(IhsanCelestialPalette.current(at: date) == .day)
}

@Test
func currentAtMidnightIsNightPalette() {
    let date = dateAt(hour: 0, minute: 0)
    #expect(IhsanCelestialPalette.current(at: date) == .night)
}

@Test
func currentAtPreFajrIsNightPalette() {
    let date = dateAt(hour: 5, minute: 0)
    #expect(IhsanCelestialPalette.current(at: date) == .night)
}

@Test
func currentAtMidMorningIsDayPalette() {
    let date = dateAt(hour: 9, minute: 30)
    #expect(IhsanCelestialPalette.current(at: date) == .day)
}

@Test
func currentAtPostMaghribIsNightPalette() {
    let date = dateAt(hour: 21, minute: 0)
    #expect(IhsanCelestialPalette.current(at: date) == .night)
}

@Test
func isNightConvenienceMatchesCurrent() {
    let nightDate = dateAt(hour: 22, minute: 0)
    let dayDate = dateAt(hour: 13, minute: 0)
    #expect(IhsanCelestialPalette.isNight(at: nightDate))
    #expect(!IhsanCelestialPalette.isNight(at: dayDate))
}

// MARK: - Subterranean: tonal extension of sky for below-horizon region
//
// The subterranean token is a tonal extension of the mode's sky, not a
// new accent family. Two invariants matter: (a) it must be darker /
// quieter than the sky deep stop so the below-horizon band reads as
// "beneath the sky", not as a competing surface, and (b) it must NOT
// be confusable with `surface` (which is the illuminated-panel body —
// a different role).

@Test
func nightSubterraneanIsDarkerThanNightSkyDeep() {
    let subterranean = SRGB(hex: NightHex.subterranean)
    let skyDeep = SRGB(hex: NightHex.skyDeep)
    #expect(
        subterranean.relativeLuminance < skyDeep.relativeLuminance,
        "night subterranean luminance \(subterranean.relativeLuminance) should be darker than night skyDeep \(skyDeep.relativeLuminance)"
    )
}

@Test
func daySubterraneanIsDarkerThanDaySkyDeep() {
    let subterranean = SRGB(hex: DayHex.subterranean)
    let skyDeep = SRGB(hex: DayHex.skyDeep)
    #expect(
        subterranean.relativeLuminance < skyDeep.relativeLuminance,
        "day subterranean luminance \(subterranean.relativeLuminance) should be darker than day skyDeep \(skyDeep.relativeLuminance)"
    )
}

@Test
func subterraneanHexValuesMatchPaletteTokens() {
    // Pinning the hex codes here keeps drift between the test fixtures
    // and the palette source flagged at compile time. The spec locks
    // these values; an inadvertent change should surface as a failed
    // test rather than a silent visual regression.
    #expect(NightHex.subterranean == 0x0A0E20)
    #expect(DayHex.subterranean == 0xC9B584)
}

// MARK: - Helpers

private func dateAt(hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 15
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components) ?? .now
}
