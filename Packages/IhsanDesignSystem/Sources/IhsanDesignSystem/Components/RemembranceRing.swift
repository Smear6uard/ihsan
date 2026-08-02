import CoreGraphics
import SwiftUI

/// How a ring of a given count is drawn.
///
/// The tasbīḥ instrument counts to thirty-three and its ring is
/// thirty-three engraved marks. A remembrance set asks for one, three,
/// seven, ten, thirty-three, thirty-four or a hundred, and thirty-three
/// marks' worth of geometry serves none of the others: three ticks
/// spaced a hundred and twenty degrees apart reads as a broken ring,
/// and a hundred reads as a hatched band.
///
/// So the form follows the count. A small count is a DIVIDED RING — arc
/// segments with gaps, the illuminated roundel the manuscript language
/// already speaks. A large count is the instrument's own engraved
/// ticks. One is the whole round, undivided, which is what one is.
public enum RemembranceRingGeometry {

    /// At or below this, the ring divides into arcs; above it, ticks.
    /// Twelve arcs still read as a divided roundel; more start to read
    /// as a dashed line.
    public static let arcThreshold = 12

    public enum Form: Sendable, Equatable {
        /// One continuous engraved ring that gilds whole.
        case unity
        /// `count` arcs separated by gaps.
        case arcs(gapDegrees: Double)
        /// `count` engraved ticks around the circle.
        case ticks(width: CGFloat, height: CGFloat)
    }

    public static func form(count: Int, radius: CGFloat) -> Form {
        guard count > 1 else { return .unity }
        if count <= arcThreshold {
            // Wide enough to read as a gap, never so wide the ring
            // stops being a ring.
            return .arcs(gapDegrees: min(8, 120 / Double(count)))
        }
        let circumference = 2 * .pi * radius
        let pitch = circumference / CGFloat(count)
        return .ticks(
            // Just over a third of the pitch: the mark reads as engraved
            // into the ring rather than filling it.
            width: min(3.5, max(1.1, pitch * 0.38)),
            // The instrument's own 16 pt up to thirty-three-ish; shorter
            // past that, where a hundred full-length marks would read as
            // a hatched band.
            height: count <= 40 ? 16 : 11
        )
    }

    /// Sweep of one arc, in degrees, for the arc form.
    public static func arcSweep(count: Int, gapDegrees: Double) -> Double {
        max(1, 360 / Double(count) - gapDegrees)
    }
}

/// The counting ring, shared by the tasbīḥ instrument and the
/// remembrance sets so the two can never drift apart.
///
/// Reduce Motion collapses the gilding pour to an instant fill; the
/// ring is otherwise identical.
public struct RemembranceRing<Center: View>: View {
    private let count: Int
    private let filled: Int
    private let tokens: SkyPaletteTokens
    private let reduceMotion: Bool
    private let center: Center

    /// Inset from the ring's bounding square to the mark track — the
    /// instrument's own figure, kept so both surfaces sit identically.
    private static var trackInset: CGFloat { 14 }

    /// The quiet state of a mark not yet counted.
    ///
    /// `metal` — the app's brass — measures 2.58:1 at full strength on
    /// the worst ground, below the 3:1 a functional mark owes, and an
    /// uncounted mark is functional: it is how far there is to go.
    /// `inkSecondary` at 0.70 measures 3.48:1 at worst. Gilded marks
    /// keep the leaf-and-keyline silhouette unchanged.
    static func pendingStroke(_ tokens: SkyPaletteTokens) -> Color {
        RemembranceRingPending.stroke(tokens)
    }

