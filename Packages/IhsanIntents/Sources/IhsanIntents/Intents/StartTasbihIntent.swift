import AppIntents
import Foundation
import IhsanCore
import OSLog

/// Opens Ihsan onto the tasbīḥ instrument. The Siri / Shortcuts entry
/// point ("Start tasbīḥ in Ihsan") — the in-app entry is the logged
/// card's quiet TASBĪḤ link, which posts the same notification.
public struct StartTasbihIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Tasbīḥ"
    public static let description = IntentDescription("Open Ihsan and begin a tasbīḥ count.")
    public static let openAppWhenRun: Bool = true
    public static let isDiscoverable: Bool = true

    /// Posted after the deeplink flag is written, for the in-app
    /// router (RootTabView) — same pattern as `OpenReflectionIntent`.
    public static let inAppNotificationName = Notification.Name(
        "com.sameerstudios.ihsan.tasbih.open"
    )

    /// App Group UserDefaults key carrying the most recent open
    /// request's timestamp, for the cold-launch path.
    public static let deeplinkUserDefaultsKey = "ihsan.deeplink.tasbih.open"

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "StartTasbihIntent"
    )

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        Self.logger.info("Invoked StartTasbihIntent")
        let defaults = UserDefaults(suiteName: IhsanModelContainerFactory.appGroupIdentifier)
        defaults?.set(Date.now.timeIntervalSince1970, forKey: Self.deeplinkUserDefaultsKey)
        NotificationCenter.default.post(name: Self.inAppNotificationName, object: nil)
        return .result()
    }
}
