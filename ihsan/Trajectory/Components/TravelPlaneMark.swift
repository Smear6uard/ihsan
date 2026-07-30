import SwiftUI

/// The travel mark — a minimal swept-wing plane drawn as a custom
/// path in the engraved linework language. Content areas never use
/// SF Symbols; this is the one airplane in the app, shared by the
/// gestalt pattern's under-column annotations and the Daily Practice
/// date labels.
struct TravelPlaneMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        // Fuselage: nose at the right, tail at the left third.
        p.move(to: CGPoint(x: 0.95 * w, y: 0.50 * h))
        // Upper wing sweep.
        p.addLine(to: CGPoint(x: 0.55 * w, y: 0.38 * h))
        p.addLine(to: CGPoint(x: 0.28 * w, y: 0.08 * h))
        p.addLine(to: CGPoint(x: 0.20 * w, y: 0.12 * h))
        p.addLine(to: CGPoint(x: 0.38 * w, y: 0.42 * h))
        // Tail.
        p.addLine(to: CGPoint(x: 0.12 * w, y: 0.36 * h))
        p.addLine(to: CGPoint(x: 0.05 * w, y: 0.42 * h))
        p.addLine(to: CGPoint(x: 0.22 * w, y: 0.50 * h))
        p.addLine(to: CGPoint(x: 0.05 * w, y: 0.58 * h))
        p.addLine(to: CGPoint(x: 0.12 * w, y: 0.64 * h))
        // Lower wing sweep (mirror).
        p.addLine(to: CGPoint(x: 0.38 * w, y: 0.58 * h))
        p.addLine(to: CGPoint(x: 0.20 * w, y: 0.88 * h))
        p.addLine(to: CGPoint(x: 0.28 * w, y: 0.92 * h))
        p.addLine(to: CGPoint(x: 0.55 * w, y: 0.62 * h))
        p.closeSubpath()
        return p
    }
}
