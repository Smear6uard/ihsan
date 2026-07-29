import IhsanCore
import SwiftUI

/// Lifecycle state of a prayer marker on the celestial plate.
public enum PrayerMarkerState: String, Sendable, CaseIterable, Equatable {
    /// Not yet reached — outlined in metal at 55%.
    case upcoming
    /// Happening now — filled, with a luminous glow halo.
    case current
    /// Logged — filled in full-opacity metal, no glow.
    case logged
    /// Window passed without a log — outlined in secondary ink.
    case passedUnlogged

    var accessibilityDescription: String {
        switch self {
        case .upcoming: return "upcoming"
        case .current: return "current prayer"
        case .logged: return "logged"
        case .passedUnlogged: return "passed, not logged"
        }
    }
}

/// The manuscript gold-leaf treatment as ONE unit (the `.gilded`
/// style of the illumination pass): a solid burnished `leafGold`
/// fill bounded by a fine deep-ultramarine keyline, with the form's
/// even-odd interior cutouts reading as drawn linework. Any glow a
/// caller adds must render BEHIND this glyph — `PrayerMarkerOrnament`
/// composes it that way; other call sites use this view rather than
/// re-layering fills ad hoc.
public struct GildedOrnamentGlyph: View {

    public let prayer: Prayer
    public let size: CGFloat
    public let tokens: SkyPaletteTokens
    /// The keyline holds ~0.75 pt at marker sizes and thins gently
    /// below 20 pt so chips stay linework, not outlines.
    public var keylineWidth: CGFloat

    public init(
        prayer: Prayer,
        size: CGFloat,
        tokens: SkyPaletteTokens,
        keylineWidth: CGFloat? = nil
    ) {
        self.prayer = prayer
        self.size = size
        self.tokens = tokens
        self.keylineWidth = keylineWidth ?? min(0.75, max(0.5, size / 40))
    }

