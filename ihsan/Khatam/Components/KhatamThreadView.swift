import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// A fine metal filament growing toward its own eight-point terminal.
/// VoiceOver receives units, never a percentage headline.
struct KhatamThreadView: View {
    let read: Int
    let target: Int
    let unit: KhatamUnit
    let tokens: SkyPaletteTokens
    var terminalSize: CGFloat = 20

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, max(0, Double(read) / Double(target)))
    }

    var body: some View {
        GeometryReader { geometry in
            let midY = geometry.size.height / 2
            let startX: CGFloat = 2
            let endX = geometry.size.width - terminalSize - IhsanSpacing.sm
            let grownEnd = startX + (endX - startX) * progress

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: startX, y: midY))
                    path.addLine(to: CGPoint(x: endX, y: midY))
                }
                .stroke(
                    tokens.metal.opacity(0.22),
                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [1, 5])
                )

                if progress > 0 {
                    KhatamFilament(endX: grownEnd, startX: startX)
                        .fill(tokens.inkSecondary)
                        .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: progress)
                }

                ZStack {
                    EightPointedStar()
                        .fill(progress >= 1 ? tokens.leafGold : tokens.panelFill)
                    EightPointedStar()
                        .stroke(tokens.inkSecondary, lineWidth: 1)
                    FourPointedStar(innerRatio: 0.38)
                        .fill(tokens.keyline.opacity(progress >= 1 ? 0.75 : 0.28))
                        .padding(terminalSize * 0.28)
                }
                .frame(width: terminalSize, height: terminalSize)
                .position(
                    x: endX + terminalSize / 2 + IhsanSpacing.sm / 2,
                    y: midY
                )
            }
        }
        .frame(height: max(28, terminalSize + 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Khatam thread, \(min(read, target)) of \(target) \(target == 1 ? unit.singularLabel : unit.pluralLabel) read"
        )
    }
}

private struct KhatamFilament: Shape {
    var endX: CGFloat
    let startX: CGFloat
    var thickness: CGFloat = 1.8

    var animatableData: CGFloat {
        get { endX }
        set { endX = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard endX - startX > 1 else { return Path() }
        let midY = rect.midY
        let midX = (startX + endX) / 2
        var path = Path()
        path.move(to: CGPoint(x: startX, y: midY))
        path.addQuadCurve(
            to: CGPoint(x: endX, y: midY),
            control: CGPoint(x: midX, y: midY - thickness)
        )
        path.addQuadCurve(
            to: CGPoint(x: startX, y: midY),
            control: CGPoint(x: midX, y: midY + thickness)
        )
        path.closeSubpath()
        return path
    }
}
