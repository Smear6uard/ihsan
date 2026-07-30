import Synchronization
import SwiftUI

/// The five canonical palette states of the celestial instrument.
///
/// Palette v2 inverts v1's placement of warmth: the ground is either
/// jewel-deep (night, dawn, sunset) or luminous cool near-white
/// (morning, afternoon), and ALL saturation lives in the ink, the
/// metal, and the glow. No state may read as tan, beige, parchment,
/// or dusty — the only parchment allowed anywhere is `panelTexture`,
/// a ≤8%-opacity overlay on panels, never a surface fill.
public enum PaletteState: String, CaseIterable, Sendable {
    case night
    case dawn
    case morning
    case afternoon
    case sunset

    /// The canonical token set for this state — the fixed-state
    /// override for previews and tests. Live UI should almost always
    /// go through `resolved(for:)` with a real `SkyPhase` instead.
    public var tokens: SkyPaletteTokens {
        switch self {
        case .night: return .night
        case .dawn: return .dawn
        case .morning: return .morning
        case .afternoon: return .afternoon
        case .sunset: return .sunset
        }
    }

    /// The full token set at a continuous phase. Plateaus return the
    /// canonical states; transition bands mix adjacent states in OKLab
    /// so there is no boundary at which any token can snap. Atmosphere
    /// roles (ground, wash, glow, metal) drift across the wide band;
    /// figure roles (ink, panel fill, status) cross in the narrow band
    /// — see `SkyPhase.figureHalfWidth` for the reasoning.
    public static func resolved(for phase: SkyPhase) -> SkyPaletteTokens {
        let atm = phase.blend
        let fig = phase.figureBlend
        let a0 = atm.from.tokens
        let a1 = atm.to.tokens
        let f0 = fig.from.tokens
        let f1 = fig.to.tokens

        var tokens = SkyPaletteTokens(
            skyZenith: .mix(a0.skyZenithValue, a1.skyZenithValue, amount: atm.amount),
            groundTop: .mix(a0.groundTopValue, a1.groundTopValue, amount: atm.amount),
            groundBottom: .mix(a0.groundBottomValue, a1.groundBottomValue, amount: atm.amount),
            groundPlane: .mix(a0.groundPlaneValue, a1.groundPlaneValue, amount: atm.amount),
            horizonWash: .mix(a0.horizonWashValue, a1.horizonWashValue, amount: atm.amount),
            ink: .mix(f0.inkValue, f1.inkValue, amount: fig.amount),
            inkSecondary: .mix(f0.inkSecondaryValue, f1.inkSecondaryValue, amount: fig.amount),
            metal: .mix(a0.metalValue, a1.metalValue, amount: atm.amount),
            metalHighlight: .mix(a0.metalHighlightValue, a1.metalHighlightValue, amount: atm.amount),
            leafGold: .mix(a0.leafGoldValue, a1.leafGoldValue, amount: atm.amount),
            keyline: .mix(f0.keylineValue, f1.keylineValue, amount: fig.amount),
            lapis: .mix(a0.lapisValue, a1.lapisValue, amount: atm.amount),
            glow: .mix(a0.glowValue, a1.glowValue, amount: atm.amount),
            panelFill: .mix(f0.panelFillValue, f1.panelFillValue, amount: fig.amount),
            panelStroke: .mix(a0.panelStrokeValue, a1.panelStrokeValue, amount: atm.amount),
            panelTexture: .mix(a0.panelTextureValue, a1.panelTextureValue, amount: atm.amount),
            panelTextureOpacity: a0.panelTextureOpacity
                + (a1.panelTextureOpacity - a0.panelTextureOpacity) * atm.amount,
            positive: .mix(f0.positiveValue, f1.positiveValue, amount: fig.amount),
            attention: .mix(f0.attentionValue, f1.attentionValue, amount: fig.amount),
            inkHalo: .mix(f0.inkHaloValue, f1.inkHaloValue, amount: fig.amount)
        )
        tokens.inkHaloStrength = phase.inkHaloStrength
        // Keep the two halo poles un-blended through a crossing:
        // darker and lighter of the crossing states' halo tints. On a
        // plateau (fig.from == fig.to) both poles collapse to the
        // canonical halo, matching the fixed-state tokens exactly.
        if f0.inkHaloValue.relativeLuminance <= f1.inkHaloValue.relativeLuminance {
            tokens.inkHaloDarkValue = f0.inkHaloValue
            tokens.inkHaloLightValue = f1.inkHaloValue
        } else {
            tokens.inkHaloDarkValue = f1.inkHaloValue
            tokens.inkHaloLightValue = f0.inkHaloValue
        }
        return tokens
    }

