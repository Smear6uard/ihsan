import SwiftUI

/// Full-screen atmospheric ground modifier. The deep ultramarine
/// `IhsanColor.ground` remains the anchor across every screen and every
/// time of day; on top of it we layer:
///
/// 1. A subtle vertical gradient (top half slightly darker, bottom half
///    slightly warmer) so the wall never reads as a flat painted surface.
/// 2. A radial wash of the adaptive time-of-day tint positioned high in
///    the frame, suggesting ambient light from above. The wash sits at
///    ~6–9% opacity — barely conscious, but the eye reads warmth at
///    midday and coolness at fajr.
/// 3. A second, very tight radial glow positioned where the hero card
///    sits — gives the screen a sense of luminous focus.
///
/// Reduce-Transparency users get just `IhsanColor.ground` so the screen
/// stays flat and high-contrast for them.
public struct AdaptiveBackground: ViewModifier {
    @Environment(\.timeOfDayOverride) private var override
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public func body(content: Content) -> some View {
        content
            .background {
                Group {
                    if reduceTransparency {
                        IhsanColor.ground
                    } else {
                        layeredGround
                    }
                }
                .ignoresSafeArea()
            }
    }

    private var layeredGround: some View {
        let date = override ?? .now
        let tint = IhsanColor.adaptiveTint(at: date)

        return ZStack {
            // 1. Anchor — the constant deep ultramarine that defines
            //    Ihsan's identity across every hour of every day.
            IhsanColor.ground

            // 2. Vertical atmosphere. Top sits in a slightly deeper
            //    indigo (closer to the void), bottom carries a few
            //    percent more warmth so the eye reads "horizon below,
            //    sky above" without being a literal landscape.
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.04, green: 0.06, blue: 0.12).opacity(0.55), location: 0.0),
                    .init(color: .clear, location: 0.45),
                    .init(color: Color(red: 0.10, green: 0.13, blue: 0.22).opacity(0.45), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // 3. Wide ambient tint wash. Centered slightly above the
            //    visual middle so the screen feels lit from above. The
            //    opacity is intentionally tiny — at midday it's a hint
            //    of honey, at fajr a hint of cool violet, never a
            //    coloured wash.
            RadialGradient(
                colors: [
                    tint.opacity(0.10),
                    tint.opacity(0.05),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 0,
                endRadius: 540
            )
            .blendMode(.plusLighter)

            // 4. Tight hero focus — a smaller, brighter pool around
            //    where the countdown card lives. Suggests light cast
            //    forward from the luminous card itself, settling on
            //    the rows below.
            RadialGradient(
                colors: [
                    tint.opacity(0.07),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.32),
                startRadius: 0,
                endRadius: 260
            )
            .blendMode(.plusLighter)
        }
    }
}

public extension View {
    /// Apply the standard Ihsan dark ground. Use once per screen at the root.
    func ihsanBackground() -> some View {
        modifier(AdaptiveBackground())
    }
}
