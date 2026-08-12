import AppIntents
import IhsanCore
import OSLog
import SwiftData

public struct ToggleJamaahIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle Jamāʿah"
    public static let description = IntentDescription("Toggle whether a prayer was performed in jamāʿah.")
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = true

    @Parameter(title: "Prayer")
    public var prayer: PrayerEntity

    /// The civil day whose entry is toggled. Nil means today.
    @Parameter(title: "Date")
    public var date: Date?

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "ToggleJamaahIntent"
    )
    private static let signposter = OSSignposter(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "ToggleJamaahIntent"
    )

    public init() {}

    public init(prayer: Prayer, date: Date? = nil) {
        self.prayer = PrayerEntity(prayer: prayer)
        self.date = date
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let signpostState = Self.signposter.beginInterval("perform")
        defer {
            Self.signposter.endInterval("perform", signpostState)
        }
        Self.logger.info("Invoked ToggleJamaahIntent")

        guard let prayer = prayer.prayer else {
            throw IntentError.invalidPrayer(prayer.id)
        }

        let container = try await ModelContainerAccess.shared.container()
        let context = ModelContext(container)
        let service = PrayerLogService()

        let log = try service.toggleJamaah(
            for: prayer,
            prayerDate: date,
            sourceSurface: .widget,
            in: context
        )

        WidgetSnapshotMirror.reflectPrayerLogs(in: context)
        await PrayerLogActivityHook.shared.notify(prayer: prayer, prayerDate: log.prayerDate)

        let dialog = log.withJamaah
            ? "\(prayer.displayNameEnglish) marked as jamāʿah."
            : "\(prayer.displayNameEnglish) jamāʿah cleared."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}