    public var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

/// The complete semantic token set of palette v2. Call sites never see
/// raw hex — they read roles. Raw `SRGBValue`s are exposed alongside
/// the `Color` accessors so contrast can be verified mathematically.
public struct SkyPaletteTokens: Sendable, Equatable {

    // MARK: Ground

    /// The very top of the sky — the manuscript chord's blue pole.
    /// On the day states this is a genuine faint blue (it is a SKY),
    /// blending down through `groundTop` to the warm horizon; the
    /// jewel states carry a deeper zenith of their own family. Sky
    /// gradient stops between zenith and ground are generated in
    /// OKLCH so the blue→warm ramp never grays out.
    public var skyZenithValue: SRGBValue
    /// Top anchor of the sky gradient.
    public var groundTopValue: SRGBValue
    /// Bottom anchor of the sky gradient.
    public var groundBottomValue: SRGBValue
    /// The band below the horizon chord — the earth the plate stands
    /// on. A deeper value of the day's ground family: warm ivory on
    /// the near-white days, deeper indigo/plum on the jewel grounds.
    /// Never a desaturated gray — the token audit pins its warmth.
    public var groundPlaneValue: SRGBValue
    /// Atmospheric wash blended into the horizon band only — never a
    /// full-surface fill.
    public var horizonWashValue: SRGBValue

    // MARK: Ink

    /// Primary text and linework. Targets ≥7:1 on every ground.
    public var inkValue: SRGBValue
    /// Secondary text. ≥4.5:1 on every ground.
    public var inkSecondaryValue: SRGBValue

    // MARK: Metal

    /// Brass/gold — ornament bodies, filament lines, panel edges.
    public var metalValue: SRGBValue
    /// The bright pole of the metal, for specular edges and the lit
    /// side of ornaments.
    public var metalHighlightValue: SRGBValue
    /// Solid burnished gold — the manuscript gold-leaf FILL of a
    /// gilded ornament. Richer than `metal` (which is linework) so a
    /// solid field of it reads as leaf, not tan.
    public var leafGoldValue: SRGBValue

    // MARK: Keyline

    /// The fine dark boundary of every gilded form — deep ultramarine
    /// (#1B2350 family). The dark edge is what makes gold read as
    /// gold rather than tan; ~0.75 pt around solid fills.
    public var keylineValue: SRGBValue

    // MARK: Lapis

    /// Ultramarine pigment — the chord's second voice beside the
    /// gold. Fills the interiors of gilded ornaments and draws the
    /// lapis filament paired with the gold horizon filament.
    public var lapisValue: SRGBValue

    // MARK: Light

    /// Warm luminosity — celestial bodies and the current prayer only.
    public var glowValue: SRGBValue

    // MARK: Panels

    /// Body fill of a content panel sitting on the ground.
    public var panelFillValue: SRGBValue
    /// Hairline edge of a panel — a quiet metal tone, decorative only.
    public var panelStrokeValue: SRGBValue
    /// Tint of the parchment-fiber texture overlay on panels.
    public var panelTextureValue: SRGBValue
    /// Opacity of that overlay. Hard-capped at 0.08 by the initializer;
    /// the palette tests re-assert the cap for every state.
    public var panelTextureOpacity: Double

    // MARK: Status

    /// Affirmative status (logged, on-time). ≥4.5:1 on panel and ground.
    public var positiveValue: SRGBValue
    /// Cautionary status (missed, attention). ≥4.5:1 on panel and ground.
    public var attentionValue: SRGBValue

    // MARK: Transition legibility

    /// Opposite-pole halo tint for text. Applied behind glyphs at
    /// `inkHaloStrength` so text stays legible through the brief
    /// mid-tone crossing at sunrise and maghrib, where continuous
    /// interpolation provably passes ink and ground through equal
    /// luminance.
    public var inkHaloValue: SRGBValue
    /// How strongly the halo applies right now, `0...1`. Zero for
    /// every canonical state; nonzero only inside polarity-crossing
    /// transitions.
    public var inkHaloStrength: Double = 0

    /// The two halo poles, preserved un-blended through a transition.
    /// Blending the halo colors would produce a mid-tone exactly when
    /// the halo is needed most (both figure states' halos average to
    /// mush at the crossing) — so text draws BOTH poles: the dark one
    /// crisps the glyph edge, the light one lifts it off the ground,
    /// and whichever matches the local ground simply disappears. On a
    /// plateau both poles equal `inkHaloValue` (and strength is zero).
    public var inkHaloDarkValue: SRGBValue
    public var inkHaloLightValue: SRGBValue

