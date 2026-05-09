import AppIntents
import Foundation
import IhsanCore
import OSLog

public struct OpenReflectionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Begin Reflection"
    public static let description = IntentDescription("Open Ihsan and start a new reflection.")
    public static let openAppWhenRun: Bool = true
    public static let isDiscoverable: Bool = true

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "OpenReflectionIntent"
    )
    private static let signposter = OSSignposter(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "OpenReflectionIntent"
    )

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        let signpostState = Self.signposter.beginInterval("perform")
        defer {
            Self.signposter.endInterval("perform", signpostState)
        }
        Self.logger.info("Invoked OpenReflectionIntent")

        let defaults = UserDefaults(suiteName: IhsanModelContainerFactory.appGroupIdentifier)
        defaults?.set(Date.now.timeIntervalSince1970, forKey: "ihsan.deeplink.reflection.open")
        return .result()
    }
}
