import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The Repair signature: a fine metal filament that grows toward a terminal
/// ornament as prayers are made up. The grown portion is a filled tapered
/// lens (the design system's filament idiom — filled, never stroked); the
/// remainder is the faint dashed guide. The eye reads growth, not deficit.
struct RepairThreadView: View {
    /// Fraction of the whole repair that is complete, 0...1.
    let progress: Double
    let tokens: SkyPaletteTokens
    var terminalSize: CGFloat = 20

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let midY = geometry.size.height / 2
            let startX: CGFloat = 2
            let endX = width - terminalSize - IhsanSpacing.sm
            let clamped = min(1, max(0, progress))
            let grownEnd = startX + (endX - startX) * clamped

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: startX, y: midY))
                    path.addLine(to: CGPoint(x: endX, y: midY))
                }
                .stroke(
                    tokens.metal.opacity(0.22),
                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [1, 5])
                )

                if clamped > 0 {
                    RepairFilamentLens(endX: grownEnd, startX: startX)
                        .fill(tokens.metal.opacity(0.85))
                        .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: clamped)
                }

                PrayerMarkerOrnament(
                    prayer: .maghrib,
                    size: terminalSize,
                    state: clamped >= 1 ? .logged : .upcoming,
                    tokens: tokens
                )
                .position(x: endX + terminalSize / 2 + IhsanSpacing.sm / 2, y: midY)
            }
        }
        .frame(height: max(28, terminalSize + 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Repair thread, \(Int((min(1, max(0, progress)) * 100).rounded())) percent made up")
    }
}

/// The grown portion of the thread: a lens between two quad curves whose
/// ends taper to points, per the plate filament convention.
private struct RepairFilamentLens: Shape {
    var endX: CGFloat
    let startX: CGFloat
    var thickness: CGFloat = 1.8

    var animatableData: CGFloat {
        get { endX }
        set { endX = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let midY = rect.midY
        var path = Path()
        guard endX - startX > 1 else {
            return path
        }

        let midX = (startX + endX) / 2
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
