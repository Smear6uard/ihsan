import SwiftUI

/// A single day in the trajectory heatmap. Opacity ramps with completion:
/// fully missed days remain just-visible against the ground; perfect days
/// glow at the primary text tier.
public struct HeatmapDot: View {
    /// 0.0 = missed entirely / no data, 1.0 = all five prayers on time.
    public let completion: Double

    public init(completion: Double) {
        self.completion = max(0, min(1, completion))
    }

    public var body: some View {
        Circle()
            .fill(IhsanColor.textPrimary.opacity(0.15 + completion * 0.85))
            .frame(
                width: IhsanSpacing.heatmapDotSize,
                height: IhsanSpacing.heatmapDotSize
            )
            .accessibilityHidden(true)
    }
}

#Preview("Heatmap dot ramp") {
    HStack(spacing: IhsanSpacing.heatmapDotSpacing) {
        ForEach(0..<11, id: \.self) { i in
            HeatmapDot(completion: Double(i) / 10.0)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanBackground()
}
