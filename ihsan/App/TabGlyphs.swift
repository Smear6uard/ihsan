import SwiftUI
import UIKit

/// The tab bar's linework glyph set — drawn marks from the app's own
/// vocabulary, never SF Symbols: the day arc over its horizon chord
/// (Today), the gestalt dots (Path), the closed book (Reflect), and
/// the engraved dial (Set). Rendered once as template images so the
/// native bar applies its own selected/unselected tinting.
@MainActor
enum TabGlyphs {
    static let today = render(TodayTabGlyph(), filled: false)
    static let path = render(PathTabGlyph(), filled: true)
    static let reflect = render(ReflectTabGlyph(), filled: false)
    static let set = render(SetTabGlyph(), filled: false)

    private static func render(_ shape: some Shape, filled: Bool) -> UIImage {
        let side: CGFloat = 26
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            let rect = CGRect(x: 1.5, y: 1.5, width: side - 3, height: side - 3)
            let path = shape.path(in: rect)
            context.cgContext.setStrokeColor(UIColor.black.cgColor)
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.setLineWidth(1.6)
            context.cgContext.setLineCap(.round)
            context.cgContext.addPath(path.cgPath)
            if filled {
                context.cgContext.drawPath(using: .fillStroke)
            } else {
                context.cgContext.strokePath()
            }
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}

/// Today: the plate in miniature — the day arc bowed over its
/// inset horizon chord.
private struct TodayTabGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let chordY = rect.maxY - rect.height * 0.18
        path.move(to: CGPoint(x: rect.minX, y: chordY))
        path.addLine(to: CGPoint(x: rect.maxX, y: chordY))
        let left = CGPoint(x: rect.minX + rect.width * 0.12, y: chordY)
        let right = CGPoint(x: rect.maxX - rect.width * 0.12, y: chordY)
        path.move(to: left)
        path.addQuadCurve(
            to: right,
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.16)
        )
        return path
    }
}

/// Path: the gestalt dots — a week of small marks rising across the
/// field.
private struct PathTabGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.width * 0.075
        let positions: [(CGFloat, CGFloat)] = [
            (0.10, 0.82), (0.32, 0.58), (0.54, 0.70), (0.76, 0.38), (0.94, 0.16),
        ]
        for (x, y) in positions {
            let center = CGPoint(
                x: rect.minX + rect.width * x,
                y: rect.minY + rect.height * y
            )
            path.addEllipse(in: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))
        }
        return path
    }
}

/// Reflect: the closed book — spine, cover, and the page edge.
private struct ReflectTabGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.12
        let book = rect.insetBy(dx: inset, dy: rect.height * 0.06)
        path.addRoundedRect(in: book, cornerSize: CGSize(width: 2.5, height: 2.5))
        // The spine.
        let spineX = book.minX + book.width * 0.24
        path.move(to: CGPoint(x: spineX, y: book.minY))
        path.addLine(to: CGPoint(x: spineX, y: book.maxY))
        return path
    }
}

/// Set: the engraved dial — a ring with four fine radial ticks.
private struct SetTabGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let ring = outer * 0.68
        path.addEllipse(in: CGRect(
            x: center.x - ring, y: center.y - ring,
            width: ring * 2, height: ring * 2
        ))
        for index in 0..<4 {
            let angle = Double(index) * .pi / 2 + .pi / 4
            let from = CGPoint(
                x: center.x + cos(angle) * ring,
                y: center.y + sin(angle) * ring
            )
            let to = CGPoint(
                x: center.x + cos(angle) * outer,
                y: center.y + sin(angle) * outer
            )
            path.move(to: from)
            path.addLine(to: to)
        }
        return path
    }
}
