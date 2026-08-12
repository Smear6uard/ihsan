import AppIntents
import IhsanCore
import OSLog
import SwiftData

public struct LogPrayerWithStatusIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Prayer with Status"
    public static let description = IntentDescription(
        "Log a prayer with an explicit status (on time, delayed, missed, or qada)."
    )
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = true

    @Parameter(title: "Prayer")
    public var prayer: PrayerEntity

    @Parameter(title: "Status")
    public var status: PrayerStatusEntity

    /// The civil day being logged. Nil means today; the Path ledger
    /// passes a past day for retroactive entries.
    @Parameter(title: "Date")
    public var date: Date?

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "LogPrayerWithStatusIntent"
    )
    private static let signposter = OSSignposter(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "LogPrayerWithStatusIntent"
    )

    public init() {}

    public init(prayer: Prayer, status: PrayerStatus, date: Date? = nil) {
        self.prayer = PrayerEntity(prayer: prayer)
        self.status = PrayerStatusEntity(status: status)
        self.date = date
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

        let log = try service.logPrayer(
            prayer,
            status: status,
            prayerDate: date,
            sourceSurface: .app,
            in: context
        )

        WidgetSnapshotMirror.reflectPrayerLogs(in: context)
        await PrayerLogActivityHook.shared.notify(prayer: prayer, prayerDate: log.prayerDate)

        let dialogText: String = {
            switch status {
            case .onTime:
                return "\(prayer.displayNameEnglish) logged \(status.spokenLabel)."
            case .late, .qada:
                return "\(prayer.displayNameEnglish) logged as \(status.spokenLabel)."
            case .missed:
                return "\(prayer.displayNameEnglish) marked as \(status.spokenLabel)."
            }
        }()

        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}
