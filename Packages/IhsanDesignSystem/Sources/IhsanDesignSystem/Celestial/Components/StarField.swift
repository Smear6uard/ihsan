import SwiftUI

/// A deterministic field of small stars rendered as a SwiftUI Canvas
/// overlay on the celestial scene.
///
/// 80 stars placed at pseudo-random positions seeded by the date. Same
/// date → same field, which gives a stable celestial backdrop for the
/// day without requiring any persistence. Star sizes are weighted
/// (60% 1pt, 30% 1.5pt, 10% 2pt) and rendered in brass at 30–50%
/// opacity to read as faint pinpricks of gold leaf scattered across the
/// indigo sky rather than as a bright constellation.
///
/// Visible only when the surrounding sky is in night mode. The
/// `CelestialScene` view modulates the star field's opacity via the
/// `SkyState.starOpacity` value so stars fade in and out smoothly
/// across dawn and dusk.
public struct StarField: View {
    @Environment(\.timeOfDayOverride) private var override

    public init() {}

    public var body: some View {
        TimelineView(.everyMinute) { context in
            let date = override ?? context.date
            Canvas { graphicsContext, size in
                draw(in: graphicsContext, size: size, seed: Self.seed(for: date))
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Number of stars rendered. Tuned for visual density on iPhone
    /// 17 Pro Max screen heights; smaller scenes still read well at
    /// this count because the size weighting keeps most stars small.
    private static let starCount = 80

    /// Stars are drawn over the celestial scene. Their color is the
    /// brass accent from the night palette.
    private func draw(in context: GraphicsContext, size: CGSize, seed: UInt64) {
        guard size.width > 0 && size.height > 0 else { return }
        var rng = SeededRandom(seed: seed)
        let accent = IhsanCelestialPalette.night.accent

        for _ in 0..<Self.starCount {
            let x = rng.nextDouble() * size.width
            let y = rng.nextDouble() * size.height
            let sizeRoll = rng.nextDouble()
            let opacityRoll = rng.nextDouble()

            let pointSize: CGFloat
            if sizeRoll < 0.6 {
                pointSize = 1.0
            } else if sizeRoll < 0.9 {
                pointSize = 1.5
            } else {
                pointSize = 2.0
            }

            // Opacity in [0.3, 0.5] — within the spec's "varying low
            // opacities for depth" band. Stars at the upper end read
            // slightly brighter, suggesting closer / larger stars
            // without ever competing with the moon for attention.
            let opacity = 0.30 + opacityRoll * 0.20

            let rect = CGRect(
                x: x - pointSize / 2,
                y: y - pointSize / 2,
                width: pointSize,
                height: pointSize
            )
            let path = Path(ellipseIn: rect)
            context.fill(path, with: .color(accent.opacity(opacity)))
        }
    }

    /// Seed derived from the date's `year * 1000 + dayOfYear`. The
    /// same calendar day yields the same seed across launches; the
    /// next day yields a different field. The seed is deliberately
    /// independent of time-of-day so the stars don't reshuffle on
    /// every per-minute redraw within a single night.
    static func seed(for date: Date) -> UInt64 {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        return UInt64(year) * 1_000 + UInt64(dayOfYear)
    }
}

/// A linear congruential generator producing reproducible pseudo-random
/// `Double`s in `[0, 1)` from a fixed `UInt64` seed.
///
/// Used by `StarField` for deterministic star layouts and by any other
/// celestial-layer view that needs reproducible randomness keyed off
/// the date (avoiding the need for persistence or `SystemRandom`).
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid a zero seed (LCG would lock at 0).
        self.state = seed == 0 ? 1 : seed
    }

    /// Advance and return the next 64-bit value. Numerical recipes
    /// constants — period ~2⁶⁴.
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005
              &+ 1_442_695_040_888_963_407
        return state
    }

    /// Next pseudo-random `Double` in `[0, 1)`.
    mutating func nextDouble() -> Double {
        // Use the top 53 bits — same precision as `Double`'s mantissa.
        let raw = next() >> 11
        return Double(raw) / Double(1 << 53)
    }
}

#Preview("Star field — night") {
    ZStack {
        SkyGradient()
            .environment(\.timeOfDayOverride, dateAt(hour: 23, minute: 0))
        StarField()
            .environment(\.timeOfDayOverride, dateAt(hour: 23, minute: 0))
    }
    .ignoresSafeArea()
}

private func dateAt(hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 15
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components) ?? .now
}