    public init(
        skyZenith: SRGBValue? = nil,
        groundTop: SRGBValue,
        groundBottom: SRGBValue,
        groundPlane: SRGBValue,
        horizonWash: SRGBValue,
        ink: SRGBValue,
        inkSecondary: SRGBValue,
        metal: SRGBValue,
        metalHighlight: SRGBValue,
        leafGold: SRGBValue,
        keyline: SRGBValue,
        lapis: SRGBValue,
        glow: SRGBValue,
        panelFill: SRGBValue,
        panelStroke: SRGBValue,
        panelTexture: SRGBValue,
        panelTextureOpacity: Double,
        positive: SRGBValue,
        attention: SRGBValue,
        inkHalo: SRGBValue
    ) {
        self.skyZenithValue = skyZenith ?? groundTop
        self.groundTopValue = groundTop
        self.groundBottomValue = groundBottom
        self.groundPlaneValue = groundPlane
        self.horizonWashValue = horizonWash
        self.inkValue = ink
        self.inkSecondaryValue = inkSecondary
        self.metalValue = metal
        self.metalHighlightValue = metalHighlight
        self.leafGoldValue = leafGold
        self.keylineValue = keyline
        self.lapisValue = lapis
        self.glowValue = glow
        self.panelFillValue = panelFill
        self.panelStrokeValue = panelStroke
        self.panelTextureValue = panelTexture
        self.panelTextureOpacity = min(0.08, max(0.0, panelTextureOpacity))
        self.positiveValue = positive
        self.attentionValue = attention
        self.inkHaloValue = inkHalo
        self.inkHaloDarkValue = inkHalo
        self.inkHaloLightValue = inkHalo
    }

    // MARK: - SwiftUI accessors

