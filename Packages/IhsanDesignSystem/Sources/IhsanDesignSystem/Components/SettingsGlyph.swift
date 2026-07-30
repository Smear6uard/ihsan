import SwiftUI

/// The Set screen's iconography: fine custom linework glyphs in the
/// engraved style — small, quiet, one consistent stroke weight.
/// Every row names its meaning through one of these forms; generic
/// SF Symbols never appear in the page's content, and the five
/// prayer ornaments are RESERVED for prayers — none of these shapes
/// quotes them.
public enum SettingsGlyph: Sendable {
    /// Compass rose — location.
    case location
    /// Astrolabe quadrant — calculation method.
    case method
    /// Gnomon and its shadow — the Asr method.
    case asrShadow
    /// A low sun over the horizon — high-latitude rule.
    case highLatitude
    /// A small radiant sun — the forenoon (duha) window.
    case sun
    /// Sound arcs from a point — adhan and notifications.
    case adhan
    /// A clock face — times and schedules.
    case clock
    /// A hanging calendar leaf — dates.
    case calendar
    /// The excused-pause droplet.
    case pause
    /// The engraved travel plane.
    case travel
    /// Two paths joining — jam (combining prayers).
    case jam
    /// Two arrows drawing inward — qasr (shortening).
    case qasr
    /// Ledger rules with a returning hook — the makeup ledger.
    case makeupLedger
    /// A thin crescent — night prayer.
    case nightMoon
    /// A fard dot orbited by its rawatib.
    case rawatib
    /// Plus and minus — counts.
    case counts
    /// Voice bars — audio memos.
    case voiceWaves
    /// A cloud outline — sync.
    case sync
    /// A shield outline — privacy.
    case privacy
    /// A leaf leaving the page — share / export.
    case share
    /// A lamp of information — about.
    case info
    /// A heart outline — acknowledgements.
    case heart
    /// An open book — guides and texts.
    case book
    /// A small bin — remove.
    case remove
}

/// Renders a `SettingsGlyph` as engraved linework in the given color.
/// One stroke weight for the whole family; the travel plane is the
/// single filled silhouette (it is a mark, not a diagram).
public struct SettingsGlyphView: View {
    public let glyph: SettingsGlyph
    public let color: Color
    public var lineWidth: CGFloat = 1.1

    public init(_ glyph: SettingsGlyph, color: Color, lineWidth: CGFloat = 1.1) {
        self.glyph = glyph
        self.color = color
        self.lineWidth = lineWidth
    }

