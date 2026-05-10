import SwiftUI
import IhsanCore

/// The day's path rendered as a gentle sine-curve arc from the left
/// horizon (Fajr) through the zenith to the right horizon (Isha), with
/// one dot per fard prayer positioned along the curve at its actual
/// scheduled time. A larger glowing brass dot tracks the current moment.
///
/// At night — before Fajr or after Isha — the arc collapses to a flat
/// horizontal line with a quiet moon icon, signalling that the day's
/// arc has not yet begun (or has completed).
///
/// This component is the visual signature of the Today screen. Get the
/// arc proportions, the dot weights, and the now-marker glow right and
/// the whole screen reads "premium iOS app" rather than "generic prayer
/// app".
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
        // Re-render once a minute. The arc geometry doesn't change between
        // ticks; what changes is which dots are "past" and where the
        // now-marker sits. A 60 s cadence is plenty for either signal.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = override ?? context.date
            let accent = IhsanColor.accentWarm(at: now)
            let contrast = IhsanColor.cardForegroundPrimary(at: now)
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
                            accent: accent,
                            contrast: contrast,
                            reduceMotion: reduceMotion
                        )
                    case .preDawn, .postIsha:
                        NightLayer(
                            position: position,
                            size: geometry.size,
                            accent: accent,
                            contrast: contrast
                        )
                    }
                }
            }
            .frame(height: 80)
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

/// Where "now" sits relative to the day's arc.
/// `internal` (not `private`) so `PrayerArcTests` can verify the
/// transition points between night and day without going through the
/// full SwiftUI view tree.
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
    static let inset: CGFloat = 14
    static let baseInsetBottom: CGFloat = 14
    /// Vertical room between the base and the apex.
    static let amplitude: CGFloat = 50

    static func point(at t: Double, in size: CGSize) -> CGPoint {
        let usableWidth = size.width - inset * 2
        let baseY = size.height - baseInsetBottom
        let x = inset + CGFloat(t) * usableWidth
        let y = baseY - amplitude * CGFloat(sin(t * .pi))
        return CGPoint(x: x, y: y)
    }

    /// Sampled path of the arc itself. 60 segments produces a curve
    /// that reads as smooth at every iPhone width without burning
    /// per-frame cycles in Canvas.
    static func path(in size: CGSize, segments: Int = 60) -> Path {
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

/// The full day arc — curve + 5 prayer dots + glowing now-marker.
private struct ArcLayer: View {
    let marks: [PrayerArc.PrayerMark]
    let nowT: Double
    let now: Date
    let size: CGSize
    let accent: Color
    let contrast: Color
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            // 1. The arc curve. Thin, atmospheric, feathered at the ends
            //    via a horizontal gradient so it dissolves into the sky
            //    rather than terminating in hard endpoints.
            ArcStroke()
                .stroke(
                    LinearGradient(
                        colors: [
                            contrast.opacity(0.06),
                            contrast.opacity(0.32),
                            contrast.opacity(0.32),
                            contrast.opacity(0.06)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                )
                .frame(width: size.width, height: size.height)

            // 2. Past prayer dots — filled in the warm accent.
            //    Future prayer dots — outlined ring in the same accent.
            ForEach(0..<marks.count, id: \.self) { i in
                let mark = marks[i]
                let t = parametricT(for: mark)
                let p = ArcGeometry.point(at: t, in: size)
                let isPast = mark.time <= now

                PrayerDot(isPast: isPast, accent: accent)
                    .position(p)
            }

            // 3. Now-marker — larger filled dot in accent with glow halo.
            //    The 3 s pulse is suppressed under Reduce Motion.
            let nowPoint = ArcGeometry.point(at: nowT, in: size)
            NowMarker(accent: accent, reduceMotion: reduceMotion)
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

/// A single prayer dot. Past prayers carry a filled disc; future
/// prayers carry only the outlined ring. The ring is always drawn so
/// past dots have a defining edge against the bright accent fill.
private struct PrayerDot: View {
    let isPast: Bool
    let accent: Color

    var body: some View {
        ZStack {
            if isPast {
                Circle()
                    .fill(accent.opacity(0.90))
                    .frame(width: 8, height: 8)
                    .shadow(color: accent.opacity(0.45), radius: 3, x: 0, y: 0)
            }
            Circle()
                .strokeBorder(
                    accent.opacity(isPast ? 0.55 : 0.85),
                    lineWidth: 1.0
                )
                .frame(width: 9, height: 9)
        }
    }
}

/// The now-marker. Larger than the prayer dots, with a tinted halo so it
/// reads as the focal element. The 3 s breathing cycle uses a sine
/// derived from the timeline timestamp — no `@State`, no background
/// mutation.
private struct NowMarker: View {
    let accent: Color
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            cursorView(scale: 1.0, opacity: 1.0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let phase = elapsed * (2 * .pi / 3.0) // 3 s cycle
                let pulse = 0.5 + 0.5 * sin(phase)
                let scale = 1.0 + 0.14 * pulse
                let opacity = 0.85 + 0.15 * pulse
                cursorView(scale: scale, opacity: opacity)
            }
        }
    }

    @ViewBuilder
    private func cursorView(scale: CGFloat, opacity: Double) -> some View {
        ZStack {
            // Soft outer halo
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 28, height: 28)
                .blur(radius: 4)
            // Inner filled marker
            Circle()
                .fill(accent)
                .frame(width: 12, height: 12)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.55), lineWidth: 0.75)
                }
                .shadow(color: accent.opacity(0.75), radius: 6, x: 0, y: 0)
                .shadow(color: accent.opacity(0.45), radius: 14, x: 0, y: 0)
        }
        .scaleEffect(scale)
        .opacity(opacity)
    }
}

/// The pre-Fajr / post-Isha alternative. A flat horizontal line at the
/// arc's base with a small moon icon at its centre. The arc is absent
/// because the day's prayer arc has not yet begun, or has completed.
private struct NightLayer: View {
    let position: ArcPosition
    let size: CGSize
    let accent: Color
    let contrast: Color

    var body: some View {
        ZStack {
            // Flat horizontal line — feathered ends so it never reads
            // as a hard ruled border.
            LinearGradient(
                colors: [
                    contrast.opacity(0.05),
                    contrast.opacity(0.32),
                    contrast.opacity(0.32),
                    contrast.opacity(0.05)
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

            // Moon icon at the centre of the line, tinted in the
            // current accent so it sits in the same chromatic key as
            // the rest of the screen at night.
            Image(systemName: moonSymbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(accent.opacity(0.85))
                .shadow(color: accent.opacity(0.45), radius: 4, x: 0, y: 0)
                .position(
                    x: size.width / 2,
                    y: size.height - ArcGeometry.baseInsetBottom - 14
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

// MARK: - Preview

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
                .padding(.horizontal, IhsanSpacing.lg)
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
                .padding(.horizontal, IhsanSpacing.lg)
        }
    }
    .environment(\.timeOfDayOverride, time(3, 30))
}
