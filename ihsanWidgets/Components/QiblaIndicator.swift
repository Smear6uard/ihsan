import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// Compass-style qibla indicator for the corner of the large widget.
///
/// A small circular dial with a hairline tick at every 45° and a thin
/// brass arrow pointing to the qibla. Static — does not rotate with
/// device heading (widgets do not have access to the magnetometer).
/// The label "QIBLA" sits below the dial in small caps.
struct QiblaIndicator: View {
    let bearingDegrees: Double
    let size: CGFloat

    init(bearingDegrees: Double, size: CGFloat = 38) {
        self.bearingDegrees = bearingDegrees
        self.size = size
    }

    var body: some View {
        VStack(spacing: IhsanSpacing.xxs) {
            ZStack {
                // Atmospheric ring
                Circle()
                    .strokeBorder(IhsanColor.atmospheric, lineWidth: 0.75)

                // 45° ticks
                ForEach(0..<8, id: \.self) { i in
                    Rectangle()
                        .fill(IhsanColor.atmospheric)
                        .frame(width: 0.75, height: i % 2 == 0 ? 4 : 2)
                        .offset(y: -size / 2 + 2)
                        .rotationEffect(.degrees(Double(i) * 45))
                }

                // Brass arrow pointing to qibla
                ZStack {
                    Triangle()
                        .fill(IhsanColor.statusQada)
                        .frame(width: 5, height: size * 0.42)
                        .offset(y: -size * 0.18)
                    Circle()
                        .fill(IhsanColor.statusQada)
                        .frame(width: 3, height: 3)
                }
                .rotationEffect(.degrees(bearingDegrees))
            }
            .frame(width: size, height: size)

            Text("QIBLA")
                .font(.system(size: 8, weight: .semibold, design: .default).smallCaps())
                .tracking(1.2)
                .foregroundStyle(IhsanColor.textMuted)
        }
        .accessibilityLabel("Qibla direction \(Int(bearingDegrees.rounded())) degrees")
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
