import SwiftUI

/// Time-adaptive sky gradient. Renders a vertical `LinearGradient` from
/// `IhsanColor.skyTopColor(at:)` at the very top to
/// `IhsanColor.skyBottomColor(at:)` at the very bottom.
///
/// The two endpoint colours are designed to shift through the day in
/// lockstep — at midday the top sits in pale neutral cream while the
/// bottom warms to honey, at maghrib the top is deep rose-magenta while
/// the bottom catches gold at the horizon. The gradient does the heavy
/// atmospheric lifting; cards float on top in the warm card material.
///
/// The view re-renders on a 60 s cadence so the colour drifts visibly
/// across the day without ever animating fast enough to read as motion.
/// Reduce-motion users get a single static evaluation at first render
/// and the wall clock is consulted only when no `\.timeOfDayOverride` is
/// present.
public struct IhsanSkyGradient: View {
    @Environment(\.timeOfDayOverride) private var override
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        if let override {
            gradient(at: override)
        } else if reduceMotion {
            gradient(at: .now)
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                gradient(at: context.date)
            }
        }
    }

    @ViewBuilder
    private func gradient(at date: Date) -> some View {
        let top = IhsanColor.skyTopColor(at: date)
        let bottom = IhsanColor.skyBottomColor(at: date)

        // The horizon band sits at ~78% so the lower 22% is the warm
        // pole of the gradient — gives prayer rows a warm layer to
        // float above without smearing the warm across the whole screen.
        LinearGradient(
            stops: [
                .init(color: top, location: 0.0),
                .init(color: bottom, location: 0.78),
                .init(color: bottom, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