    public init(
        count: Int,
        filled: Int,
        tokens: SkyPaletteTokens,
        reduceMotion: Bool,
        @ViewBuilder center: () -> Center
    ) {
        self.count = max(1, count)
        self.filled = filled
        self.tokens = tokens
        self.reduceMotion = reduceMotion
        self.center = center()
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let radius = side / 2 - Self.trackInset

            ZStack {
                marks(radius: radius)
                center
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: filled)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func marks(radius: CGFloat) -> some View {
        switch RemembranceRingGeometry.form(count: count, radius: radius) {
        case .unity:
            // Heavier than a hairline even ungilded: one round mark has
            // to read as a mark, not as an outline someone forgot to
            // fill.
            RingArc(startDegrees: 0, sweepDegrees: 360, radius: radius)
                .stroke(
                    filled >= 1
                        ? AnyShapeStyle(tokens.leafGold)
                        : AnyShapeStyle(Self.pendingStroke(tokens)),
                    style: StrokeStyle(lineWidth: filled >= 1 ? 5 : 2.0)
                )
                .overlay {
                    if filled >= 1 {
                        RingArc(startDegrees: 0, sweepDegrees: 360, radius: radius)
                            .stroke(tokens.keyline.opacity(0.55), lineWidth: 0.8)
                    }
                }

        case .arcs(let gapDegrees):
            let sweep = RemembranceRingGeometry.arcSweep(count: count, gapDegrees: gapDegrees)
            ForEach(0..<count, id: \.self) { index in
                let start = Double(index) * 360 / Double(count) + gapDegrees / 2
                RingArc(startDegrees: start, sweepDegrees: sweep, radius: radius)
                    .stroke(
                        index < filled
                            ? AnyShapeStyle(tokens.leafGold)
                            : AnyShapeStyle(Self.pendingStroke(tokens)),
                        style: StrokeStyle(lineWidth: index < filled ? 5 : 1.4, lineCap: .butt)
                    )
                    .overlay {
                        if index < filled {
                            RingArc(startDegrees: start, sweepDegrees: sweep, radius: radius)
                                .stroke(tokens.keyline.opacity(0.55), lineWidth: 0.8)
                        }
                    }
            }

        case .ticks(let width, let height):
            ForEach(0..<count, id: \.self) { index in
                RingTick(
                    gilded: index < filled,
                    justGilded: index == filled - 1,
                    tokens: tokens,
                    reduceMotion: reduceMotion
                )
                .frame(width: width, height: height)
                .offset(y: -radius)
                .rotationEffect(.degrees(Double(index) / Double(count) * 360))
            }
        }
    }
}

public extension RemembranceRing where Center == EmptyView {
    init(count: Int, filled: Int, tokens: SkyPaletteTokens, reduceMotion: Bool) {
        self.init(
            count: count, filled: filled, tokens: tokens, reduceMotion: reduceMotion
        ) { EmptyView() }
    }
}

/// One arc of the divided ring, measured clockwise from twelve
/// o'clock so a set reads in the direction it is counted.
struct RingArc: Shape {
    let startDegrees: Double
    let sweepDegrees: Double
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: .degrees(startDegrees - 90),
            endAngle: .degrees(startDegrees - 90 + sweepDegrees),
            clockwise: false
        )
        return path
    }
}

/// Where the ungilded stroke's colour comes from, reachable from the
/// tick view without going through the generic ring type.
enum RemembranceRingPending {
    static func stroke(_ tokens: SkyPaletteTokens) -> Color {
        tokens.inkSecondary.opacity(0.70)
    }
}

/// One engraved mark of the ring: a fine outline until its count
/// arrives, then gilded — solid gold bounded by the keyline, with the
/// materialize pour at small scale. Under Reduce Motion the pour is an
/// instant fill.
struct RingTick: View {
    let gilded: Bool
    let justGilded: Bool
    let tokens: SkyPaletteTokens
    let reduceMotion: Bool

    var body: some View {
        Capsule()
            .fill(gilded ? AnyShapeStyle(tokens.leafGold) : AnyShapeStyle(.clear))
            .overlay {
                Capsule().strokeBorder(
                    gilded
                        ? tokens.keyline.opacity(0.55)
                        : RemembranceRingPending.stroke(tokens),
                    lineWidth: gilded ? 0.8 : 0.9
                )
            }
            .scaleEffect(scale)
    }

    private var scale: Double {
        guard !reduceMotion, justGilded else { return 1 }
        return 1.18
    }
}

#Preview("Counting rings at their transmitted counts") {
    let tokens = PaletteState.resolved(for: SkyPhase.fixed(.night))
    return ZStack {
        tokens.groundGradient.ignoresSafeArea()
        ScrollView {
            VStack(spacing: 28) {
                ForEach([1, 3, 7, 10, 33, 34, 100], id: \.self) { count in
                    VStack(spacing: 6) {
                        Text("\(count)")
                            .font(IhsanFont.inscription)
                            .tracking(1.6)
                            .foregroundStyle(tokens.inkSecondary)
                        RemembranceRing(
                            count: count,
                            filled: max(1, count / 2),
                            tokens: tokens,
                            reduceMotion: false
                        )
                        .frame(width: 150, height: 150)
                    }
                }
            }
            .padding()
        }
    }
}
