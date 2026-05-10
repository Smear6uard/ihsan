import SwiftUI
import IhsanCore

/// Horizontal day-arc: a thin atmospheric line representing the full day
/// (midnight → midnight) with one dot per fard prayer at its scheduled
/// position. Past-prayer dots are filled, future-prayer dots are
/// outlined, and a thin vertical accent in the adaptive time-of-day
/// tint marks the current moment along the line.
///
/// Lives in roughly 40pt of vertical space and is intended to sit
/// between the hero countdown and the prayer list — giving "where am I
/// in the day" context as a single quiet horizontal element.
public struct DayArc: View {
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
        // The whole arc re-renders once per minute. We don't need
        // per-second precision for a horizontal day visualization, and
        // the lower cadence keeps the SwiftUI graph quiet.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = override ?? context.date
            let tint = IhsanColor.adaptiveTint(at: now)
            let nowFraction = Self.dayFraction(at: now)

            GeometryReader { geometry in
                let width = geometry.size.width
                let centerY = geometry.size.height / 2

                ZStack(alignment: .topLeading) {
                    // Soft horizontal line — feathered at both ends so
                    // it reads as a thread laid across the surface
                    // rather than a hard ruled line.
                    LinearGradient(
                        colors: [
                            .clear,
                            IhsanColor.atmospheric.opacity(0.7),
                            IhsanColor.atmospheric.opacity(0.9),
                            IhsanColor.atmospheric.opacity(0.7),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width, height: 1)
                    .position(x: width / 2, y: centerY)

                    // Prayer dots — one per fard prayer.
                    ForEach(prayerMarks, id: \.prayer) { mark in
                        let fraction = Self.dayFraction(at: mark.time)
                        let isPast = now >= mark.time
                        PrayerDot(
                            isPast: isPast,
                            tint: tint
                        )
                        .position(x: width * fraction, y: centerY)
                        .accessibilityLabel(accessibilityLabel(for: mark, isPast: isPast))
                    }

                    // Vertical "now" accent. A thin glowing stem in the
                    // adaptive tint, anchored at the current time
                    // position. Vertical (not a dot) so it reads as a
                    // moving cursor rather than another prayer marker.
                    NowMarker(tint: tint, reduceMotion: reduceMotion)
                        .position(x: width * nowFraction, y: centerY)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 28)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Day arc")
    }

    private func accessibilityLabel(for mark: PrayerMark, isPast: Bool) -> String {
        let prayerName = mark.prayer.displayNameEnglish
        let timeString = mark.time.formatted(date: .omitted, time: .shortened)
        return isPast
            ? "\(prayerName) at \(timeString), passed"
            : "\(prayerName) at \(timeString), upcoming"
    }

    /// 0.0 at the start of the local day, 1.0 at the start of the next.
    static func dayFraction(at date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let comps = calendar.dateComponents([.hour, .minute, .second], from: date)
        let seconds = Double(comps.hour ?? 0) * 3600
            + Double(comps.minute ?? 0) * 60
            + Double(comps.second ?? 0)
        return max(0.0, min(1.0, seconds / 86_400))
    }
}

private struct PrayerDot: View {
    let isPast: Bool
    let tint: Color

    var body: some View {
        ZStack {
            // Past prayers: filled tint dot. Future prayers: just the
            // ring. The change is small but readable — the line is a
            // chronology, not a status display.
            if isPast {
                Circle()
                    .fill(tint.opacity(0.85))
                    .frame(width: 7, height: 7)
                    .shadow(color: tint.opacity(0.45), radius: 3, x: 0, y: 0)
            }
            Circle()
                .strokeBorder(IhsanColor.atmospheric.opacity(0.95), lineWidth: 0.75)
                .frame(width: 7, height: 7)
        }
    }
}

private struct NowMarker: View {
    let tint: Color
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            cursorView(scale: 1.0, opacity: 1.0)
        } else {
            // 2.4s breathing cycle. The phase is derived from the
            // tick timestamp so we never need a @State variable
            // (which would have to be mutated from a background Task).
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let phase = elapsed * (2 * .pi / 2.4)
                let scale = 1.0 + 0.18 * sin(phase)
                let opacity = 0.78 + 0.22 * (0.5 + 0.5 * sin(phase))
                cursorView(scale: scale, opacity: opacity)
            }
        }
    }

    @ViewBuilder
    private func cursorView(scale: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(tint)
            .frame(width: 5, height: 5)
            .shadow(color: tint.opacity(0.85), radius: 5, x: 0, y: 0)
            .shadow(color: tint.opacity(0.45), radius: 10, x: 0, y: 0)
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

#Preview("Day arc — afternoon (Asr just passed)") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    func time(_ h: Int, _ m: Int) -> Date {
        calendar.date(byAdding: .second, value: h * 3600 + m * 60, to: today) ?? today
    }
    let marks: [DayArc.PrayerMark] = [
        .init(prayer: .fajr, time: time(5, 0)),
        .init(prayer: .dhuhr, time: time(12, 30)),
        .init(prayer: .asr, time: time(15, 30)),
        .init(prayer: .maghrib, time: time(19, 0)),
        .init(prayer: .isha, time: time(21, 30))
    ]
    return ZStack {
        IhsanColor.ground.ignoresSafeArea()
        DayArc(prayerMarks: marks)
            .padding(IhsanSpacing.lg)
    }
    .environment(\.timeOfDayOverride, time(15, 45))
}
