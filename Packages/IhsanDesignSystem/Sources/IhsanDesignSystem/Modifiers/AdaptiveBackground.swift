import SwiftUI

/// Full-screen dark ground modifier. The ground is constant across every
/// screen at every time of day — there is NO time-of-day background color
/// shift in Ihsan. Time of day is expressed only through how the glass
/// surfaces refract light.
public struct AdaptiveBackground: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background {
                IhsanColor.ground
                    .ignoresSafeArea()
            }
    }
}

public extension View {
    /// Apply the standard Ihsan dark ground. Use once per screen at the root.
    func ihsanBackground() -> some View {
        modifier(AdaptiveBackground())
    }
}
