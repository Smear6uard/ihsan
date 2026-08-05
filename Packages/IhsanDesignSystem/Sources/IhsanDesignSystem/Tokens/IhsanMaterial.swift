import SwiftUI

/// Intensity tier for the Ihsan Liquid Glass treatment.
///
/// Maps to a tint opacity and a small bundle of decorative-layer
/// opacities. iOS 26's `Glass` material is uniform; we layer a thin
/// specular edge stroke and a top-down iridescent wash on top so the
/// surface reads as a translucent material across every time of day,
/// even when the ground behind it is uniform.
public enum GlassIntensity: Sendable {
    /// Settings rows, list items, secondary surfaces.
    case subtle
    /// Prayer rows, content cards — the default.
    case regular
    /// The countdown card and other primary surfaces. More tint, more presence.
    case hero

    /// Tint colour mixed into the base `.regular` glass.
    var tintOpacity: Double {
        switch self {
        case .subtle: return 0.18
        case .regular: return 0.30
        case .hero: return 0.46
        }
    }

    /// Strength of the top-down iridescent gradient that gives the surface
    /// a sense of internal depth.
    var sheenOpacity: Double {
        switch self {
        case .subtle: return 0.08
        case .regular: return 0.16
        case .hero: return 0.26
        }
    }

    /// Strength of the thin specular edge stroke.
    var edgeHighlightOpacity: Double {
        switch self {
        case .subtle: return 0.16
        case .regular: return 0.28
        case .hero: return 0.42
        }
    }

    /// Lower edge shadow opacity. Suggests the material catching ambient
    /// light only from above, never below — keeps the glass from looking
    /// like a flat outlined rectangle.
    var bottomShadeOpacity: Double {
        switch self {
        case .subtle: return 0.06
        case .regular: return 0.10
        case .hero: return 0.16
        }
    }
}

// MARK: - Time-of-day override (for previews)
//
// The IhsanGlassModifier reads this environment value when present and
// falls back to `Date.now` otherwise. Previews can use it to show a
// component at a specific hour without clock-mocking.

private struct TimeOfDayOverrideKey: EnvironmentKey {
    static let defaultValue: Date? = nil
}

public extension EnvironmentValues {
    /// Optional Date used by `.ihsanGlass(...)` to compute the adaptive tint.
    /// When `nil`, the modifier uses `Date.now`.
    var timeOfDayOverride: Date? {
        get { self[TimeOfDayOverrideKey.self] }
        set { self[TimeOfDayOverrideKey.self] = newValue }
    }
}

// MARK: - .ihsanGlass modifier

public extension View {
    /// Apply the standard Ihsan Liquid Glass effect with the adaptive
    /// time-of-day tint.
    ///
    /// Uses iOS 26's native `glassEffect(_:in:)` with `Glass.regular.tint(_:)`,
    /// where the tint is computed from the current `Date` (or the
    /// `\.timeOfDayOverride` environment value when set). On top of the
    /// system material we layer a thin specular edge and a top-down
    /// iridescent sheen so the surface reads as a translucent material
    /// even when the ground behind it is uniform.
    ///
    /// - Parameters:
    ///   - shape: Clipping shape for the glass surface.
    ///   - intensity: Tier that scales the tint contribution.
    ///   - isActive: Adds a luminous tinted ring and inner radial glow
    ///     to mark this as the "current prayer" surface.
    ///   - isClear: Uses the neutral clear Liquid Glass character while
    ///     retaining Ihsan's edge and active-state treatments.
    func ihsanGlass<S: InsettableShape>(
        in shape: S,
        intensity: GlassIntensity = .regular,
        isActive: Bool = false,
        isInteractive: Bool = false,
        isClear: Bool = false
    ) -> some View {
        modifier(
            IhsanGlassModifier(
                shape: shape,
                intensity: intensity,
                isActive: isActive,
                isInteractive: isInteractive,
                isClear: isClear
            )
        )
    }

