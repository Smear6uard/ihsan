import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Lock screen circular — five segments around one ornament.
///
/// Each segment is one prayer, filled once that prayer is logged. The
/// centre carries the current or next prayer's own ornament. During an
/// excused pause the segments stand aside entirely — the face shows
/// the ornament and nothing that reads as an unfilled obligation.
struct PrayerProgressCircularWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        switch entry.content {
        case .live(let day):
            liveBody(day)
        case .invitation:
            // At circular scale the invitation is the app's mark
            // alone — a quiet seal, never a fake ring.
            LockOrnament(prayer: .fajr, size: 20, isEmphasised: false)
                .widgetAccentable()
                .accessibilityLabel("Open Ihsan for today's prayer times")
        }
    }

    @ViewBuilder
    private func liveBody(_ day: PrayerTimelineEntry.LiveDay) -> some View {
        ZStack {
            if !day.isPaused {
                ForEach(Array(day.slots.enumerated()), id: \.element.id) { index, slot in
                    let isFilled = slot.status != nil && slot.status != .missed
                    Arc(startDegree: degrees(for: index).start,
                        endDegree: degrees(for: index).end)
                        .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .butt))
                        .foregroundStyle(isFilled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                }
            }

            LockOrnament(
                prayer: day.currentPrayer ?? day.nextPrayer,
                size: 17,
                isEmphasised: day.currentPrayer != nil
            )
        }
        .padding(2)
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(day))
    }

    private func degrees(for index: Int) -> (start: Double, end: Double) {
        // Five segments around the full circle, 2° gaps, from the top.
        let segmentSpan = 360.0 / 5.0
        let gap = 2.0
        let start = -90.0 + Double(index) * segmentSpan + gap / 2.0
        let end = start + segmentSpan - gap
        return (start, end)
    }

    private func accessibilityLabel(_ day: PrayerTimelineEntry.LiveDay) -> String {
        if let current = day.currentPrayer {
            return "\(current.displayNameEnglish) now"
        }
        return "\(day.nextPrayer.displayNameEnglish) at \(day.clockTime(day.nextPrayerTime))"
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
