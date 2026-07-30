import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The single quiet guidance slot beneath the inscriptions. At most
/// one line ever shows: compass calibration outranks posture. Nothing
/// modal, nothing that scolds — the line appears, helps, and leaves.
struct QiblaGuidanceLine: View {
    enum Guidance {
        case calibrate
        case holdFlat
    }

    let tokens: SkyPaletteTokens
    let guidance: Guidance
    let typeScale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 9) {
            if guidance == .calibrate {
                figureEight
            }
            Text(text)
                .font(QiblaType.inscription(typeScale))
                .tracking(1.8)
                .foregroundStyle(tokens.inkSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
    }

    private var text: String {
        switch guidance {
        case .calibrate: "MOVE IN A FIGURE EIGHT TO CALIBRATE"
        case .holdFlat: "HOLD FLAT"
        }
    }

    private var spokenText: String {
        switch guidance {
        case .calibrate: "Compass needs calibration. Move your phone in a figure eight."
        case .holdFlat: "Hold your phone flat."
        }
    }

    /// A small brass filament tracing the calibration gesture — a
    /// short luminous segment traveling the lemniscate. Under Reduce
    /// Motion the full figure renders as a static diagram.
    @ViewBuilder
    private var figureEight: some View {
        if reduceMotion {
            LemniscateShape()
                .stroke(tokens.metal.opacity(0.65), lineWidth: 1.2)
                .frame(width: 56, height: 24)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let cycle = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 2.4) / 2.4
                ZStack {
                    LemniscateShape()
                        .stroke(tokens.metal.opacity(0.28), lineWidth: 1)
                    LemniscateShape()
                        .trim(
                            from: cycle,
                            to: min(cycle + 0.22, 1)
                        )
                        .stroke(
                            tokens.metalHighlight.opacity(0.95),
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                        )
                    // Wrap the traveling segment across the seam so
                    // the trace never blinks at the loop point.
                    if cycle + 0.22 > 1 {
                        LemniscateShape()
                            .trim(from: 0, to: cycle + 0.22 - 1)
                            .stroke(
                                tokens.metalHighlight.opacity(0.95),
                                style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                            )
                    }
                }
                .frame(width: 56, height: 24)
            }
        }
    }
}

/// Gerono lemniscate — the figure-eight, drawn as one continuous
/// path (a filament, per the house rule: never dashed).
struct LemniscateShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 96
        for i in 0...steps {
            let t = Double(i) / Double(steps) * 2 * .pi
            let x = rect.midX + rect.width / 2 * CGFloat(sin(t))
            let y = rect.midY + rect.height / 2 * CGFloat(sin(t) * cos(t))
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

/// The qibla surfaces scale their engravings with Dynamic Type. The
/// base sizes are the design system's inscription tokens (13 pt /
/// 15 pt); the multiplier arrives from `@ScaledMetric` at the call
/// site so the whole instrument grows together through accessibility
/// sizes.
enum QiblaType {
    static func inscription(_ scale: CGFloat) -> Font {
        .system(size: 13 * scale, weight: .semibold).smallCaps()
    }

    static func inscriptionLarge(_ scale: CGFloat) -> Font {
        .system(size: 15 * scale, weight: .semibold).smallCaps()
    }
}
