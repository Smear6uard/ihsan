import AppIntents
import IhsanCore
import OSLog
import SwiftData

/// The funnel's one way back: removes a prayer's record for the cycle in
/// progress (or for a given day).
///
/// It exists because the Today card records in one tap, and a one-tap
/// record is only safe when a mis-tap can be taken back in one tap. It
/// lives beside the logging intents rather than in a view so the dedup
/// key, the widget mirror and the Live Activity hook stay on the single
/// path every other write takes.
///
/// Not discoverable: it is the app's undo, not a shortcut anyone needs
/// to find.
public struct RemovePrayerLogIntent: AppIntent {
    public static let title: LocalizedStringResource = "Remove Prayer Log"
    public static let description = IntentDescription(
        "Remove a prayer's record for today, or for a given day."
    )
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = false

    @Parameter(title: "Prayer")
    public var prayer: PrayerEntity

    /// The cycle being edited. Nil means the cycle in progress.
    @Parameter(title: "Date")
    public var date: Date?

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "RemovePrayerLogIntent"
    )

    public init() {}

    public init(prayer: Prayer, date: Date? = nil) {
        self.prayer = PrayerEntity(prayer: prayer)
        self.date = date
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        Self.logger.info("Invoked RemovePrayerLogIntent")

        guard let prayer = prayer.prayer else {
            throw IntentError.invalidPrayer(prayer.id)
        }

        let container = try await ModelContainerAccess.shared.container()
        let context = ModelContext(container)
        let removed = try PrayerLogService().removeLog(
            for: prayer,
            prayerDate: date,
            in: context
        )

        WidgetSnapshotMirror.reflectPrayerLogs(in: context)

        let dialog = removed == nil
            ? "\(prayer.displayNameEnglish) has no record to remove."
            : "\(prayer.displayNameEnglish) record removed."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}
