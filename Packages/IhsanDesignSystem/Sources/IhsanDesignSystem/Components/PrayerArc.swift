import SwiftUI
import IhsanCore

/// The day's prayer schedule rendered as an illuminated astrolabe-style
/// arc: a brass curve from the left horizon (Fajr) through the zenith to
/// the right horizon (Isha), with a small four-pointed star at each
/// fard prayer's scheduled time and a larger eight-pointed gold star
/// marking the current moment.
///
/// At night — before Fajr or after Isha — the arc collapses to a flat
/// horizontal brass line with a small crescent moon at the user's
/// current position. The same chromatic key (brass arc, gold now-marker)
/// is preserved so the screen reads in one visual register.
///
/// This component is the single most distinctive element of the Today
/// screen. Get the star geometry, the proportions, and the gold glow
/// right and the whole composition reads "illuminated manuscript".
public struct PrayerArc: View {
    public struct PrayerMark: Sendable {
        public let prayer: Prayer
        public let time: Date

        public init(prayer: Prayer, time: Date) {
            self.prayer = prayer
            self.time = time
        }
    }

    public let prayerMarks: [PrayerMark]

    @Environment(\.timeOfDayOverride) private var override
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(prayerMarks: [PrayerMark]) {
        self.prayerMarks = prayerMarks
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = override ?? context.date
            let position = ArcPosition.compute(at: now, marks: prayerMarks)

            GeometryReader { geometry in
                ZStack {
                    switch position {
                    case .dayArc(let nowT):
                        ArcLayer(
                            marks: prayerMarks,
                            nowT: nowT,
                            now: now,
                            size: geometry.size,
                            reduceMotion: reduceMotion
                        )
                    case .preDawn, .postIsha:
                        NightLayer(
                            position: position,
                            size: geometry.size
                        )
                    }
                }
            }
            .frame(height: ArcGeometry.containerHeight)
            .padding(.horizontal, ArcGeometry.horizontalInset)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(for: position, now: now))
        }
    }

    private func accessibilityLabel(for position: ArcPosition, now: Date) -> String {
        switch position {
        case .preDawn:
            if let nextFajr = prayerMarks.first(where: { $0.prayer == .fajr })?.time {
                let nextTime = nextFajr.formatted(date: .omitted, time: .shortened)
                return "Night sky. Fajr begins at \(nextTime)."
            }
            return "Night sky"
        case .postIsha:
            return "Night sky. The day's arc is complete."
        case .dayArc(let t):
            let percent = Int((t * 100).rounded())
            return "Day arc, \(percent) percent through. \(nextPrayerDescription(after: now))"
        }
    }

    private func nextPrayerDescription(after date: Date) -> String {
        guard let next = prayerMarks.first(where: { $0.time > date }) else {
            return "All prayers passed."
        }
        let timeString = next.time.formatted(date: .omitted, time: .shortened)
        return "\(next.prayer.displayNameEnglish) next at \(timeString)."
    }
}

// MARK: - Position model

/// Where "now" sits relative to the day's arc. `internal` (not `private`)
/// so `PrayerArcTests` can verify the transition points between night
/// and day without going through the full SwiftUI view tree.
enum ArcPosition: Equatable {
    case preDawn       // before Fajr
    case dayArc(t: Double) // between Fajr and Isha, t ∈ [0, 1]
    case postIsha      // after Isha

    static func compute(at now: Date, marks: [PrayerArc.PrayerMark]) -> ArcPosition {
        guard let fajr = marks.first(where: { $0.prayer == .fajr })?.time,
              let isha = marks.first(where: { $0.prayer == .isha })?.time
        else {
            return .dayArc(t: 0.5)
        }
        if now < fajr { return .preDawn }
        if now >= isha { return .postIsha }
        let span = isha.timeIntervalSince(fajr)
        guard span > 0 else { return .dayArc(t: 0.5) }
        let t = now.timeIntervalSince(fajr) / span
        return .dayArc(t: max(0, min(1, t)))
    }
}

// MARK: - Arc geometry

/// Sine-curve arc parameterized over t ∈ [0, 1]. y = base − amp·sin(πt)
/// reaches the apex exactly at t = 0.5, which gives the curve a true
/// noon-zenith feel without the asymmetric droop of an untuned bezier.
/// `internal` (not `private`) so `PrayerArcTests` can pin the curve's
/// endpoints and apex.
enum ArcGeometry {
    /// Outer horizontal margin applied via `.padding(.horizontal, ...)`.
    /// Combines with the inner inset so the curve never touches the screen
    /// edges nor the panel borders flanking it on the Today screen.
    static let horizontalInset: CGFloat = 18

    /// Inner inset from the geometry's edges to the arc endpoints, in
    /// points. Leaves room for the marker stars at the horizon to render
    /// fully without clipping.
    static let inset: CGFloat = 12

