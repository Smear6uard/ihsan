import AppIntents
import IhsanCore
import OSLog
import SwiftData

public struct ToggleJamaahIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle Jama'ah"
    public static let description = IntentDescription("Toggle whether a prayer was performed in jama'ah.")
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = true

    @Parameter(title: "Prayer")
    public var prayer: PrayerEntity

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "ToggleJamaahIntent"
    )
    private static let signposter = OSSignposter(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "ToggleJamaahIntent"
    )

    public init() {}

    public init(prayer: Prayer) {
        self.prayer = PrayerEntity(prayer: prayer)
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
            sourceSurface: .widget,
            in: context
        )

        let dialog = log.withJamaah
            ? "\(prayer.displayNameEnglish) marked as jama'ah."
            : "\(prayer.displayNameEnglish) jama'ah cleared."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}
