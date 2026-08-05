import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Lock screen rectangular — the day row: five mini ornaments in
/// state, each over its hour. The whole day in one line.
struct DayRowRectangularWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        switch entry.content {
        case .live(let day):
            let model = day.faceModel(at: entry.date)
            AccessoryDayRowFace(
                slots: model.slots,
                timeZoneIdentifier: model.timeZoneIdentifier
            )
        case .invitation(let invitation):
            VStack(alignment: .leading, spacing: 2) {
                Text(invitation.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .widgetAccentable()
                Text(invitation.line)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct DayRowRectangularWidget: Widget {
    static let kind: String = "DayRowRectangularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            DayRowRectangularWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("The Day Row")
        .description("All five prayers and their hours, in one line.")
        .supportedFamilies([.accessoryRectangular])
    }
}