    /// Vertical room from the base to the apex of the arc.
    static let amplitude: CGFloat = 56

    /// Distance from the base of the arc up to the baseline.
    static let baseInsetBottom: CGFloat = 16

    /// The vertical extent of the arc component. Hosts the curve, the
    /// markers, and accommodates the now-marker's glow without clipping.
    static let containerHeight: CGFloat = 90

    static func point(at t: Double, in size: CGSize) -> CGPoint {
        let usableWidth = size.width - inset * 2
        let baseY = size.height - baseInsetBottom
        let x = inset + CGFloat(t) * usableWidth
        let y = baseY - amplitude * CGFloat(sin(t * .pi))
        return CGPoint(x: x, y: y)
    }

    /// Sampled path of the arc itself. 80 segments produces a curve that
    /// reads as smooth at every iPhone width without burning per-frame
    /// cycles in Canvas.
    static func path(in size: CGSize, segments: Int = 80) -> Path {
        var path = Path()
        for i in 0...segments {
            let t = Double(i) / Double(segments)
            let p = point(at: t, in: size)
            if i == 0 {
                path.move(to: p)
            } else {
                path.addLine(to: p)
            }
        }
        return path
    }
}

// MARK: - Layers

/// The full day arc — curve + 5 prayer star markers + glowing now-marker.
private struct ArcLayer: View {
    let marks: [PrayerArc.PrayerMark]
    let nowT: Double
    let now: Date
    let size: CGSize
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            // 1. The arc curve. Thin brass stroke at 50% opacity,
            //    feathered at the ends so it dissolves into the page
            //    rather than terminating in hard endpoints.
            ArcStroke()
                .stroke(
                    LinearGradient(
                        colors: [
                            IhsanColor.brass.opacity(0.08),
                            IhsanColor.brass.opacity(0.50),
                            IhsanColor.brass.opacity(0.50),
                            IhsanColor.brass.opacity(0.08)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .frame(width: size.width, height: size.height)

            // 2. Prayer star markers — small four-pointed stars
            //    positioned at each prayer's scheduled time. Past
            //    prayers fill, future prayers outline.
            ForEach(0..<marks.count, id: \.self) { i in
                let mark = marks[i]
                let t = parametricT(for: mark)
                let p = ArcGeometry.point(at: t, in: size)
                let isPast = mark.time <= now

                PrayerArcDot(isPast: isPast)
                    .position(p)
            }

            // 3. Current-time marker — an eight-pointed gold star with a
            //    soft gold glow. The single moment of saturation on the
            //    arc; everything else is brass.
            let nowPoint = ArcGeometry.point(at: nowT, in: size)
            NowMarker(reduceMotion: reduceMotion)
                .position(nowPoint)
        }
    }

    private func parametricT(for mark: PrayerArc.PrayerMark) -> Double {
        guard let fajr = marks.first(where: { $0.prayer == .fajr })?.time,
              let isha = marks.first(where: { $0.prayer == .isha })?.time
        else { return 0.5 }
        let span = isha.timeIntervalSince(fajr)
        guard span > 0 else { return 0.5 }
        return max(0, min(1, mark.time.timeIntervalSince(fajr) / span))
    }
}

/// The arc curve as a `Shape` so it can be stroked with a gradient.
private struct ArcStroke: Shape {
    func path(in rect: CGRect) -> Path {
        ArcGeometry.path(in: rect.size)
    }
}

/// A single prayer marker rendered as a four-pointed star. Past prayers
/// fill the star in brass; future prayers render only the outlined
/// stroke. The size (8pt) is calibrated against the curve's stroke width
/// so the markers read as ornaments laid on the arc, not as glyphs
/// floating above it.
private struct PrayerArcDot: View {
    let isPast: Bool

