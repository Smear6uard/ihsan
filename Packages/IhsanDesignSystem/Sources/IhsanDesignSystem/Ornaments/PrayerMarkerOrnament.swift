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
/// The component is static in every state: glow is a fixed radial
/// halo, not an animation, so Reduce Motion needs no branch here.
public struct PrayerMarkerOrnament: View {

    public let prayer: Prayer
    public let size: CGFloat
    public let state: PrayerMarkerState
    public let tokens: SkyPaletteTokens
    public let lineWeight: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.celestialForceReducedTransparency) private var forceReducedTransparency

    private var reduceTransparency: Bool { systemReduceTransparency || forceReducedTransparency }

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
        lineWeight: CGFloat? = nil
    ) {
        self.prayer = prayer
        self.size = size
        self.state = state
        self.tokens = tokens
        self.lineWeight = lineWeight ?? max(0.8, size / 22)
    }

    public var body: some View {
        ZStack {
            if state == .current {
                glowHalo
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

    @ViewBuilder
    private var glyph: some View {
        switch state {
        case .upcoming:
            PrayerOrnamentShape(prayer: prayer, mode: .outline)
                .stroke(tokens.metal.opacity(0.55), lineWidth: lineWeight)
        case .current, .logged:
            // The gilded body — solid leaf bounded by the dark
            // keyline. For `current` the glow halo renders behind it
            // (see `body`); `logged` carries no glow.
            GildedOrnamentGlyph(prayer: prayer, size: size, tokens: tokens)
        case .passedUnlogged:
            PrayerOrnamentShape(prayer: prayer, mode: .outline)
                .stroke(tokens.inkSecondary, lineWidth: lineWeight)
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
