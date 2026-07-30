import SwiftUI
import WidgetKit
import IhsanCore
import IhsanDesignSystem

/// Rectangular complication: full prayer list with the upcoming
/// prayer highlighted. Designed to fit the modular face's rectangular
/// slot — three rows max in practice, so we condense onto two rows
/// of compact prayer-time pairs.
struct PrayerListRectangularWidget: Widget {
    let kind: String = "ihsan.complications.prayer-list-rectangular"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            PrayerListRectangularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Prayers")
        .description("Today's five prayers with the next highlighted.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct PrayerListRectangularView: View {
    let entry: ComplicationEntry

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        f.timeZone = TimeZone(identifier: entry.timeZoneIdentifier)
        return f
    }

    var body: some View {
        if entry.isStale || entry.dayPrayerTimes.isEmpty {
            stalePlaceholder
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                ForEach(top, id: \.self) { prayer in
                    cell(prayer: prayer)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack(spacing: 4) {
                ForEach(bottom, id: \.self) { prayer in
                    cell(prayer: prayer)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var top: [Prayer] {
        [.fajr, .dhuhr, .asr]
    }

    private var bottom: [Prayer] {
        [.maghrib, .isha]
    }

    private func cell(prayer: Prayer) -> some View {
        let isNext = prayer == entry.nextPrayer
        let scheduled = entry.dayPrayerTimes[prayer]

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                Text(prayer.displayNameEnglish.prefix(3).uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(
                        isNext ? IhsanColor.textPrimary : IhsanColor.textMuted
                    )
                if let status = entry.loggedStatuses[prayer] {
                    Circle()
                        .fill(statusFill(status))
                        .frame(width: 4, height: 4)
                }
            }
            if let scheduled {
                let timeText = Text(timeFormatter.string(from: scheduled))
                    .font(.system(size: 11, weight: isNext ? .semibold : .regular,
                                  design: .rounded).monospacedDigit())
                    .foregroundStyle(
                        isNext ? IhsanColor.textPrimary : IhsanColor.textSecondary
                    )

                if isNext {
                    timeText.widgetAccentable()
                } else {
                    timeText
                }
            } else {
                Text("—")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(IhsanColor.textMuted)
            }
        }
    }

    private var stalePlaceholder: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Open Ihsan")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(IhsanColor.textPrimary)
            Text("to refresh prayer times")
                .font(.system(size: 10))
                .foregroundStyle(IhsanColor.textMuted)
        }
    }

    private func statusFill(_ status: PrayerStatus) -> Color {
        switch status {
        case .onTime: IhsanColor.statusOnTime
        case .late: IhsanColor.statusLate
        case .missed: IhsanColor.statusMissed
        case .qada: IhsanColor.statusQada
        }
    }
}
