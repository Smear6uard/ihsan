import AppIntents
import IhsanCore
import OSLog
import SwiftData

public struct LogPrayerWithStatusIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Prayer with Status"
    public static let description = IntentDescription(
        "Log a prayer with an explicit status (on time, late, missed, or qada)."
    )
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = true

    @Parameter(title: "Prayer")
    public var prayer: PrayerEntity

    @Parameter(title: "Status")
    public var status: PrayerStatusEntity

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "LogPrayerWithStatusIntent"
    )
    private static let signposter = OSSignposter(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "LogPrayerWithStatusIntent"
    )

    public init() {}

    public init(prayer: Prayer, status: PrayerStatus) {
        self.prayer = PrayerEntity(prayer: prayer)
        self.status = PrayerStatusEntity(status: status)
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let signpostState = Self.signposter.beginInterval("perform")
        defer {
            Self.signposter.endInterval("perform", signpostState)
        }
        Self.logger.info("Invoked LogPrayerWithStatusIntent")

        guard let prayer = prayer.prayer else {
            throw IntentError.invalidPrayer(prayer.id)
        }
        guard let status = status.status else {
            throw IntentError.invalidStatus(status.id)
        }

        let container = try await ModelContainerAccess.shared.container()
        let context = ModelContext(container)
        let service = PrayerLogService()

        _ = try service.logPrayer(
            prayer,
            status: status,
            sourceSurface: .app,
            in: context
        )

        let dialogText: String = {
            switch status {
            case .onTime:
                return "\(prayer.displayNameEnglish) logged on time."
            case .late:
                return "\(prayer.displayNameEnglish) logged as late."
            case .missed:
                return "\(prayer.displayNameEnglish) marked as missed."
            case .qada:
                return "\(prayer.displayNameEnglish) logged as qada."
            }
        }()

        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}
