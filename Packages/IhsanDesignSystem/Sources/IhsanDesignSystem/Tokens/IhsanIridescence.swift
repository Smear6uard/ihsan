import SwiftUI

/// Iridescent treatments for the manuscript aesthetic.
///
/// Real gold leaf on a manuscript page is iridescent: it shifts from
/// honey to brass to pale champagne as the angle of incident light
/// changes. The illuminated-panel borders and the gold star markers
/// reach for the same material quality by sampling the four-tone brass
/// palette (`brassHoney`, `brassMid`, `brassPale`, `brassDark`) around
/// their perimeters and inside their fill.
///
/// For v1 every gradient is static — the angular variation across the
/// perimeter already reads as "this is gold leaf, not a flat brass
/// rectangle" when the device tilts. A future iteration can layer in
/// CoreMotion-driven shimmer where performance permits; everything in
/// this file is shape-of-gradient only, so a motion overlay can be
/// added without changing the call sites.
public enum IhsanIridescence {

    // MARK: - Brass border stroke

    /// An `AngularGradient` cycling honey → mid → pale → dark → mid →
    /// honey around the perimeter of a shape's stroke. Applied to the
    /// brass illumination border on every illuminated panel.
    ///
    /// - Parameters:
    ///   - opacity: Multiplier applied to every stop so the same
    ///     gradient can fade in for inactive cards (~`0.55`) and snap
    ///     to full presence for the active prayer (`1.0`).
    ///   - angle: Rotation applied to the angular gradient's zero
    ///     position. Default `0°` puts honey at the top of the
    ///     perimeter. Threading an angle in lets a TimelineView
    ///     rotate the gradient slowly without rebuilding the stops.
    public static func brassStroke(
        opacity: Double = 1.0,
        angle: Angle = .zero
    ) -> AngularGradient {
        AngularGradient(
            stops: [
                .init(color: IhsanColor.brassHoney.opacity(opacity), location: 0.00),
                .init(color: IhsanColor.brassMid.opacity(opacity),   location: 0.18),
                .init(color: IhsanColor.brassPale.opacity(opacity),  location: 0.38),
                .init(color: IhsanColor.brassMid.opacity(opacity),   location: 0.58),
                .init(color: IhsanColor.brassDark.opacity(opacity),  location: 0.78),
                .init(color: IhsanColor.brassHoney.opacity(opacity), location: 1.00)
            ],
            center: .center,
            angle: angle
        )
    }

    // MARK: - Gold ornament radial fill

    /// A `RadialGradient` for small gold ornaments — the eight-pointed
    /// star current-prayer marker and the brass dots on status pills.
    /// Pale champagne at the centre fading through bright gold to
    /// honey at the rim, so the ornament reads as catching light from
    /// the top-left.
    public static func goldOrnament(
        opacity: Double = 1.0,
        center: UnitPoint = .topLeading
    ) -> RadialGradient {
        RadialGradient(
            stops: [
                .init(color: IhsanColor.brassPale.opacity(opacity),  location: 0.00),
                .init(color: IhsanColor.goldBright.opacity(opacity), location: 0.45),
                .init(color: IhsanColor.brassHoney.opacity(opacity), location: 0.85),
                .init(color: IhsanColor.brassDark.opacity(opacity),  location: 1.00)
            ],
            center: center,
            startRadius: 0,
            endRadius: 28
        )
    }
}