    public var body: some View {
        ZStack {
            // Lapis under-layer: the nonzero-winding fill covers the
            // whole silhouette, so wherever the even-odd gold leaves
            // an interior cutout (the Shamsa's heart, the Lawzina's
            // slit, the night star's field inside its ring), the
            // ultramarine shows through — pigment inside the leaf.
            PrayerOrnamentShape(prayer: prayer, mode: .filled)
                .fill(tokens.lapis, style: FillStyle(eoFill: false))
            PrayerOrnamentShape(prayer: prayer, mode: .filled)
                .fill(tokens.leafGold, style: FillStyle(eoFill: true))
            PrayerOrnamentShape(prayer: prayer, mode: .filled)
                .stroke(tokens.keyline, lineWidth: keylineWidth)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A prayer's ornament rendered in one of its four marker states,
/// against the current palette. The glow halo for the `current` state
/// is drawn here, inside the component, so every composition gets it
/// for free — and gets the same one.
///
/// Life (the illumination pass):
///
/// - **Materialization.** A state change between an outline state and
///   a gilded state crossfades outline↔solid over ~300 ms, the gold
///   pouring in from the center (a scaling circular mask). Logging a
///   prayer plays it forward; undo reverses it. Under Reduce Motion
///   the mask is static and only the crossfade remains.
/// - **Breathing.** When `ambientGlowBreathing` is on and the state
///   is `current`, the glow halo breathes on a slow ~5 s cycle
///   (±10 % luminance) behind a paused-under-Reduce-Motion timeline.
///   Off by default so compositions showing the same prayer twice
///   (plate + card) carry a single breathing element.
public struct PrayerMarkerOrnament: View {

    public let prayer: Prayer
    public let size: CGFloat
    public let state: PrayerMarkerState
    public let tokens: SkyPaletteTokens
    public let lineWeight: CGFloat
    /// Opt-in ambient breathing for the `current` state's glow.
    public var ambientGlowBreathing: Bool = false

    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.celestialForceReducedTransparency) private var forceReducedTransparency
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.celestialForceReducedMotion) private var forceReducedMotion

    private var reduceTransparency: Bool { systemReduceTransparency || forceReducedTransparency }
    private var reduceMotion: Bool { systemReduceMotion || forceReducedMotion }

    /// - Parameters:
    ///   - prayer: Which of the five ornaments to draw.
    ///   - size: Edge length of the ornament's square frame in points.
    ///     The glow halo extends beyond this frame but is
    ///     non-interactive and purely decorative.
    ///   - state: Marker lifecycle state.
    ///   - tokens: The active palette. Pass a resolved set — the
    ///     component never resolves phase itself.
    ///   - lineWeight: Stroke width for outline states. The default
    ///     scales gently with size so 16 pt markers stay fine-lined
    ///     and 44 pt markers gain drawing weight.
    public init(
        prayer: Prayer,
        size: CGFloat,
        state: PrayerMarkerState,
        tokens: SkyPaletteTokens,
        lineWeight: CGFloat? = nil,
        ambientGlowBreathing: Bool = false
    ) {
        self.prayer = prayer
        self.size = size
        self.state = state
        self.tokens = tokens
        self.lineWeight = lineWeight ?? max(0.8, size / 22)
        self.ambientGlowBreathing = ambientGlowBreathing
    }

    public var body: some View {
        ZStack {
            if state == .current {
                breathingHalo
            }
            glyph
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(prayer.displayNameEnglish) marker, \(state.accessibilityDescription)"
        )
    }

    private var showsSolid: Bool {
        state == .current || state == .logged
    }

    /// Both faces are always present so a state change between an
    /// outline state and a gilded state is a genuine transition: the
    /// outline fades as the solid gold materializes from the center,
    /// ~300 ms, synchronized with the commit haptic that triggered
    /// it. Undo reverses the same animation.
    @ViewBuilder
    private var glyph: some View {
        ZStack {
            PrayerOrnamentShape(prayer: prayer, mode: .outline)
                .stroke(outlineColor, lineWidth: lineWeight)
                .opacity(showsSolid ? 0 : 1)

            GildedOrnamentGlyph(prayer: prayer, size: size, tokens: tokens)
                .opacity(showsSolid ? 1 : 0)
                .mask {
                    // The fill pours in from the center. Static under
                    // Reduce Motion — the crossfade is the defined
                    // equivalent.
                    Circle()
                        .scaleEffect(
                            reduceMotion ? 1.5 : (showsSolid ? 1.5 : 0.0001)
                        )
                }
        }
        .animation(.easeOut(duration: 0.3), value: state)
    }

    private var outlineColor: Color {
        state == .passedUnlogged
            ? tokens.inkSecondary
            : tokens.metal.opacity(0.55)
    }

    /// The `current` halo, optionally breathing: a slow ~5 s cycle at
    /// ±10 % of the glow's strength, behind a timeline that pauses
    /// under Reduce Motion (static halo, same geometry). Compositions
    /// opt in per instance so at most one element breathes per prayer
    /// on screen.
    @ViewBuilder
    private var breathingHalo: some View {
        if ambientGlowBreathing && !reduceMotion && !reduceTransparency {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                glowHalo
                    .opacity(0.90 + 0.10 * sin(t * 2 * .pi / 5.0))
            }
        } else {
            glowHalo
        }
    }

    /// Soft radial glow behind the current prayer — warm and
    /// metal-toned, never neutral: the halo carries the same brass
    /// family as the ornament it lights. Under Reduce Transparency the
    /// gradient collapses to a single faint disc so the state remains
    /// marked without a translucency ramp.
    private var warmGlow: SRGBValue {
        SRGBValue.mix(tokens.glowValue, tokens.metalValue, amount: 0.45)
    }

    @ViewBuilder
    private var glowHalo: some View {
        let radius = size * 1.35
        let glow = warmGlow.color
        if reduceTransparency {
            Circle()
                .fill(glow.opacity(0.22))
                .frame(width: radius * 1.4, height: radius * 1.4)
                .allowsHitTesting(false)
        } else {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            glow.opacity(0.55),
                            glow.opacity(0.18),
                            glow.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: size * 0.1,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Previews

#Preview("Marker states × palettes") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(PaletteState.allCases, id: \.self) { paletteState in
                let tokens = paletteState.tokens
                VStack(spacing: 12) {
                    Text(paletteState.displayName.uppercased())
                        .font(.system(size: 11, weight: .semibold).smallCaps())
                        .tracking(1.2)
                        .foregroundStyle(tokens.inkSecondary)
                    ForEach(PrayerMarkerState.allCases, id: \.self) { markerState in
                        HStack(spacing: 22) {
                            ForEach(Prayer.allCases, id: \.self) { prayer in
                                PrayerMarkerOrnament(
                                    prayer: prayer,
                                    size: 24,
                                    state: markerState,
                                    tokens: tokens
                                )
                            }
                            Text(markerState.rawValue)
                                .font(.caption2)
                                .foregroundStyle(tokens.inkSecondary)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(tokens.groundGradient)
            }
        }
    }
}
