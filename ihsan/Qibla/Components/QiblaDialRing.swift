import IhsanDesignSystem
import SwiftUI

/// The engraved degree ring — the rotating card of the instrument.
///
/// Pure engraving, no filled disc (flat + luminous): two hairline
/// circles hold the band, major ticks every 10°, minor every 2°, and
/// the four cardinals engraved in small caps that ride the card. The
/// tick field is stroked with a radial gradient — light falling into
/// the cuts, brighter where they meet the inner band and dimming
/// toward the rim — so the metal reads machined, not flat-stroked.
///
/// The view depends only on palette tokens; rotation is applied by
/// the parent as a transform, so this Canvas never redraws while the
/// user turns.
struct QiblaDialRing: View {
    let tokens: SkyPaletteTokens
    /// Cardinal engraving size in points — pre-scaled by the caller's
    /// Dynamic Type metric so the ring adapts with the inscriptions.
    var cardinalSize: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            drawHairlines(context: context, center: center, radius: radius)
            drawTicks(context: context, center: center, radius: radius)
            drawCardinals(context: context, center: center, radius: radius)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Band hairlines

    private func drawHairlines(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let outer = Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
        context.stroke(outer, with: .color(tokens.metal.opacity(0.38)), lineWidth: 0.75)

        let innerRadius = radius * 0.86
        let inner = Path(ellipseIn: CGRect(
            x: center.x - innerRadius, y: center.y - innerRadius,
            width: innerRadius * 2, height: innerRadius * 2
        ))
        context.stroke(inner, with: .color(tokens.metal.opacity(0.26)), lineWidth: 0.6)
    }

    // MARK: - Tick field

    private func drawTicks(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        var majors = Path()
        var minors = Path()

        for degrees in stride(from: 0, to: 360, by: 2) {
            let angle = (Double(degrees) - 90) * .pi / 180
            let isMajor = degrees % 10 == 0
            let outerEnd = radius * 0.985
            let innerEnd = radius * (isMajor ? 0.885 : 0.94)
            let from = CGPoint(
                x: center.x + cos(angle) * outerEnd,
                y: center.y + sin(angle) * outerEnd
            )
            let to = CGPoint(
                x: center.x + cos(angle) * innerEnd,
                y: center.y + sin(angle) * innerEnd
            )
            if isMajor {
                majors.move(to: from)
                majors.addLine(to: to)
            } else {
                minors.move(to: from)
                minors.addLine(to: to)
            }
        }

        // The machined sheen: engravings catch more light toward the
        // inner band, dimming toward the rim.
        let sheen = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                tokens.metalHighlight.opacity(0.92),
                tokens.metal.opacity(0.50),
            ]),
            center: center,
            startRadius: radius * 0.86,
            endRadius: radius
        )
        context.stroke(majors, with: sheen, lineWidth: 1.2)
        context.stroke(minors, with: .color(tokens.metal.opacity(0.42)), lineWidth: 0.65)
    }

    // MARK: - Cardinals

    private func drawCardinals(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let cardinals: [(label: String, degrees: Double)] = [
            ("N", 0), ("E", 90), ("S", 180), ("W", 270),
        ]
        for cardinal in cardinals {
            let color = cardinal.label == "N"
                ? tokens.metalHighlight.opacity(0.95)
                : tokens.metal.opacity(0.78)
            let text = Text(cardinal.label)
                .font(.system(size: cardinalSize, weight: .semibold, design: .serif).smallCaps())
                .foregroundStyle(color)

            context.drawLayer { layer in
                layer.translateBy(x: center.x, y: center.y)
                layer.rotate(by: .degrees(cardinal.degrees))
                layer.draw(layer.resolve(text), at: CGPoint(x: 0, y: -radius * 0.755))
            }
        }
    }
}
