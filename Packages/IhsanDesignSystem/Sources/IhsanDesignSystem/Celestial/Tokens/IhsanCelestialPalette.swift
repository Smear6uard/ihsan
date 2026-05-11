import SwiftUI

/// The canonical four-colour-per-mode palette for the celestial Today
/// screen. The whole composition — sky, panels, text, ornaments — samples
/// from one of two palettes (`.night` or `.day`); transition windows
/// blend between the two with the horizon accents (`horizonRose`,
/// `horizonGlow`) layered on top.
///
/// Every hex code in this file is locked by the manuscript redirect
/// spec. New components in the celestial aesthetic MUST sample from
/// these tokens rather than inventing off-spec values. If a colour
/// outside this palette is needed, the composition is wrong — reach
/// back to the spec before adding a new constant.
///
/// Functionally each mode commits to four colour roles:
///
/// 1. **sky / skyDeep** — vertical gradient anchors for the page
///    background. Two stops only; the gradient is uniform within the
///    mode and the transition windows are handled by blending palettes.
/// 2. **surface** — the body colour of illuminated panels (focused-
///    prayer card and any future content cards on the celestial scene).
/// 3. **text** — primary foreground on a `surface` panel.
/// 4. **accent** — brass. Borders, inscriptions, prayer-marker bodies.
///
/// Two named variants of the accent are exposed so call sites can read
/// in palette terms rather than threading hex codes:
///
/// - **accentBright** — gold (`#D4A574` / `#C9A876`). The current-prayer
///   eight-pointed star, the sun ornament's core fill.
/// - **accentMoon** — bone cream / honey gold (`#F0E5D0` / `#D4A574`).
///   The moon body during night, the sun body during day.
/// - **subterranean** — a tonal extension of the mode's sky for the
///   region beneath the horizon line (`#0A0E20` / `#B8956A`). Not a
///   fifth accent family — the value is a deeper, quieter sibling of
///   the sky so the below-horizon band reads as "beneath the visible
///   sky" rather than as a competing surface.
///
/// The two named palettes (`.night` and `.day`) and the time-of-day
/// resolver (`current(at:)`) are the only public surface for the
/// celestial scene's colour layer. Phase 2 wires real sun-altitude
/// resolution into `current(at:)`; for Phase 1 it uses a simple clock-
/// time threshold so the rest of the layer can compile and preview.
public struct IhsanCelestialPalette: Sendable, Equatable {

    /// Gradient TOP anchor for the page background.
    public let sky: Color

    /// Gradient BOTTOM anchor for the page background. One step deeper
    /// than `sky` so the gradient reads as "page above, horizon below"
    /// without ever becoming a hard band.
    public let skyDeep: Color

    /// Illuminated-panel body colour for content sitting on the sky.
    public let surface: Color

    /// Primary text colour on a `surface` panel. WCAG AA verified by
    /// `CelestialPaletteTests.textOnSurfaceMeetsAA`.
    public let text: Color

    /// Brass — the dominant accent for borders, inscriptions, prayer
    /// markers, and any small ornamental detail.
    public let accent: Color

    /// Gold — used only where "this is happening right now" emphasis is
    /// needed: the active prayer marker, the sun ornament core, the
    /// focused-prayer card's iridescent border when in the active state.
    public let accentBright: Color

    /// The body colour for the dominant celestial ornament — moon at
    /// night (bone cream `#F0E5D0`), sun during the day (gold
    /// `#D4A574`).
    public let accentMoon: Color

    /// Region below the horizon line — a tonal extension of the
    /// mode's sky, not a separate accent family. Quieter and dimmer
    /// than `skyDeep` so the subterranean band reads as "beneath the
    /// visible sky" rather than as a competing surface. Night uses a
    /// deeper indigo (`#0A0E20`); day uses a muted warm dark
    /// (`#B8956A`) that is rarely seen in the daytime composition
    /// because the horizon then sits near the bottom of the scene.
    public let subterranean: Color
}

// MARK: - Named palettes

public extension IhsanCelestialPalette {

    /// Night palette. Active from end-of-Isha through pre-Fajr.
    ///
    /// - `sky` Persian indigo `#161D3F`
    /// - `skyDeep` deeper indigo `#0E142B`
    /// - `surface` warm espresso `#2A2218`
    /// - `text` bone cream `#F0E5D0`
    /// - `accent` brass `#C9A876`
    /// - `accentBright` gold `#D4A574`
    /// - `accentMoon` bone cream `#F0E5D0`
    static let night = IhsanCelestialPalette(
        sky: Color(celestialHex: 0x161D3F),
        skyDeep: Color(celestialHex: 0x0E142B),
        surface: Color(celestialHex: 0x2A2218),
        text: Color(celestialHex: 0xF0E5D0),
        accent: Color(celestialHex: 0xC9A876),
        accentBright: Color(celestialHex: 0xD4A574),
        accentMoon: Color(celestialHex: 0xF0E5D0),
        subterranean: Color(celestialHex: 0x0A0E20)
    )