    var body: some View {
        ZStack {
            if isPast {
                FourPointedStar()
                    .fill(IhsanColor.brass.opacity(0.92))
                    .frame(width: 8, height: 8)
            }
            FourPointedStar()
                .stroke(
                    IhsanColor.brass.opacity(isPast ? 0.55 : 0.85),
                    lineWidth: 1.0
                )
                .frame(width: 9, height: 9)
        }
        .shadow(
            color: isPast ? IhsanColor.brass.opacity(0.35) : .clear,
            radius: 2,
            x: 0,
            y: 0
        )
    }
}

/// The now-marker. A large eight-pointed Star-of-Lakshmi rendered in
/// gold, with a soft gold halo and a subtle 3-second breathing pulse.
/// The pulse is suppressed under Reduce Motion.
private struct NowMarker: View {
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            markerBody(scale: 1.0, opacity: 1.0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let phase = elapsed * (2 * .pi / 3.0) // 3 s cycle
                let pulse = 0.5 + 0.5 * sin(phase)
                let scale = 1.0 + 0.10 * pulse
                let opacity = 0.88 + 0.12 * pulse
                markerBody(scale: scale, opacity: opacity)
            }
        }
    }

    @ViewBuilder
    private func markerBody(scale: CGFloat, opacity: Double) -> some View {
        ZStack {
            // Outer gold halo. Wider and softer than the inner star,
            // tinted at 30% so it lifts the marker off the brass arc
            // without ever reading as a glare.
            EightPointedStar()
                .fill(IhsanColor.gold.opacity(0.30))
                .frame(width: 30, height: 30)
                .blur(radius: 4)

            // Inner iridescent gold star — the visible marker. The
            // radial gradient samples the brass palette so the star
            // reads as "gold leaf catching light" rather than a flat
            // gold disc. The brass rim outline anchors the silhouette
            // against the parchment surface beneath.
            EightPointedStar()
                .fill(IhsanIridescence.goldOrnament())
                .frame(width: 14, height: 14)
                .overlay {
                    EightPointedStar()
                        .stroke(IhsanColor.brassDark.opacity(0.70), lineWidth: 0.6)
                }
                .shadow(color: IhsanColor.gold.opacity(0.75), radius: 6, x: 0, y: 0)
                .shadow(color: IhsanColor.gold.opacity(0.40), radius: 14, x: 0, y: 0)
        }
        .scaleEffect(scale)
        .opacity(opacity)
    }
}

/// The pre-Fajr / post-Isha alternative. A thin horizontal brass band at
/// the arc's base with a small crescent moon at the user's current
/// position. The arc is absent because the day's prayer arc has not yet
/// begun or has completed; the page is contemplative.
private struct NightLayer: View {
    let position: ArcPosition
    let size: CGSize

    var body: some View {
        ZStack {
            // Feathered brass horizon line.
            LinearGradient(
                colors: [
                    IhsanColor.brass.opacity(0.05),
                    IhsanColor.brass.opacity(0.40),
                    IhsanColor.brass.opacity(0.40),
                    IhsanColor.brass.opacity(0.05)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(
                width: size.width - ArcGeometry.inset * 2,
                height: 1
            )
            .position(
                x: size.width / 2,
                y: size.height - ArcGeometry.baseInsetBottom
            )

            // Crescent moon centred on the line. Brass-tinted so it
            // belongs to the same chromatic key as the day arc.
            Image(systemName: moonSymbol)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(IhsanColor.brass.opacity(0.88))
                .shadow(color: IhsanColor.brass.opacity(0.45), radius: 4, x: 0, y: 0)
                .position(
                    x: size.width / 2,
                    y: size.height - ArcGeometry.baseInsetBottom - 16
                )
        }
    }

    private var moonSymbol: String {
        switch position {
        case .preDawn: return "moon.stars"
        case .postIsha: return "moon.fill"
        case .dayArc: return "sun.max"
        }
    }
}

// MARK: - Previews

#Preview("Prayer arc — mid-afternoon") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    func time(_ h: Int, _ m: Int) -> Date {
        calendar.date(byAdding: .second, value: h * 3600 + m * 60, to: today) ?? today
    }
    let marks: [PrayerArc.PrayerMark] = [
        .init(prayer: .fajr, time: time(5, 0)),
        .init(prayer: .dhuhr, time: time(12, 30)),
        .init(prayer: .asr, time: time(15, 30)),
        .init(prayer: .maghrib, time: time(19, 0)),
        .init(prayer: .isha, time: time(21, 30))
    ]
    return ZStack {
        IhsanSkyGradient().ignoresSafeArea()
        VStack {
            PrayerArc(prayerMarks: marks)
                .padding(.horizontal, IhsanSpacing.md)
        }
    }
    .environment(\.timeOfDayOverride, time(15, 45))
}

#Preview("Prayer arc — pre-dawn") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    func time(_ h: Int, _ m: Int) -> Date {
        calendar.date(byAdding: .second, value: h * 3600 + m * 60, to: today) ?? today
    }
    let marks: [PrayerArc.PrayerMark] = [
        .init(prayer: .fajr, time: time(5, 0)),
        .init(prayer: .dhuhr, time: time(12, 30)),
        .init(prayer: .asr, time: time(15, 30)),
        .init(prayer: .maghrib, time: time(19, 0)),
        .init(prayer: .isha, time: time(21, 30))
    ]
    return ZStack {
        IhsanSkyGradient().ignoresSafeArea()
        VStack {
            PrayerArc(prayerMarks: marks)
                .padding(.horizontal, IhsanSpacing.md)
        }
    }
    .environment(\.timeOfDayOverride, time(3, 30))
}
