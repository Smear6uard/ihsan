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

    // MARK: - Horizon-aware piecewise mapping
    //
    // The default symmetric mapping above puts altitude 0° at a fixed
    // y-position determined by `[altitudeMin, altitudeMax]`. That is
    // correct for an isolated celestial-arc preview but wrong for the
    // Today screen: the horizon's y-position must shift with the
    // user's daily cycle so the below-horizon region remains visible
    // (and prayer markers at deep negative altitudes don't collapse
    // off-screen behind the focused-prayer card).
    //
    // The horizon-aware overloads below position altitude 0° at a
    // caller-supplied `horizonYFraction` of the marker zone height,
    // then linearly map above-horizon altitudes upward to the top inset
    // and below-horizon altitudes downward to the bottom inset. The
    // marker zone is defined by asymmetric `topInset` and `bottomInset`
    // so callers can carve out room for the header (top) and focused-
    // prayer card (bottom) without the chrome covering positioned
    // ornaments.

    /// The proportional y-position of the horizon line within the
    /// marker zone, computed from the sun's current altitude. The
    /// returned value is a fraction of the marker-zone height (0.0 =
    /// top of zone, 1.0 = bottom).
    ///
    /// During pure night (sun well below horizon) the horizon sits at
    /// `0.50` so the upper half of the scene holds the visible night
    /// sky and the lower half holds the subterranean band where below-
    /// horizon prayer markers live. During daytime (sun above horizon)
    /// the horizon sits at `0.80` so almost the whole scene is sky and
    /// only a slim band beneath holds any below-horizon markers. The
    /// transitions (Fajr-to-sunrise, Maghrib-to-Isha) interpolate
    /// linearly so the horizon line glides between positions rather
    /// than snapping.
    public static func horizonYFraction(forSunAltitude altitude: Double) -> Double {
        let nightFraction: Double = 0.50
        let dayFraction: Double = 0.80
        let nightAltitudeThreshold: Double = -15.0
        if altitude >= 0 {
            return dayFraction
        }
        if altitude <= nightAltitudeThreshold {
            return nightFraction
        }
        let t = (altitude - nightAltitudeThreshold)
            / (0.0 - nightAltitudeThreshold)
        return nightFraction + t * (dayFraction - nightFraction)
    }

    /// Map an (hour angle, altitude) pair to a `CGPoint` within a
    /// horizon-aware marker zone.
    ///
    /// - Parameters:
    ///   - hourAngle: Local hour angle in degrees, clamped to
    ///     `[-hourAngleSpan, +hourAngleSpan]` as in the default mapping.
    ///   - altitude: Altitude in degrees, clamped to
    ///     `[altitudeMin, altitudeMax]`. Altitude 0° lands exactly on
    ///     the horizon line.
    ///   - size: The size of the celestial scene's drawing area.
    ///   - horizonYFraction: Where within the marker zone altitude 0°
    ///     should land. Typically computed from the current sun's
    ///     altitude via `horizonYFraction(forSunAltitude:)`.
    ///   - topInset: Distance from the top edge of `size` to the top
    ///     of the marker zone. Carves out the header / safe area.
    ///   - bottomInset: Distance from the bottom edge of `size` to the
    ///     bottom of the marker zone. Carves out the focused-prayer
    ///     card / tab bar.
    ///   - horizontalInset: Symmetric inset from left and right edges.
    ///   - hourAngleSpan: Half-width of the hour-angle range covered
    ///     by the scene width.
    ///   - altitudeMax: Altitude mapped to the top of the marker zone.
    ///   - altitudeMin: Altitude mapped to the bottom of the marker
    ///     zone. Negative — far below the horizon line.
    public static func screenPosition(
        hourAngle: Double,
        altitude: Double,
        in size: CGSize,
        horizonYFraction: Double,
        topInset: CGFloat,
        bottomInset: CGFloat,
        horizontalInset: CGFloat = defaultHorizontalInset,
        hourAngleSpan: Double = defaultHourAngleSpan / 2.0,
        altitudeMax: Double = defaultAltitudeMax,
        altitudeMin: Double = defaultAltitudeMin
    ) -> CGPoint {
        let usableWidth = max(0, size.width - horizontalInset * 2)
        let usableHeight = max(0, size.height - topInset - bottomInset)

        // X — same as the default mapping.
        let clampedHA = max(-hourAngleSpan, min(hourAngleSpan, hourAngle))
        let xFraction = (clampedHA + hourAngleSpan) / (2.0 * hourAngleSpan)
        let x = horizontalInset + CGFloat(xFraction) * usableWidth

        // Y — piecewise around the horizon. Above the horizon,
        // altitude `[0, altitudeMax]` maps linearly to y `[horizonY,
        // topInset]`. Below, altitude `[altitudeMin, 0]` maps to y
        // `[bottomY, horizonY]`.
        let clampedFraction = max(0.0, min(1.0, horizonYFraction))
        let horizonY = topInset + CGFloat(clampedFraction) * usableHeight

        let y: CGFloat
        if altitude >= 0 {
            let clampedAlt = min(altitudeMax, altitude)
            let aboveFraction = altitudeMax > 0 ? clampedAlt / altitudeMax : 0
            y = horizonY - CGFloat(aboveFraction) * (horizonY - topInset)
        } else {
            let clampedAlt = max(altitudeMin, altitude)
            let denom = abs(altitudeMin)
            let belowFraction = denom > 0 ? abs(clampedAlt) / denom : 0
            let bottomY = size.height - bottomInset
            y = horizonY + CGFloat(belowFraction) * (bottomY - horizonY)
        }

        return CGPoint(x: x, y: y)
    }

    /// Convenience overload taking a `SolarPosition` directly with
    /// horizon-aware piecewise mapping.
    public static func screenPosition(
        for position: SolarPosition,
        in size: CGSize,
        horizonYFraction: Double,
        topInset: CGFloat,
        bottomInset: CGFloat,
        horizontalInset: CGFloat = defaultHorizontalInset
    ) -> CGPoint {
        screenPosition(
            hourAngle: position.hourAngle,
            altitude: position.altitude,
            in: size,
            horizonYFraction: horizonYFraction,
            topInset: topInset,
            bottomInset: bottomInset,
            horizontalInset: horizontalInset
        )
    }

    /// Convenience overload taking a `LunarPosition` directly with
    /// horizon-aware piecewise mapping.
    public static func screenPosition(
        for position: LunarPosition,
        in size: CGSize,
        horizonYFraction: Double,
        topInset: CGFloat,
        bottomInset: CGFloat,
        horizontalInset: CGFloat = defaultHorizontalInset
    ) -> CGPoint {
        screenPosition(
            hourAngle: position.hourAngle,
            altitude: position.altitude,
            in: size,
            horizonYFraction: horizonYFraction,
            topInset: topInset,
            bottomInset: bottomInset,
            horizontalInset: horizontalInset
        )
    }

    /// The screen y-coordinate of the horizon line for a marker zone
    /// with the given insets and horizon fraction. Convenience for the
    /// scene's horizon-line and subterranean-band positioning.
    public static func horizonY(
        in size: CGSize,
        horizonYFraction: Double,
        topInset: CGFloat,
        bottomInset: CGFloat
    ) -> CGFloat {
        let usableHeight = max(0, size.height - topInset - bottomInset)
        let clampedFraction = max(0.0, min(1.0, horizonYFraction))
        return topInset + CGFloat(clampedFraction) * usableHeight
    }
}