    /// Flat ground — the Reduce Transparency fallback for the gradient,
    /// and the fill for chrome that wants a single ground tone.
    public var ground: Color { SRGBValue.mix(groundTopValue, groundBottomValue, amount: 0.5).color }
    /// The vertical sky gradient.
    public var groundGradient: LinearGradient {
        LinearGradient(
            colors: [groundTopValue.color, groundBottomValue.color],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    public var horizonWash: Color { horizonWashValue.color }
    public var ink: Color { inkValue.color }
    public var inkSecondary: Color { inkSecondaryValue.color }
    public var metal: Color { metalValue.color }
    public var metalHighlight: Color { metalHighlightValue.color }
    public var skyZenith: Color { skyZenithValue.color }
    public var leafGold: Color { leafGoldValue.color }
    public var keyline: Color { keylineValue.color }
    public var lapis: Color { lapisValue.color }
    public var glow: Color { glowValue.color }
    public var panelFill: Color { panelFillValue.color }
    public var panelStroke: Color { panelStrokeValue.color }
    public var panelTexture: Color { panelTextureValue.color.opacity(panelTextureOpacity) }
    public var positive: Color { positiveValue.color }
    public var attention: Color { attentionValue.color }
    public var inkHalo: Color { inkHaloValue.color.opacity(inkHaloStrength) }
    /// Dark pole of the transition halo at the current strength.
    public var inkHaloDark: Color { inkHaloDarkValue.color.opacity(inkHaloStrength) }
    /// Light pole of the transition halo at the current strength.
    public var inkHaloLight: Color { inkHaloLightValue.color.opacity(inkHaloStrength) }

    /// The below-horizon ground plane. A real token per state
    /// (corrective E item 4) — the earlier lightness-scaled derivation
    /// produced a desaturated gray on the near-white days, which read
    /// as unpainted primer and muddied the glass chrome sampling it.
    public var groundPlane: Color { groundPlaneValue.color }

    /// Backing tint for Liquid Glass chrome standing on the ground
    /// plane (corrective E item 5). On the near-white days, bare
    /// glass sampling the warm-ivory ground reads olive; this warm
    /// near-white lift keeps the bar warm and quiet. Jewel grounds
    /// return clear — platform glass over a dark page needs no help.
    /// A backing layer, never a tint of the glass itself: chrome
    /// remains the only surface carrying the platform's native glass.
    public var chromeTint: Color {
        groundPlaneValue.relativeLuminance > 0.5
            ? SRGBValue.mix(panelFillValue, horizonWashValue, amount: 0.45).color.opacity(0.72)
            : .clear
    }

    /// Legacy name for the ground plane, kept so older call sites and
    /// tests read the same token the sky view fills with.
    public var subterranean: Color { groundPlaneValue.color }
    public var subterraneanValue: SRGBValue { groundPlaneValue }

    /// Backing tint for the log sheet's glass — SkyPhase-aware on
    /// EVERY ground (corrective G, phase 3). `chromeTint` returns
    /// clear on jewel grounds because a bar of bare glass over the
    /// dark page needs no help; a full-height sheet is not a bar —
    /// bare material over the night plate read as a flat charcoal
    /// slab. The sheet's backing therefore carries the ground family
    /// in all four phases: warm near-white on the days, deep
    /// indigo/plum on the jewel grounds — glass that refracts the sky
    /// it stands in. A backing layer under the platform material,
    /// never a tint of the glass itself.
    public var sheetBackingValue: SRGBValue {
        groundPlaneValue.relativeLuminance > 0.5
            ? SRGBValue.mix(panelFillValue, horizonWashValue, amount: 0.45)
            : SRGBValue.mix(panelFillValue, groundPlaneValue, amount: 0.35)
    }

    /// Opacity of the sheet backing over the platform glass.
    public var sheetBackingOpacity: Double {
        groundPlaneValue.relativeLuminance > 0.5 ? 0.72 : 0.62
    }

    public var sheetBacking: Color {
        sheetBackingValue.color.opacity(sheetBackingOpacity)
    }

    // MARK: - Page ground (secondary pages)

    /// Top anchor of the secondary pages' ground — a QUIETER
    /// derivative of the sky at this phase: same family and warmth,
    /// lower drama. The zenith blue is omitted entirely and the top
    /// starts a third of the way toward the bottom value, so the
    /// gradient reads as a settled wash rather than a painted sky.
    /// Path, Reflect, and Set all consume this one definition.
    public var pageGroundTopValue: SRGBValue {
        SRGBValue.mix(groundTopValue, groundBottomValue, amount: 0.35)
    }

    /// Bottom anchor of the page ground — the sky gradient's own
    /// bottom, unchanged, so a tab switch keeps the horizon family.
    public var pageGroundBottomValue: SRGBValue {
        groundBottomValue
    }

    /// The quiet page gradient for secondary pages.
    public var pageGround: LinearGradient {
        LinearGradient(
            colors: [pageGroundTopValue.color, pageGroundBottomValue.color],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Flat page ground — the Reduce Transparency fallback.
    public var pageGroundFlatValue: SRGBValue {
        SRGBValue.mix(pageGroundTopValue, pageGroundBottomValue, amount: 0.5)
    }

    public var pageGroundFlat: Color { pageGroundFlatValue.color }
}

/// The one resolver for secondary-page chrome: SkyPhase → the quiet
/// page ground and the token set its panels and ink read from.
/// Defined once here so no page can derive its own ground.
public enum IhsanPageChrome {
    /// The day's real solar events, published by the one surface that
    /// owns a schedule (the Today snapshot refresh). While present
    /// and current, every page ground rides the identical solar
    /// transition as the celestial plate — dawn included; the clock
    /// approximation remains only as the cold-launch fallback before
    /// the first schedule resolves.
    private static let publishedEvents = Mutex<SolarDayEvents?>(nil)

    /// How far from the published day's solar noon the events are
    /// still trusted. Beyond this the schedule is stale (the app slept
    /// through a refresh) and the clock fallback is the honest answer.
    private static let validitySpan: TimeInterval = 36 * 3600

    /// Publish (or clear) the day's real solar events for page chrome.
    public static func publish(_ events: SolarDayEvents?) {
        publishedEvents.withLock { $0 = events }
    }

    /// The phase page chrome rides at `date`: the published solar
    /// events when current, the clock approximation otherwise.
    public static func phase(at date: Date, timeZone: TimeZone = .current) -> SkyPhase {
        if let events = publishedEvents.withLock({ $0 }),
           abs(date.timeIntervalSince(events.solarNoon)) < validitySpan {
            return SkyPhase.resolve(at: date, events: events)
        }
        return SkyPhase.approximate(at: date, timeZone: timeZone)
    }

    /// Tokens for a secondary page at `date`.
    public static func tokens(at date: Date, timeZone: TimeZone = .current) -> SkyPaletteTokens {
        PaletteState.resolved(for: phase(at: date, timeZone: timeZone))
    }

    /// The quiet page ground for a given phase.
    public static func pageGround(for phase: SkyPhase) -> LinearGradient {
        PaletteState.resolved(for: phase).pageGround
    }
}

// MARK: - Canonical states

extension SkyPaletteTokens {

    /// Dawn (fajr → sunrise). Twilight as its own state, not a blend
    /// artifact: deep indigo lightening toward the horizon, the last
    /// stars still out, the sun below the chord with only its growing
    /// glow. One family step lighter than night so the passage reads
    /// as first light on the same page — the polarity flip to the
    /// luminous morning ground happens at sunrise, as it does in the
    /// sky.
    static let dawn = SkyPaletteTokens(
        skyZenith: SRGBValue(hex: 0x0C1132),
        groundTop: SRGBValue(hex: 0x121838),
        groundBottom: SRGBValue(hex: 0x232C5A),
        groundPlane: SRGBValue(hex: 0x0C112E),
        horizonWash: SRGBValue(hex: 0x3E3C6E),
        ink: SRGBValue(hex: 0xEDEFF6),
        inkSecondary: SRGBValue(hex: 0xAEB4CB),
        metal: SRGBValue(hex: 0xC9A96A),
        metalHighlight: SRGBValue(hex: 0xE8D5A3),
        leafGold: SRGBValue(hex: 0xD2AC5C),
        keyline: SRGBValue(hex: 0x10163A),
        lapis: SRGBValue(hex: 0x3B4685),
        glow: SRGBValue(hex: 0xF3C77F),
        panelFill: SRGBValue(hex: 0x1B2350),
        panelStroke: SRGBValue(hex: 0x655C58),
        panelTexture: SRGBValue(hex: 0xE8D5A3),
        panelTextureOpacity: 0.04,
        positive: SRGBValue(hex: 0x8FBF9F),
        attention: SRGBValue(hex: 0xE59A82),
        inkHalo: SRGBValue(hex: 0x0C112E)
    )

    /// Night (isha → fajr). Tinted near-black indigo ground —
    /// never pure black, so panels don't float and OLED halation stays
    /// controlled. Warmth lives in the brass and the glow.
    static let night = SkyPaletteTokens(
        skyZenith: SRGBValue(hex: 0x0A0E28),
        groundTop: SRGBValue(hex: 0x0E1330),
        groundBottom: SRGBValue(hex: 0x141A3A),
        groundPlane: SRGBValue(hex: 0x0A0E26),
        horizonWash: SRGBValue(hex: 0x232B5C),
        ink: SRGBValue(hex: 0xECEEF5),
        inkSecondary: SRGBValue(hex: 0xA9AFC4),
        metal: SRGBValue(hex: 0xC9A96A),
        metalHighlight: SRGBValue(hex: 0xE8D5A3),
        leafGold: SRGBValue(hex: 0xD2AC5C),
        keyline: SRGBValue(hex: 0x10163A),
        lapis: SRGBValue(hex: 0x39447F),
        glow: SRGBValue(hex: 0xF0D18B),
        panelFill: SRGBValue(hex: 0x191F46),
        panelStroke: SRGBValue(hex: 0x5F5654),
        panelTexture: SRGBValue(hex: 0xE8D5A3),
        panelTextureOpacity: 0.04,
        positive: SRGBValue(hex: 0x8FBF9F),
        attention: SRGBValue(hex: 0xE59A82),
        inkHalo: SRGBValue(hex: 0x0B1028)
    )

    /// Morning (sunrise → solar noon). THE corrected state: luminous
    /// cool near-white with a faint cool-blue horizon wash — early
    /// light on cool air, not antique paper. Saturation sits in the
    /// deep-indigo ink and the warm sun glow, never in the ground.
    static let morning = SkyPaletteTokens(
        skyZenith: SRGBValue(hex: 0xC3D8F0),
        groundTop: SRGBValue(hex: 0xF5F7FA),
        groundBottom: SRGBValue(hex: 0xEEF2F7),
        groundPlane: SRGBValue(hex: 0xE8E0CB),
        horizonWash: SRGBValue(hex: 0xDCE7F4),
        ink: SRGBValue(hex: 0x1B2350),
        inkSecondary: SRGBValue(hex: 0x4A5378),
        metal: SRGBValue(hex: 0xA8895A),
        metalHighlight: SRGBValue(hex: 0xC9A96A),
        leafGold: SRGBValue(hex: 0xC29B4C),
        keyline: SRGBValue(hex: 0x1B2350),
        lapis: SRGBValue(hex: 0x2A3780),
        glow: SRGBValue(hex: 0xE7A93E),
        panelFill: SRGBValue(hex: 0xFBFCFE),
        panelStroke: SRGBValue(hex: 0xD6C8B4),
        panelTexture: SRGBValue(hex: 0xC9A96A),
        panelTextureOpacity: 0.05,
        positive: SRGBValue(hex: 0x2E6B47),
        attention: SRGBValue(hex: 0xAA3F24),
        inkHalo: SRGBValue(hex: 0xF7F9FC)
    )

    /// Afternoon (solar noon → maghrib). A HINT of warmth in a
    /// near-white — deliberately one step from morning, nowhere near
    /// beige. Ink stays in the indigo family for continuity.
    static let afternoon = SkyPaletteTokens(
        skyZenith: SRGBValue(hex: 0xCBD8EB),
        groundTop: SRGBValue(hex: 0xFAF8F3),
        groundBottom: SRGBValue(hex: 0xF5F1E9),
        groundPlane: SRGBValue(hex: 0xE9DFC2),
        horizonWash: SRGBValue(hex: 0xF3EAD6),
        ink: SRGBValue(hex: 0x231F3D),
        inkSecondary: SRGBValue(hex: 0x4C4668),
        metal: SRGBValue(hex: 0xB8923F),
        metalHighlight: SRGBValue(hex: 0xE0BC6A),
        leafGold: SRGBValue(hex: 0xC79E45),
        keyline: SRGBValue(hex: 0x201D48),
        lapis: SRGBValue(hex: 0x2C3579),
        glow: SRGBValue(hex: 0xECBB55),
        panelFill: SRGBValue(hex: 0xFEFCF7),
        panelStroke: SRGBValue(hex: 0xDECCA4),
        panelTexture: SRGBValue(hex: 0xE0BC6A),
        panelTextureOpacity: 0.06,
        positive: SRGBValue(hex: 0x2E6B47),
        attention: SRGBValue(hex: 0xAA3F24),
        inkHalo: SRGBValue(hex: 0xFBF8F1)
    )

    /// Sunset (maghrib window → isha). Deep plum-vermillion jewel
    /// ground; the gold carries the light.
    static let sunset = SkyPaletteTokens(
        skyZenith: SRGBValue(hex: 0x2C1128),
        groundTop: SRGBValue(hex: 0x3A1526),
        groundBottom: SRGBValue(hex: 0x7A2233),
        groundPlane: SRGBValue(hex: 0x38101F),
        horizonWash: SRGBValue(hex: 0x9A4430),
        ink: SRGBValue(hex: 0xF2E9E4),
        inkSecondary: SRGBValue(hex: 0xDCC0C7),
        metal: SRGBValue(hex: 0xD4A94E),
        metalHighlight: SRGBValue(hex: 0xF0CC80),
        leafGold: SRGBValue(hex: 0xDCAF54),
        keyline: SRGBValue(hex: 0x191F4A),
        lapis: SRGBValue(hex: 0x333C74),
        glow: SRGBValue(hex: 0xF6B96E),
        panelFill: SRGBValue(hex: 0x4C1F30),
        panelStroke: SRGBValue(hex: 0x82563C),
        panelTexture: SRGBValue(hex: 0xF0CC80),
        panelTextureOpacity: 0.05,
        positive: SRGBValue(hex: 0xA9CDB4),
        attention: SRGBValue(hex: 0xF2AC8E),
        inkHalo: SRGBValue(hex: 0x43182A)
    )
}

public extension SkyPaletteTokens {
    /// Ink for a face seen on a nightstand.
    ///
    /// StandBy at three in the morning gets Night Mode's red shift,
    /// which discards the blue and green channels. A bright white
    /// becomes a glare with no colour left in it; warm parchment held
    /// at 84% keeps its character through the tint and never becomes a
    /// light source in a dark room.
    ///
    /// Held at 0.94 red rather than 0.92: Night Mode's tint leaves the
    /// red channel doing nearly all the separating, and the darker
    /// value measured 4.47:1 against the nightstand ground once the
    /// other two were discarded — just under AA, on the one surface
    /// read in the dark.
    var standByInkValue: SRGBValue {
        SRGBValue(red: 0.94, green: 0.89, blue: 0.80)
    }

    var standByInk: Color {
        standByInkValue.color.opacity(0.84)
    }

    var standByInkSecondary: Color {
        standByInkValue.color.opacity(0.55)
    }
}
