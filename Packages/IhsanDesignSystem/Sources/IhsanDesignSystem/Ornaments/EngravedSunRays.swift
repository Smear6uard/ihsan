import CoreGraphics
import Foundation

/// The ray collar engraved around the real sun — the day state's
/// signature mark (corrective H item 2).
///
/// The plate has always had two suns that never met: the Dhuhr
/// **Shamsa**, an illuminator's twelve-lobed "little sun" with
/// radiating rays, and the actual sun overhead, which was pure painted
/// light. This is the join. The collar takes the Shamsa's own angular
/// construction — twelve rays at 30°, first at −90°, alternating long
/// and short — so the sky's sun and the page's ornaments are literally
/// the same hand.
///
/// This type owns the construction and nothing else. It returns
/// polylines; `PlateGeometry.sunRayFilamentSegments` cuts them against
/// the plate's knockouts and rebuilds each kept run as a tapered
/// ribbon, so the collar is drawn by exactly the machinery that draws
/// the day arc and the almucantars — and obeys exactly the same rule.
/// That rule is the reason the construction lives here rather than
/// inside `LuminousBody`: around solar noon the sun stands on Dhuhr's
/// marker, and a ray system that ran through the Shamsa and its label
/// would be linework crossing a medallion, which the plate does not
/// do anywhere else.
///
/// What it is not, and must never become:
///
/// - **Not light.** These are engraved lines laid over the bloom, the
///   way linework is drawn over laid gold on the page. They render in
///   `metal`, not `glow`, and they are darker than the field they sit
///   on.
/// - **Not a camera artifact.** No streaks, no flare, no anamorphic
///   spread. The first pass ran the rays out to 1.05 diameters and it
///   was wrong in kind rather than in degree: twelve spokes reaching
///   past the bloom is a starburst, and a starburst is a lens
///   rendering — the one family of image this plate is permanently
///   forbidden. A collar of short ticks at the bloom's edge is an
///   engraving. Same construction, opposite reading.
/// - **Not animated, and never rotating.** Nothing here reads a clock.
///   The collar is placed at the sun's own position and travels with
///   it; it does not turn with the hour.
///
/// The collar starts outside the radius at which the sun's core has
/// fully dissolved, so the sun still has no pixel at which it stops.
public enum EngravedSunRays {

    /// Twelve rays, first pointing up, exactly as the Shamsa lays them.
    static let rayCount = 12
    static let firstRayDegrees = -90.0

    /// Ray radii as multiples of the sun's disc diameter. A fifth of a
    /// diameter long, sitting where the corona's falloff gives out —
    /// outside the core (which dissolves by 0.45 d) and inside the
    /// corona's outer reach (1.3 d).
    static let innerRadius: CGFloat = 0.68
    static let longRadius: CGFloat = 0.88
    static let shortRadius: CGFloat = 0.82

    /// Samples per ray. Enough that the knockout cutter can terminate a
    /// ray part-way along rather than only keeping or dropping it
    /// whole.
    private static let samplesPerRay = 12

    /// The collar as one polyline per ray, in `center`'s coordinate
    /// space. Rays alternate long and short around the circle.
    public static func rayPolylines(
        around center: CGPoint,
        bodyDiameter: CGFloat
    ) -> [[CGPoint]] {
        let step = 360.0 / Double(rayCount)
        return (0..<rayCount).map { i in
            let radians = (firstRayDegrees + Double(i) * step) * .pi / 180.0
            let dx = CGFloat(cos(radians))
            let dy = CGFloat(sin(radians))
            let from = bodyDiameter * innerRadius
            let to = bodyDiameter * (i.isMultiple(of: 2) ? longRadius : shortRadius)
            return (0...samplesPerRay).map { s in
                let r = from + (to - from) * CGFloat(s) / CGFloat(samplesPerRay)
                return CGPoint(x: center.x + dx * r, y: center.y + dy * r)
            }
        }
    }
}
