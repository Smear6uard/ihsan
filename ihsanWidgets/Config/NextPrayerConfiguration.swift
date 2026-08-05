import AppIntents
import Foundation
import IhsanCore
import WidgetKit

/// Which prayer the small Next Prayer widget follows.
enum PrayerChoice: String, AppEnum {
    case auto
    case fajr, dhuhr, asr, maghrib, isha

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Prayer")

    static let caseDisplayRepresentations: [PrayerChoice: DisplayRepresentation] = [
        .auto: DisplayRepresentation(title: "Next prayer"),
        .fajr: DisplayRepresentation(title: "Fajr"),
        .dhuhr: DisplayRepresentation(title: "Dhuhr"),
        .asr: DisplayRepresentation(title: "Asr"),
        .maghrib: DisplayRepresentation(title: "Maghrib"),
        .isha: DisplayRepresentation(title: "Isha"),
    ]

    var prayer: Prayer? {
        Prayer(rawValue: rawValue)
    }
}

struct NextPrayerConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Next Prayer"
    static let description = IntentDescription(
        "Follow the day's next prayer, or keep one prayer in view."
    )

    @Parameter(title: "Prayer", default: .auto)
    var prayer: PrayerChoice

    init() {}

    init(prayer: PrayerChoice) {
        self.prayer = prayer
    }
}

/// The configurable provider: identical entries to the static one,
/// with the chosen prayer stamped on so the face can pin its focus.
struct ConfigurablePrayerTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = PrayerTimelineEntry
    typealias Intent = NextPrayerConfigurationIntent

    func placeholder(in context: Context) -> PrayerTimelineEntry {
        PrayerTimelineProvider().placeholder(in: context)
    }

    func snapshot(
        for configuration: NextPrayerConfigurationIntent,
        in context: Context
    ) async -> PrayerTimelineEntry {
        var entry = context.isPreview
            ? PrayerTimelineProvider().placeholder(in: context)
            : WidgetTimelineComposer().entry(at: .now)
        entry.fixedPrayer = configuration.prayer.prayer
        return entry
    }

    func timeline(
        for configuration: NextPrayerConfigurationIntent,
        in context: Context
    ) async -> Timeline<PrayerTimelineEntry> {
        let timeline = WidgetTimelineComposer().timeline(from: .now)
        let entries = timeline.entries.map { entry in
            var stamped = entry
            stamped.fixedPrayer = configuration.prayer.prayer
            return stamped
        }
        return Timeline(entries: entries, policy: timeline.policy)
    }
}
