import AppIntents
import Foundation
import IhsanCore
import OSLog
import SwiftData

public struct MarkAsQadaIntent: AppIntent {
    public static let title: LocalizedStringResource = "Mark as Qada"
    public static let description = IntentDescription("Mark a missed prayer as made up.")
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = true

    @Parameter(
        title: "Original Log ID",
        description: "The identifier for the missed prayer log to mark as qada."
    )
    public var originalLogID: String

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "MarkAsQadaIntent"
    )
    private static let signposter = OSSignposter(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "MarkAsQadaIntent"
    )

    public init() {}

    public init(originalLogID: String) {
        self.originalLogID = originalLogID
    }

    public init(originalLogID: UUID) {
        self.originalLogID = originalLogID.uuidString
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let signpostState = Self.signposter.beginInterval("perform")
        defer {
            Self.signposter.endInterval("perform", signpostState)
        }
        Self.logger.info("Invoked MarkAsQadaIntent")

        guard let uuid = UUID(uuidString: originalLogID) else {
            throw IntentError.invalidPrayer(originalLogID)
        }

        let container = try await ModelContainerAccess.shared.container()
        let context = ModelContext(container)
        let service = PrayerLogService()

        let log = try service.markAsQada(
            originalLogID: uuid,
            sourceSurface: .app,
            in: context
        )

        let prayerName = log.prayer?.displayNameEnglish ?? "Prayer"
        return .result(dialog: IntentDialog("\(prayerName) marked as qada."))
    }
}
