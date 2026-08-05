import AppIntents
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif
import IhsanCore
import OSLog
import SwiftData

public struct LogPrayerIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Prayer"
    public static let description = IntentDescription("Log a prayer as completed on time.")
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = true

    @Parameter(
        title: "Prayer",
        description: "Which prayer to log",
        requestValueDialog: "Which prayer would you like to log?"
    )
    public var prayer: PrayerEntity

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "LogPrayerIntent"
    )
    private static let signposter = OSSignposter(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "LogPrayerIntent"
    )

    public init() {}

    public init(prayer: Prayer) {
        self.prayer = PrayerEntity(prayer: prayer)
    }

    init(prayerEntity: PrayerEntity) {
        self.prayer = prayerEntity
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let signpostState = Self.signposter.beginInterval("perform")
        defer {
            Self.signposter.endInterval("perform", signpostState)
        }
        Self.logger.info("Invoked LogPrayerIntent")

        guard let prayer = prayer.prayer else {
            throw IntentError.invalidPrayer(prayer.id)
        }

        let container = try await ModelContainerAccess.shared.container()
        let context = ModelContext(container)
        let service = PrayerLogService()

        _ = try service.logPrayer(
            prayer,
            status: .onTime,
            sourceSurface: .siri,
            in: context
        )

        WidgetSnapshotMirror.reflectPrayerLogs(in: context)

        return .result(dialog: IntentDialog("\(prayer.displayNameEnglish) logged."))
    }
}

#if canImport(ActivityKit) && os(iOS)
extension LogPrayerIntent: LiveActivityIntent {}
#endif