    /// Default rounded-rectangle variant. Swift can't default a generic
    /// shape parameter cleanly across all call sites, so we provide a
    /// no-shape overload that uses the standard card radius.
    func ihsanGlass(
        intensity: GlassIntensity = .regular,
        isActive: Bool = false,
        isInteractive: Bool = false,
        isClear: Bool = false
    ) -> some View {
        ihsanGlass(
            in: RoundedRectangle(
                cornerRadius: IhsanSpacing.cardRadius,
                style: .continuous
            ),
            intensity: intensity,
            isActive: isActive,
            isInteractive: isInteractive,
            isClear: isClear
        )
    }

    /// Hero variant — used for the countdown card and other primary surfaces.
    /// Slightly more pronounced specular and tint.
    func ihsanGlassHero() -> some View {
        ihsanGlass(intensity: .hero)
    }
}

internal struct IhsanGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let intensity: GlassIntensity
    let isActive: Bool
    let isInteractive: Bool
    let isClear: Bool
    @Environment(\.timeOfDayOverride) private var override
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let date = override ?? .now
        let baseTint = IhsanColor.adaptiveTint(at: date)
        let glassTint = baseTint.opacity(intensity.tintOpacity)

        content
            .modifier(
                IhsanGlassBaseLayer(
                    shape: shape,
                    glassTint: glassTint,
                    baseTint: baseTint,
                    intensity: intensity,
                    isActive: isActive,
                    isInteractive: isInteractive,
                    isClear: isClear,
                    reduceTransparency: reduceTransparency
                )
            )
    }
}

/// Splits the layer composition out so the type-checker doesn't have to
/// reason about a deeply nested `.overlay { if ... else ... }` chain inside
/// the ViewModifier's `body`.
private struct IhsanGlassBaseLayer<S: InsettableShape>: ViewModifier {
    let shape: S
    let glassTint: Color
    let baseTint: Color
    let intensity: GlassIntensity
    let isActive: Bool
    let isInteractive: Bool
    let isClear: Bool
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background {
                    shape
                        .fill(IhsanColor.ground)
                        .overlay { shape.fill(baseTint.opacity(0.22)) }
                        .overlay {
                            shape.strokeBorder(
                                baseTint.opacity(isActive ? 0.55 : 0.30),
                                lineWidth: isActive ? 1.0 : 0.6
                            )
                        }
                }
        } else {
            let glass = isClear
                ? Glass.clear.interactive(isInteractive)
                : Glass.regular.tint(glassTint).interactive(isInteractive)
            content
                // iOS 26 native Liquid Glass. The tint passed in here is
                // what gives the surface its iridescent, time-of-day
                // quality — the ground beneath stays constant.
                .glassEffect(
                    glass,
                    in: shape
                )
                // Inner radial glow — only present on the active prayer
                // card. Renders BEFORE the sheen so the sheen's edge
                // shadow still reads.
                .overlay {
                    if isActive {
                        shape
                            .fill(
                                RadialGradient(
                                    colors: [
                                        baseTint.opacity(0.22),
                                        baseTint.opacity(0.08),
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 220
                                )
                            )
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                    }
                }
                // Top-down iridescent sheen. The top half picks up the
                // tint as a faint warm/cool wash; the bottom edge sits in
                // a subtle shadow so the card reads as a 3-D surface
                // catching light from above.
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(intensity.sheenOpacity * 0.9), location: 0.0),
                                    .init(color: baseTint.opacity(intensity.sheenOpacity), location: 0.35),
                                    .init(color: .clear, location: 0.65),
                                    .init(color: .black.opacity(intensity.bottomShadeOpacity), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }
                // Specular edge — a thin gradient stroke that catches the
                // tint at the top-left and dissolves to nothing at the
                // bottom-right. This single detail is what reads as
                // "glass" rather than "tinted rectangle" on device.
                .overlay {
                    shape
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(intensity.edgeHighlightOpacity), location: 0.0),
                                    .init(color: baseTint.opacity(intensity.edgeHighlightOpacity * 0.6), location: 0.4),
                                    .init(color: .white.opacity(0.04), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }
                // Active ring — only on the current-prayer card. Drawn
                // last so it sits above the sheen.
                .overlay {
                    if isActive {
                        shape
                            .strokeBorder(baseTint.opacity(0.55), lineWidth: 1.0)
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}
