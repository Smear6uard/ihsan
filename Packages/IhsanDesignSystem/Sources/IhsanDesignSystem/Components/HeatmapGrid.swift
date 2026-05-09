import SwiftUI

/// 30 / 90 / 365-day grid of `HeatmapDot`s. The values array is ordered
/// oldest first; missing tail slots in the last row render as transparent
/// placeholders so the grid stays rectangular without padding the data.
public struct HeatmapGrid: View {
    public let values: [Double]
    public let columns: Int

    public init(values: [Double], columns: Int = 7) {
        self.values = values
        self.columns = columns
    }

    public var body: some View {
        let rows = (values.count + columns - 1) / columns
        VStack(spacing: IhsanSpacing.heatmapDotSpacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: IhsanSpacing.heatmapDotSpacing) {
                    ForEach(0..<columns, id: \.self) { col in
                        let idx = row * columns + col
                        if idx < values.count {
                            HeatmapDot(completion: values[idx])
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(
                                    width: IhsanSpacing.heatmapDotSize,
                                    height: IhsanSpacing.heatmapDotSize
                                )
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard !values.isEmpty else {
            return "Heatmap, no data"
        }
        let avg = values.reduce(0, +) / Double(values.count)
        let pct = Int((avg * 100).rounded())
        return "Heatmap of \(values.count) days, average completion \(pct) percent"
    }
}

#Preview("Heatmap grid — 30 days") {
    let sample = (0..<30).map { i in
        Double((i * 17) % 100) / 100.0
    }
    HeatmapGrid(values: sample, columns: 7)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ihsanBackground()
}
