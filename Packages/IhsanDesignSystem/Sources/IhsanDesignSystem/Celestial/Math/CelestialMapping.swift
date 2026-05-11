import CoreGraphics
import Foundation

/// Map astronomical (hour angle, altitude) coordinates to screen
/// coordinates within the celestial scene zone.
///
/// The celestial scene is conceptually a south-facing window onto the
/// sky. Mapping convention:
///
/// - **X axis** — hour angle from `-90°` (sunrise, leftward) through
///   `0°` (solar noon, centred) to `+90°` (sunset, rightward). The
///   horizontal position is therefore symmetric around solar noon.
/// - **Y axis** — altitude from `0°` (horizon, at the BOTTOM of the
///   scene) up to `90°` (zenith, at the TOP). Negative altitudes are
///   allowed so the maghrib descent animation can dip the sun below
///   the horizon line.
///
/// The "natural arc" of the celestial path comes for free from the
/// underlying astronomical math: at any given hour angle, altitude is
/// determined by the sun's declination and observer latitude. As we
/// sweep hour angle from sunrise to sunset, altitude rises and falls
/// in a natural curve — no special arc-shape parameter required in
/// the mapping itself.
///
/// Insets allow space for the ornament glyphs (sun ~48pt, moon ~56pt,
/// prayer markers ~12pt) to render fully at the edges of the scene
/// without clipping against the focused-prayer card or the header.
public enum CelestialMapping {

    /// Default vertical inset — 40pt of room above the highest sun
    /// position and 40pt below the horizon so ornaments at the
    /// extremities have breathing room.
    public static let defaultVerticalInset: CGFloat = 40

    /// Default horizontal inset — 32pt of room from each edge.
    public static let defaultHorizontalInset: CGFloat = 32

    /// Hour angle range mapped across the scene width. The default of
    /// 100° (±50°) deliberately CROPS the dawn-to-dusk span — most
    /// users open the app well within that range, and cropping keeps
    /// the prayer markers visually distributed across the scene rather
    /// than crammed near the horizons. The maghrib descent animation
    /// uses a wider range temporarily so the sun is visible during the
    /// transition.
    public static let defaultHourAngleSpan: Double = 100.0

    /// Altitude range mapped across the scene height. Spans `-15°`
    /// below horizon (for the maghrib descent and pre-dawn moon dip)
    /// up to `+90°` zenith.
    public static let defaultAltitudeMin: Double = -15.0
    public static let defaultAltitudeMax: Double = 90.0

    /// Map an (hour angle, altitude) pair to a `CGPoint` within a
    /// scene of the given size.
    ///
    /// - Parameters:
    ///   - hourAngle: Local hour angle in degrees. Values outside
    ///     `[-hourAngleSpan, +hourAngleSpan]` are clamped to the scene
    ///     edges so off-screen ornaments hug the left / right borders
    ///     rather than vanishing into negative coordinates.
    ///   - altitude: Altitude in degrees. Clamped to
    ///     `[altitudeMin, altitudeMax]`.
    ///   - size: The size of the celestial scene's drawing area.
    ///   - horizontalInset: Symmetric inset from left and right edges.
    ///   - verticalInset: Inset from top and bottom edges.
    ///   - hourAngleSpan: Half-width of the hour-angle range covered
    ///     by the scene width. Defaults to 50° (so ±50° across).
    ///   - altitudeMin: The altitude value mapped to the bottom edge.
    ///   - altitudeMax: The altitude value mapped to the top edge.
    public static func screenPosition(
        hourAngle: Double,
        altitude: Double,
        in size: CGSize,
        horizontalInset: CGFloat = defaultHorizontalInset,
        verticalInset: CGFloat = defaultVerticalInset,
        hourAngleSpan: Double = defaultHourAngleSpan / 2.0,
        altitudeMin: Double = defaultAltitudeMin,
        altitudeMax: Double = defaultAltitudeMax
    ) -> CGPoint {
        let usableWidth = max(0, size.width - horizontalInset * 2)
        let usableHeight = max(0, size.height - verticalInset * 2)

        // X — hour angle into [0, 1] across the horizontal range.
        let clampedHA = max(-hourAngleSpan, min(hourAngleSpan, hourAngle))
        let xFraction = (clampedHA + hourAngleSpan) / (2.0 * hourAngleSpan)
        let x = horizontalInset + CGFloat(xFraction) * usableWidth

        // Y — altitude into [0, 1]. Higher altitude = smaller y.
        let clampedAlt = max(altitudeMin, min(altitudeMax, altitude))
        let yFraction = (altitudeMax - clampedAlt) / (altitudeMax - altitudeMin)
        let y = verticalInset + CGFloat(yFraction) * usableHeight

        return CGPoint(x: x, y: y)
    }

    /// Convenience overload taking a `SolarPosition` directly.
    public static func screenPosition(
        for position: SolarPosition,
        in size: CGSize,
        horizontalInset: CGFloat = defaultHorizontalInset,
        verticalInset: CGFloat = defaultVerticalInset
    ) -> CGPoint {
        screenPosition(
            hourAngle: position.hourAngle,
            altitude: position.altitude,
            in: size,
            horizontalInset: horizontalInset,
            verticalInset: verticalInset
        )
    }

    /// Convenience overload taking a `LunarPosition` directly.
    public static func screenPosition(
        for position: LunarPosition,
        in size: CGSize,
        horizontalInset: CGFloat = defaultHorizontalInset,
        verticalInset: CGFloat = defaultVerticalInset
    ) -> CGPoint {
        screenPosition(
            hourAngle: position.hourAngle,
            altitude: position.altitude,
            in: size,
            horizontalInset: horizontalInset,
            verticalInset: verticalInset
        )
    }
}
