import IhsanCore
import SwiftUI
import WidgetKit

/// Lock screen circular widget — five-segment progress ring around an
/// outline prayer symbol. Each segment corresponds to one of today's
/// prayers and fills (`.primary`) when that prayer is logged with any
/// non-missed status. Missed/unlogged segments stay at the
/// `.tertiary` opacity so the ring is fully drawn.
///
/// Uses `Gauge(value:in:label:)` is too coarse for five distinct
/// segments, so we compose the ring manually from five arc paths.
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

            VStack(spacing: 0) {
                Image(systemName: lockSymbol(for: entry.nextPrayer))
                    .font(.system(size: 13, weight: .regular))
                Text("\(entry.loggedCountToday)/5")
                    .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(2)
        .widgetAccentable()
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

    private func lockSymbol(for prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return "sunrise"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.haze"
        case .maghrib: return "sunset"
        case .isha: return "moon.stars"
        }
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
        .description("Five-segment ring showing today's logged prayers.")
        .supportedFamilies([.accessoryCircular])
    }
}