    /// Day palette. Active from sunrise through Maghrib.
    ///
    /// - `sky` parchment cream `#F0E5D0`
    /// - `skyDeep` deeper parchment `#E8DCC0`
    /// - `surface` sunlit-paper cream `#FFFAF0`
    /// - `text` ink deep `#1A1F2E`
    /// - `accent` antique brass `#6F5429`
    /// - `accentBright` mid brass `#C9A876`
    /// - `accentMoon` sun gold `#D4A574`
    /// - `subterranean` darker cream-amber `#C9B584`
    ///
    /// The surface and subterranean tokens together carve the daytime
    /// scene into three visibly distinct luminance bands: the sunlit-
    /// paper card surface (brightest), the cream sky behind it, and
    /// the warmer subterranean amber beneath the horizon line.
    ///
    /// The spec's original `dayAccent` was `#B8956A`, which yields a
    /// 2.35:1 ratio against the lighter cards and skies — well below
    /// the WCAG AA contract for the inscription small caps that
    /// consume this token. The deeper antique-brass `#6F5429` stays
    /// in the same warm-brass family while clearing AA against every
    /// day-mode surface and sky stop. The lighter `#B8956A` remains
    /// available through `IhsanIridescence.brassStroke` as a non-text
    /// decorative stroke for panel borders and marker outlines.
    static let day = IhsanCelestialPalette(
        sky: Color(celestialHex: 0xF0E5D0),
        skyDeep: Color(celestialHex: 0xE8DCC0),
        surface: Color(celestialHex: 0xFFFAF0),
        text: Color(celestialHex: 0x1A1F2E),
        accent: Color(celestialHex: 0x6F5429),
        accentBright: Color(celestialHex: 0xC9A876),
        accentMoon: Color(celestialHex: 0xD4A574),
        subterranean: Color(celestialHex: 0xC9B584)
    )
}

// MARK: - Transition accents

public extension IhsanCelestialPalette {

    /// Rose-gold at the horizon during the Fajr-to-sunrise and
    /// Maghrib-to-Isha transition windows. Layered on the sky gradient
    /// at the horizon's y-coordinate, never on a panel surface.
    static let horizonRose = Color(celestialHex: 0xC77B5C)

    /// Brighter glow halo immediately above the horizon during the same
    /// transition windows. Falls off vertically over ~120pt so it reads
    /// as light bending around the horizon, not as a hard band.
    static let horizonGlow = Color(celestialHex: 0xE8945C)
}

// MARK: - Status indicators

public extension IhsanCelestialPalette {

    /// Status colours used in the prayer-log sheet and the focused-prayer
    /// card's inscription. Never appear on the celestial scene itself —
    /// the scene only ever uses palette accent colours.
    enum Status {
        /// Verdant green `#2D5F3F` — prayer logged on time.
        public static let onTime = Color(celestialHex: 0x2D5F3F)

        /// Brass `#C9A876` — prayer logged after the on-time window.
        /// Same hue as the dominant accent so "late" feels embedded in
        /// the palette rather than signalled with traffic-light colour.
        public static let late = Color(celestialHex: 0xC9A876)

        /// Vermillion `#C73E1D` — prayer missed.
        public static let missed = Color(celestialHex: 0xC73E1D)

        /// Deep indigo `#2D2547` — prayer logged as qadā (made up later).
        public static let qada = Color(celestialHex: 0x2D2547)
    }
}

// MARK: - Time-of-day resolution

public extension IhsanCelestialPalette {

    /// Returns the active palette for the given moment.
    ///
    /// Phase 1 uses a sunrise / sunset clock-time threshold (06:30 /
    /// 18:30 local time). Phase 2 replaces this with real sun-altitude
    /// resolution via `SolarPosition`, so callers don't need to be
    /// rewritten — they already thread the date through.
    ///
    /// During the transition windows (Fajr-to-sunrise, Maghrib-to-Isha)
    /// the underlying mode crossfades; Phase 3 builds the gradient that
    /// blends `.night` and `.day` palettes with the horizon accents
    /// layered between them. The resolver here returns whichever mode
    /// is dominant — the panel surface and text follow.
    static func current(at date: Date = .now) -> IhsanCelestialPalette {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let clockTime = Double(hour) + Double(minute) / 60.0
        // Phase 1 fallback: sunrise ~06:30, maghrib ~18:30. The crossover
        // is sub-minute so the panel surface and text flip at sunrise /
        // maghrib rather than dragging through a mid-tone transition that
        // would land below the WCAG AA threshold.
        return (clockTime >= 6.5 && clockTime < 18.5) ? .day : .night
    }

    /// Whether the active palette is the night mode at the given moment.
    /// Convenience for components that need a boolean rather than a
    /// palette instance (e.g. choosing between a moon and a sun ornament).
    static func isNight(at date: Date = .now) -> Bool {
        current(at: date) == .night
    }
}

// MARK: - Internal hex initializer
//
// File-private hex initializer scoped to celestial-layer files. Other
// design-system files have their own equivalent; centralising this is
// a follow-up cleanup, not a Phase 1 concern.

extension Color {
    init(celestialHex hex: Int) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