    public var body: some View {
        Group {
            if glyph == .travel {
                SettingsGlyphShape(glyph: .travel)
                    .fill(color)
            } else {
                SettingsGlyphShape(glyph: glyph)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .accessibilityHidden(true)
    }
}

/// The paths themselves, drawn in the unit rect.
public struct SettingsGlyphShape: Shape {
    public let glyph: SettingsGlyph

    public init(glyph: SettingsGlyph) {
        self.glyph = glyph
    }

    public func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        var p = Path()

        switch glyph {
        case .location:
            p.addEllipse(in: CGRect(x: rect.minX + 0.08 * w, y: rect.minY + 0.08 * h, width: 0.84 * w, height: 0.84 * h))
            p.move(to: pt(0.5, 0.22))
            p.addLine(to: pt(0.63, 0.5))
            p.addLine(to: pt(0.5, 0.78))
            p.addLine(to: pt(0.37, 0.5))
            p.closeSubpath()

        case .method:
            // Quadrant arc anchored at the lower-left, one radius, and
            // the sighting hole.
            p.move(to: pt(0.15, 0.25))
            p.addArc(
                center: pt(0.15, 0.85),
                radius: 0.6 * min(w, h),
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            p.move(to: pt(0.15, 0.85))
            p.addLine(to: pt(0.57, 0.43))
            p.addEllipse(in: CGRect(x: rect.minX + 0.58 * w, y: rect.minY + 0.30 * h, width: 0.12 * w, height: 0.12 * h))

        case .asrShadow:
            p.move(to: pt(0.12, 0.80))
            p.addLine(to: pt(0.88, 0.80))
            p.move(to: pt(0.34, 0.80))
            p.addLine(to: pt(0.34, 0.30))
            p.move(to: pt(0.34, 0.30))
            p.addLine(to: pt(0.74, 0.80))

        case .highLatitude:
            p.move(to: pt(0.10, 0.66))
            p.addLine(to: pt(0.90, 0.66))
            p.move(to: pt(0.24, 0.66))
            p.addQuadCurve(to: pt(0.76, 0.66), control: pt(0.5, 0.34))
            p.move(to: pt(0.5, 0.20))
            p.addLine(to: pt(0.5, 0.10))

        case .sun:
            p.addEllipse(in: CGRect(x: rect.minX + 0.32 * w, y: rect.minY + 0.32 * h, width: 0.36 * w, height: 0.36 * h))
            for angle in stride(from: 0.0, to: 360.0, by: 45.0) {
                let r1 = 0.28, r2 = 0.42
                let rad = angle * .pi / 180
                p.move(to: pt(0.5 + r1 * cos(rad), 0.5 + r1 * sin(rad)))
                p.addLine(to: pt(0.5 + r2 * cos(rad), 0.5 + r2 * sin(rad)))
            }

        case .adhan:
            for radius in [0.22, 0.42, 0.62] {
                p.move(to: pt(0.18 + radius * 0.766, 0.82 - radius * 0.643))
                p.addArc(
                    center: pt(0.18, 0.82),
                    radius: radius * min(w, h),
                    startAngle: .degrees(-40),
                    endAngle: .degrees(-5),
                    clockwise: false
                )
            }
            p.addEllipse(in: CGRect(x: rect.minX + 0.13 * w, y: rect.minY + 0.77 * h, width: 0.1 * w, height: 0.1 * h))

        case .clock:
            p.addEllipse(in: CGRect(x: rect.minX + 0.1 * w, y: rect.minY + 0.1 * h, width: 0.8 * w, height: 0.8 * h))
            p.move(to: pt(0.5, 0.5))
            p.addLine(to: pt(0.5, 0.26))
            p.move(to: pt(0.5, 0.5))
            p.addLine(to: pt(0.68, 0.58))

        case .calendar:
            p.addRoundedRect(
                in: CGRect(x: rect.minX + 0.14 * w, y: rect.minY + 0.2 * h, width: 0.72 * w, height: 0.64 * h),
                cornerSize: CGSize(width: 0.06 * w, height: 0.06 * h)
            )
            p.move(to: pt(0.14, 0.38))
            p.addLine(to: pt(0.86, 0.38))
            p.move(to: pt(0.34, 0.12))
            p.addLine(to: pt(0.34, 0.26))
            p.move(to: pt(0.66, 0.12))
            p.addLine(to: pt(0.66, 0.26))

        case .pause:
            p.move(to: pt(0.5, 0.10))
            p.addCurve(to: pt(0.74, 0.62), control1: pt(0.60, 0.28), control2: pt(0.74, 0.44))
            p.addArc(
                center: pt(0.5, 0.62),
                radius: 0.24 * min(w, h),
                startAngle: .degrees(0),
                endAngle: .degrees(180),
                clockwise: false
            )
            p.addCurve(to: pt(0.5, 0.10), control1: pt(0.26, 0.44), control2: pt(0.40, 0.28))
            p.closeSubpath()

        case .travel:
            p.move(to: pt(0.95, 0.50))
            p.addLine(to: pt(0.55, 0.38))
            p.addLine(to: pt(0.28, 0.08))
            p.addLine(to: pt(0.20, 0.12))
            p.addLine(to: pt(0.38, 0.42))
            p.addLine(to: pt(0.12, 0.36))
            p.addLine(to: pt(0.05, 0.42))
            p.addLine(to: pt(0.22, 0.50))
            p.addLine(to: pt(0.05, 0.58))
            p.addLine(to: pt(0.12, 0.64))
            p.addLine(to: pt(0.38, 0.58))
            p.addLine(to: pt(0.20, 0.88))
            p.addLine(to: pt(0.28, 0.92))
            p.addLine(to: pt(0.55, 0.62))
            p.closeSubpath()

        case .jam:
            p.move(to: pt(0.22, 0.15))
            p.addLine(to: pt(0.5, 0.5))
            p.move(to: pt(0.78, 0.15))
            p.addLine(to: pt(0.5, 0.5))
            p.move(to: pt(0.5, 0.5))
            p.addLine(to: pt(0.5, 0.85))

        case .qasr:
            p.move(to: pt(0.10, 0.5))
            p.addLine(to: pt(0.42, 0.5))
            p.move(to: pt(0.34, 0.42))
            p.addLine(to: pt(0.42, 0.5))
            p.addLine(to: pt(0.34, 0.58))
            p.move(to: pt(0.90, 0.5))
            p.addLine(to: pt(0.58, 0.5))
            p.move(to: pt(0.66, 0.42))
            p.addLine(to: pt(0.58, 0.5))
            p.addLine(to: pt(0.66, 0.58))

        case .makeupLedger:
            for y in [0.30, 0.52, 0.74] {
                p.move(to: pt(0.20, y))
                p.addLine(to: pt(0.80, y))
            }
            p.move(to: pt(0.34, 0.18))
            p.addLine(to: pt(0.20, 0.30))
            p.addLine(to: pt(0.34, 0.42))

        case .nightMoon:
            p.move(to: pt(0.62, 0.10))
            p.addArc(
                center: pt(0.5, 0.5),
                radius: 0.42 * min(w, h),
                startAngle: .degrees(-73),
                endAngle: .degrees(107),
                clockwise: false
            )
            p.addArc(
                center: pt(0.66, 0.42),
                radius: 0.34 * min(w, h),
                startAngle: .degrees(122),
                endAngle: .degrees(-92),
                clockwise: true
            )
            p.closeSubpath()

        case .rawatib:
            p.addEllipse(in: CGRect(x: rect.minX + 0.42 * w, y: rect.minY + 0.42 * h, width: 0.16 * w, height: 0.16 * h))
            for (x, y) in [(0.5, 0.14), (0.86, 0.5), (0.5, 0.86), (0.14, 0.5)] {
                p.addEllipse(in: CGRect(
                    x: rect.minX + (x - 0.05) * w,
                    y: rect.minY + (y - 0.05) * h,
                    width: 0.10 * w,
                    height: 0.10 * h
                ))
            }

        case .counts:
            p.move(to: pt(0.16, 0.35))
            p.addLine(to: pt(0.44, 0.35))
            p.move(to: pt(0.30, 0.21))
            p.addLine(to: pt(0.30, 0.49))
            p.move(to: pt(0.56, 0.68))
            p.addLine(to: pt(0.84, 0.68))

        case .voiceWaves:
            for (x, top, bottom) in [(0.2, 0.42, 0.58), (0.35, 0.30, 0.70), (0.5, 0.18, 0.82), (0.65, 0.34, 0.66), (0.8, 0.44, 0.56)] {
                p.move(to: pt(x, top))
                p.addLine(to: pt(x, bottom))
            }

        case .sync:
            p.move(to: pt(0.24, 0.68))
            p.addArc(center: pt(0.34, 0.68), radius: 0.10 * min(w, h), startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.addArc(center: pt(0.52, 0.60), radius: 0.16 * min(w, h), startAngle: .degrees(215), endAngle: .degrees(330), clockwise: false)
            p.addArc(center: pt(0.70, 0.68), radius: 0.10 * min(w, h), startAngle: .degrees(280), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: pt(0.24, 0.78))
            p.closeSubpath()

        case .privacy:
            p.move(to: pt(0.5, 0.10))
            p.addLine(to: pt(0.82, 0.24))
            p.addCurve(to: pt(0.5, 0.90), control1: pt(0.82, 0.58), control2: pt(0.70, 0.78))
            p.addCurve(to: pt(0.18, 0.24), control1: pt(0.30, 0.78), control2: pt(0.18, 0.58))
            p.closeSubpath()

        case .share:
            p.move(to: pt(0.30, 0.42))
            p.addLine(to: pt(0.20, 0.42))
            p.addLine(to: pt(0.20, 0.86))
            p.addLine(to: pt(0.80, 0.86))
            p.addLine(to: pt(0.80, 0.42))
            p.addLine(to: pt(0.70, 0.42))
            p.move(to: pt(0.5, 0.62))
            p.addLine(to: pt(0.5, 0.12))
            p.move(to: pt(0.36, 0.26))
            p.addLine(to: pt(0.5, 0.12))
            p.addLine(to: pt(0.64, 0.26))

        case .info:
            p.addEllipse(in: CGRect(x: rect.minX + 0.12 * w, y: rect.minY + 0.12 * h, width: 0.76 * w, height: 0.76 * h))
            p.move(to: pt(0.5, 0.30))
            p.addLine(to: pt(0.5, 0.34))
            p.move(to: pt(0.5, 0.46))
            p.addLine(to: pt(0.5, 0.70))

        case .heart:
            p.move(to: pt(0.5, 0.82))
            p.addCurve(to: pt(0.14, 0.36), control1: pt(0.26, 0.64), control2: pt(0.14, 0.52))
            p.addArc(center: pt(0.32, 0.36), radius: 0.18 * min(w, h), startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.addArc(center: pt(0.68, 0.36), radius: 0.18 * min(w, h), startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.addCurve(to: pt(0.5, 0.82), control1: pt(0.86, 0.52), control2: pt(0.74, 0.64))
            p.closeSubpath()

        case .book:
            p.move(to: pt(0.5, 0.24))
            p.addCurve(to: pt(0.14, 0.18), control1: pt(0.38, 0.16), control2: pt(0.24, 0.14))
            p.addLine(to: pt(0.14, 0.76))
            p.addCurve(to: pt(0.5, 0.84), control1: pt(0.24, 0.72), control2: pt(0.38, 0.76))
            p.addCurve(to: pt(0.86, 0.76), control1: pt(0.62, 0.76), control2: pt(0.76, 0.72))
            p.addLine(to: pt(0.86, 0.18))
            p.addCurve(to: pt(0.5, 0.24), control1: pt(0.76, 0.14), control2: pt(0.62, 0.16))
            p.move(to: pt(0.5, 0.24))
            p.addLine(to: pt(0.5, 0.84))

        case .remove:
            p.move(to: pt(0.22, 0.28))
            p.addLine(to: pt(0.78, 0.28))
            p.move(to: pt(0.40, 0.28))
            p.addLine(to: pt(0.40, 0.16))
            p.addLine(to: pt(0.60, 0.16))
            p.addLine(to: pt(0.60, 0.28))
            p.move(to: pt(0.28, 0.28))
            p.addLine(to: pt(0.32, 0.86))
            p.addLine(to: pt(0.68, 0.86))
            p.addLine(to: pt(0.72, 0.28))
        }
        return p
    }
}

#Preview("Settings glyphs") {
    let tokens = PaletteState.afternoon.tokens
    let glyphs: [SettingsGlyph] = [
        .location, .method, .asrShadow, .highLatitude, .sun, .adhan,
        .clock, .calendar, .pause, .travel, .jam, .qasr, .makeupLedger,
        .nightMoon, .rawatib, .counts, .voiceWaves, .sync, .privacy,
        .share, .info, .heart, .book, .remove,
    ]
    return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
        ForEach(Array(glyphs.enumerated()), id: \.offset) { _, glyph in
            SettingsGlyphView(glyph, color: tokens.metal)
                .frame(width: 22, height: 22)
                .padding(8)
        }
    }
    .padding()
    .background(tokens.panelFill)
}
