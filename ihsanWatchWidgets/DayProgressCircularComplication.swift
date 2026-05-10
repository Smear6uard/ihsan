import SwiftUI
import WidgetKit
import IhsanCore
import IhsanDesignSystem

/// Circular complication: 5-segment ring expressing today's logged
/// completion. Each segment maps to one fardh prayer. Fill style is
/// driven by status — solid for on-time, dim for late, hairline for
/// missed, brass-tinted for qada.
struct DayProgressCircularWidget: Widget {
    let kind: String = "ihsan.complications.day-progress-circular"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            DayProgressCircularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Day Progress")
        .description("Today's prayer completion at a glance.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct DayProgressCircularView: View {
    let entry: ComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            ZStack {
                // The 5 segments are drawn with a small gap between
                // them so the divisions read as discrete prayers.
                ForEach(Array(PrayerListOrder.all.enumerated()), id: \.offset) { index, prayer in
                    SegmentedRingArc(
                        index: index,
                        total: PrayerListOrder.all.count,
                        gapAngle: 6
                    )
                    .stroke(
                        fillColor(for: prayer),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                }

                // Compact "n/5" text in the middle for a numeric anchor.
                let logged = entry.loggedStatuses.values.filter { $0 != .missed }.count
                Text("\(logged)/5")
                    .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                    .widgetAccentable()
            }
            .padding(4)
        }
        .accessibilityLabel("Today's prayers")
        .accessibilityValue(accessibilityValue)
    }

    private func fillColor(for prayer: Prayer) -> Color {
        switch entry.loggedStatuses[prayer] {
        case .onTime: return IhsanColor.statusOnTime
        case .late: return IhsanColor.statusLate
        case .missed: return IhsanColor.statusMissed
        case .qada: return IhsanColor.statusQada
        case nil: return IhsanColor.atmospheric
        }
    }

    private var accessibilityValue: String {
        let counts = PrayerStatus.allCases.map { status -> (PrayerStatus, Int) in
            (status, entry.loggedStatuses.values.filter { $0 == status }.count)
        }
        let parts = counts
            .filter { $0.1 > 0 }
            .map { "\($0.1) \(label($0.0))" }
        return parts.isEmpty ? "Nothing logged yet today." : parts.joined(separator: ", ")
    }

    private func label(_ status: PrayerStatus) -> String {
        switch status {
        case .onTime: "on time"
        case .late: "late"
        case .missed: "missed"
        case .qada: "qada"
        }
    }
}

/// Draws one segment of the 5-segment ring, sweeping from `startAngle`
/// to `endAngle` with a gap before the next segment so segments read
/// as discrete prayer slots rather than a continuous gauge.
private struct SegmentedRingArc: Shape {
    let index: Int
    let total: Int
    let gapAngle: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 2
        let segmentAngle = (360.0 - Double(total) * gapAngle) / Double(total)
        // Start at -90° (top of circle), advance clockwise.
        let start = -90.0 + Double(index) * (segmentAngle + gapAngle)
        let end = start + segmentAngle

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(start),
            endAngle: .degrees(end),
            clockwise: false
        )
        return path
    }
}

private enum PrayerListOrder {
    static let all: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
}
