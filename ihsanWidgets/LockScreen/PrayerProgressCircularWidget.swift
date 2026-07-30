import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Lock screen circular — five segments around one ornament.
///
/// Each segment is one prayer, filled once that prayer is logged. The
/// centre carries the current or next prayer's own ornament, so the
/// glance answers "which prayer, and where am I in the day" without a
/// figure. It used to read "3/5"; a count out of five is a score, and
/// this app does not keep score of anyone's worship.
///
/// `Gauge` is too coarse for five distinct segments, so the ring is
/// composed from five arcs.
struct PrayerProgressCircularWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                let prayer = Prayer.allCases[index]
                let logged = entry.loggedStatus(for: prayer)
                let isFilled = logged != nil && logged != .missed
                Arc(startDegree: degrees(for: index).start,
                    endDegree: degrees(for: index).end)
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .butt))
                    .foregroundStyle(isFilled ? .primary : .tertiary)
            }

            LockOrnament(
                prayer: centrePrayer,
                size: 17,
                isEmphasised: entry.currentPrayer != nil
            )
        }
        .padding(2)
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func degrees(for index: Int) -> (start: Double, end: Double) {
        // Five segments around the full circle. 2° gaps for visual breathing
        // room. Start at -90° (top) and proceed clockwise.
        let segmentSpan = 360.0 / 5.0
        let gap = 2.0
        let start = -90.0 + Double(index) * segmentSpan + gap / 2.0
        let end = start + segmentSpan - gap
        return (start, end)
    }

    /// The prayer the glance is about: the open one if a window is
    /// open, otherwise the one being waited for.
    private var centrePrayer: Prayer {
        entry.currentPrayer ?? entry.nextPrayer
    }

    private var accessibilityLabel: String {
        if let current = entry.currentPrayer {
            return "\(current.displayNameEnglish) now"
        }
        return "\(entry.nextPrayer.displayNameEnglish) at \(entry.clockTime(entry.nextPrayerScheduledTime))"
    }
}

private struct Arc: Shape {
    let startDegree: Double
    let endDegree: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2 - 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startDegree),
            endAngle: .degrees(endDegree),
            clockwise: false
        )
        return path
    }
}

struct PrayerProgressCircularWidget: Widget {
    static let kind: String = "PrayerProgressCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            PrayerProgressCircularWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Today's Progress")
        .description("Which prayers are logged, and which one you are in.")
        .supportedFamilies([.accessoryCircular])
    }
}
