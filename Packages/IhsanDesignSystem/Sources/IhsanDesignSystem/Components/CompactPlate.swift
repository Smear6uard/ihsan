import IhsanCore
import SwiftUI

/// The day's arc, small.
///
/// The full celestial plate is a screen-sized instrument. This is the
/// same idea reduced to what survives at two inches: a shallow arc, the
/// five ornaments at their true proportion of the day, one sunrise
/// tick, and nothing else. No labels, no axis, no grid — the shapes are
/// the information, and their spacing says something true (the crowding
/// of Maghrib against Isha in summer, the long gap after Fajr).
///
/// It lives in the design system rather than in the widget extension
/// because more than one surface needs it — the widgets, the nightstand
/// face, and any preview that has to show what those will look like
/// without a home screen to put them on.
public struct CompactPlate: View {

    /// Everything the arc needs, and nothing about where it came from.
    public struct Model: Sendable, Equatable {
        public struct Mark: Sendable, Equatable {
            public let prayer: Prayer
            public let time: Date
            public let state: PrayerMarkerState

            public init(prayer: Prayer, time: Date, state: PrayerMarkerState) {
                self.prayer = prayer
                self.time = time
                self.state = state
            }
        }

        public let marks: [Mark]
        public let sunrise: Date?

        public init(marks: [Mark], sunrise: Date?) {
            self.marks = marks
            self.sunrise = sunrise
        }
    }

    public let model: Model
    public let tokens: SkyPaletteTokens
    /// Ornament diameter; the arc scales around it.
    public var ornamentSize: CGFloat

    public init(
        model: Model,
        tokens: SkyPaletteTokens,
        ornamentSize: CGFloat = 18
    ) {
        self.model = model
        self.tokens = tokens
        self.ornamentSize = ornamentSize
    }

    private var span: (start: Date, end: Date)? {
        guard
            let first = model.marks.first?.time,
            let last = model.marks.last?.time,
            last > first
        else { return nil }
        return (first, last)
    }

    /// Where a moment falls along the arc, `0...1`. Fajr anchors the
    /// left and Isha the right, inset so neither is clipped by a
    /// rounded corner.
    private func position(of date: Date) -> CGFloat? {
        guard let span else { return nil }
        let total = span.end.timeIntervalSince(span.start)
        guard total > 0 else { return nil }
        return CGFloat(min(max(date.timeIntervalSince(span.start) / total, 0), 1))
    }

    public var body: some View {
        GeometryReader { proxy in
            let arc = ArcGeometry(size: proxy.size, ornamentSize: ornamentSize)

            ZStack(alignment: .topLeading) {
                ArcPath(arc: arc)
                    .stroke(
                        LinearGradient(
                            colors: [
                                tokens.metal.opacity(0.20),
                                tokens.metal.opacity(0.55),
                                tokens.metal.opacity(0.20)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )

                // Sunrise crosses the arc as a fine tick — the same mark
                // the full plate uses. It is not a prayer, so it is
                // never an ornament.
                if let sunrise = model.sunrise, let t = position(of: sunrise) {
                    let p = arc.point(at: t)
                    Path { path in
                        path.move(to: CGPoint(x: p.x, y: p.y - 3))
                        path.addLine(to: CGPoint(x: p.x, y: p.y + 3))
                    }
                    .stroke(tokens.metal.opacity(0.45), lineWidth: 1)
                }

                ForEach(model.marks, id: \.prayer) { mark in
                    if let t = position(of: mark.time) {
                        let p = arc.point(at: t)
                        PrayerMarkerOrnament(
                            prayer: mark.prayer,
                            size: ornamentSize,
                            state: mark.state,
                            tokens: tokens
                        )
                        .position(x: p.x, y: p.y)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's prayers")
        .accessibilityValue(
            model.marks
                .map { "\($0.prayer.displayNameEnglish) \($0.state.spokenDescription)" }
                .joined(separator: ", ")
        )
    }
}

/// Where the arc lies, and where a moment sits on it. One definition,
/// used by both the stroke and the ornaments, so a marker can never end
/// up off its own curve.
struct ArcGeometry: Equatable {
    let inset: CGFloat
    let width: CGFloat
    let rise: CGFloat
    let baseline: CGFloat

    init(size: CGSize, ornamentSize: CGFloat) {
        // The first and last ornaments sit at the ends of the arc,
        // which on a widget is exactly where the rounded corner cuts
        // in. The inset and the raised baseline together keep both of
        // them clear of it.
        inset = ornamentSize / 2 + 6
        width = max(size.width - inset * 2, 1)
        // Shallow on purpose: the ornaments ride the curve's top edge,
        // so it reads as the sun's path rather than as a bowl.
        rise = min(size.height * 0.42, width * 0.16)
        baseline = size.height - ornamentSize / 2 - 4
    }

    /// A parabola: both ends on the baseline, peak at t = 0.5.
    func point(at t: CGFloat) -> CGPoint {
        CGPoint(
            x: inset + width * t,
            y: baseline - rise * (1 - pow(2 * t - 1, 2))
        )
    }
}

struct ArcPath: Shape {
    let arc: ArcGeometry

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let samples = 48
        for index in 0...samples {
            let point = arc.point(at: CGFloat(index) / CGFloat(samples))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

public extension PrayerMarkerState {
    /// VoiceOver phrasing, defined once so every surface voices a
    /// marker the same way.
    var spokenDescription: String {
        switch self {
        case .upcoming: "upcoming"
        case .current: "now"
        case .logged: "logged"
        case .passedUnlogged: "passed, not logged"
        }
    }
}
