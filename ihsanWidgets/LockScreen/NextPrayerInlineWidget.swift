import AppIntents
import IhsanCore
import SwiftUI
import WidgetKit

/// Lock screen inline — a single line above the clock: the next
/// prayer's name with its hour, or with the time remaining. The
/// system renders one line of text at text scale; at that size an
/// ornament is indistinguishable from a smudge, so this line is words
/// and figures only.
struct NextPrayerInlineWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        switch entry.content {
        case .live(let day):
            if entry.inlineShowsCountdown, let countdown = entry.nextPrayerCountdown {
                Text("\(day.nextPrayer.displayNameEnglish) in \(Text(timerInterval: countdown, countsDown: true))")
                    .monospacedDigit()
            } else {
                Text("\(day.nextPrayer.displayNameEnglish) · \(day.clockTime(day.nextPrayerTime))")
                    .font(.system(.body, design: .rounded).monospacedDigit())
            }
        case .invitation(let invitation):
            Text("\(invitation.title) \(invitation.line)")
        }
    }
}

/// How the inline form reads.
enum InlineStyle: String, AppEnum {
    case time
    case countdown

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Form")
    static let caseDisplayRepresentations: [InlineStyle: DisplayRepresentation] = [
        .time: DisplayRepresentation(title: "Prayer and time"),
        .countdown: DisplayRepresentation(title: "Prayer and countdown"),
    ]
}

struct InlineConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Next Prayer Line"
    static let description = IntentDescription("Show the hour, or the time remaining.")

    @Parameter(title: "Form", default: .time)
    var style: InlineStyle

    init() {}
}

struct InlineTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = PrayerTimelineEntry
    typealias Intent = InlineConfigurationIntent

    func placeholder(in context: Context) -> PrayerTimelineEntry {
        PrayerTimelineProvider().placeholder(in: context)
    }

    func snapshot(
        for configuration: InlineConfigurationIntent,
        in context: Context
    ) async -> PrayerTimelineEntry {
        var entry = context.isPreview
            ? PrayerTimelineProvider().placeholder(in: context)
            : WidgetTimelineComposer().entry(at: .now)
        entry.inlineShowsCountdown = configuration.style == .countdown
        return entry
    }

    func timeline(
        for configuration: InlineConfigurationIntent,
        in context: Context
    ) async -> Timeline<PrayerTimelineEntry> {
        let timeline = WidgetTimelineComposer().timeline(from: .now)
        let entries = timeline.entries.map { entry in
            var stamped = entry
            stamped.inlineShowsCountdown = configuration.style == .countdown
            return stamped
        }
        return Timeline(entries: entries, policy: timeline.policy)
    }
}

struct NextPrayerInlineWidget: Widget {
    static let kind: String = "NextPrayerInlineWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: InlineConfigurationIntent.self,
            provider: InlineTimelineProvider()
        ) { entry in
            NextPrayerInlineWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Next Prayer (Inline)")
        .description("Above the lock screen clock — the next prayer, as an hour or a countdown.")
        .supportedFamilies([.accessoryInline])
    }
}
