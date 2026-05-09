import SwiftUI

/// Intensity tier for the Ihsan Liquid Glass treatment.
///
/// Maps to a tint opacity. iOS 26's `Glass` only exposes a single
/// `.regular` material; we add our own intensity scale by varying
/// how strongly the adaptive time-of-day tint colors the glass.
public enum GlassIntensity: Sendable {
    /// Settings rows, list items, secondary surfaces.
    case subtle
    /// Prayer rows, content cards — the default.
    case regular
    /// The countdown card and other primary surfaces. More tint, more presence.
    case hero

    var tintOpacity: Double {
        switch self {
        case .subtle: return 0.10
        case .regular: return 0.16
        case .hero: return 0.26
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
    /// `\.timeOfDayOverride` environment value when set).
    ///
    /// - Parameters:
    ///   - shape: Clipping shape for the glass surface.
    ///   - intensity: Tier that scales the tint contribution.
    func ihsanGlass<S: Shape>(
        in shape: S,
        intensity: GlassIntensity = .regular
    ) -> some View {
        modifier(IhsanGlassModifier(shape: shape, intensity: intensity))
    }

    /// Default rounded-rectangle variant. Swift can't default a generic
    /// shape parameter cleanly across all call sites, so we provide a
    /// no-shape overload that uses the standard card radius.
    func ihsanGlass(
        intensity: GlassIntensity = .regular
    ) -> some View {
        ihsanGlass(
            in: RoundedRectangle(
                cornerRadius: IhsanSpacing.cardRadius,
                style: .continuous
            ),
            intensity: intensity
        )
    }

    /// Hero variant — used for the countdown card and other primary surfaces.
    /// Slightly more pronounced specular and tint.
    func ihsanGlassHero() -> some View {
        ihsanGlass(intensity: .hero)
    }
}

internal struct IhsanGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let intensity: GlassIntensity
    @Environment(\.timeOfDayOverride) private var override

    func body(content: Content) -> some View {
        let date = override ?? .now
        let tint = IhsanColor.adaptiveTint(at: date)
            .opacity(intensity.tintOpacity)
        // iOS 26 native Liquid Glass. The tint color is what gives the
        // surface its iridescent, time-of-day quality. The ground beneath
        // remains constant; only the glass picks up the hour.
        return content.glassEffect(
            .regular.tint(tint),
            in: shape
        )
    }
}
