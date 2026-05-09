import SwiftUI

/// 1pt atmospheric divider at 20% white. The quietest possible separator —
/// reads as a hairline against the dark ground without ever drawing
/// attention to itself.
public struct HairlineDivider: View {
    public let orientation: Axis

    public init(_ orientation: Axis = .horizontal) {
        self.orientation = orientation
    }

    public var body: some View {
        Rectangle()
            .fill(IhsanColor.atmospheric)
            .frame(
                width: orientation == .vertical ? IhsanSpacing.hairline : nil,
                height: orientation == .horizontal ? IhsanSpacing.hairline : nil
            )
            .accessibilityHidden(true)
    }
}
