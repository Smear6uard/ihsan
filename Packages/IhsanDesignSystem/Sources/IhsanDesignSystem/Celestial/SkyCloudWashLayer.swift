import SwiftUI

/// Partly veiled: one to two soft luminous cloud washes — the
/// manuscript's cloud abstraction, not a weather renderer's.
///
/// Each wash is a flat, banded lift of the sky it lies on: the sky's
/// own value at that height, raised a few points of lightness with its
/// chroma calmed — tinted vellum showing through the blue, in either
/// palette polarity. Flat fill, soft top and bottom edges, firm-ish
/// flanks. No cumulus modelling, no noise, no photographic softness.
///
/// The washes sit ABOVE the atmosphere layer and BELOW the instrument:
/// the sun's bloom warms a wash it sits behind, and every engraved
/// line, ornament, and label reads over the top.
///
/// Motion: a drift of a few points per minute, imperceptible in the
/// watching and only barely caught in the returning. Static under
/// Reduce Motion; gone entirely under Reduce Transparency (the
/// compressed flat field carries the state there).
public struct SkyCloudWashLayer: View {
    public let tokens: SkyPaletteTokens
    /// The horizon chord in this view's coordinate space.
    public let horizonY: CGFloat

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.celestialForceReducedMotion) private var forceReducedMotion
    @Environment(\.celestialForceReducedTransparency) private var forceReducedTransparency

    private var reduceMotion: Bool { systemReduceMotion || forceReducedMotion }
    private var reduceTransparency: Bool { systemReduceTransparency || forceReducedTransparency }

    public init(tokens: SkyPaletteTokens, horizonY: CGFloat) {
        self.tokens = tokens
        self.horizonY = horizonY
    }

    /// How far a wash lifts the sky's lightness. A veil, not a shape.
    public static let washLift: Double = 0.045
    /// Core opacity of the flat fill.
    public static let washPresence: Double = 0.85

    /// The two bands: (center as a fraction of the sky's height,
    /// band height as a fraction, width as a fraction of the frame,
    /// anchored leading?, drift phase).
    private static let bands: [(center: CGFloat, height: CGFloat, width: CGFloat, leading: Bool, phase: Double)] = [
        (0.30, 0.15, 0.82, true, 0.0),
        (0.52, 0.11, 0.68, false, 2.1),
    ]

    public var body: some View {
        if !reduceTransparency, horizonY > 40 {
            TimelineView(
                .animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)
            ) { timeline in
                Canvas { context, size in
                    let t = reduceMotion
                        ? 0.0
                        : timeline.date.timeIntervalSinceReferenceDate
                    for band in Self.bands {
                        draw(band: band, time: t, into: &context, size: size)
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func draw(
        band: (center: CGFloat, height: CGFloat, width: CGFloat, leading: Bool, phase: Double),
        time: TimeInterval,
        into context: inout GraphicsContext,
        size: CGSize
    ) {
        let centerY = horizonY * band.center
        let height = horizonY * band.height
        let width = size.width * band.width
        // A few points over five minutes — the drift is only ever
        // caught by coming back.
        let drift: CGFloat = time == 0
            ? 0
            : CGFloat(sin(time * 2 * .pi / 300 + band.phase)) * 7
        let x = band.leading
            ? -size.width * 0.06 + drift
            : size.width - width + size.width * 0.06 + drift

        // The wash color: the sky at this height, lifted and calmed.
        var lab = CelestialSkyView.skyValue(
            atFraction: Double(centerY / max(horizonY, 1)),
            tokens: tokens
        ).oklab
        lab.l = min(0.985, lab.l + Self.washLift)
        lab.a *= 0.7
        lab.b *= 0.7
        let wash = lab.srgb.color

        let rect = CGRect(x: x, y: centerY - height / 2, width: width, height: height)
        var banded = context
        banded.clip(to: Path(roundedRect: rect, cornerRadius: height / 2))
        banded.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: wash.opacity(0), location: 0),
                    .init(color: wash.opacity(Self.washPresence), location: 0.35),
                    .init(color: wash.opacity(Self.washPresence), location: 0.65),
                    .init(color: wash.opacity(0), location: 1),
                ]),
                startPoint: CGPoint(x: 0, y: rect.minY),
                endPoint: CGPoint(x: 0, y: rect.maxY)
            )
        )
    }
}
