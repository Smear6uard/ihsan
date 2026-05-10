import AppIntents
import Foundation
import IhsanCore
import OSLog

public struct OpenReflectionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Begin Reflection"
    public static let description = IntentDescription("Open Ihsan and start a new reflection.")
    public static let openAppWhenRun: Bool = true
    public static let isDiscoverable: Bool = true

    /// Notification posted after the deeplink flag is written. The
    /// in-app router (RootTabView) listens for this so a tap on the
    /// Today screen's "Begin" button switches tabs immediately, without
    /// waiting for a scene-phase transition. The cold-launch path
    /// (Siri / Shortcut) still works through the App Group flag —
    /// nobody is listening to the notification yet at launch time.
    public static let inAppNotificationName = Notification.Name(
        "com.sameerstudios.ihsan.reflection.open"
    )

    /// App Group UserDefaults key that stores the timestamp of the most
    /// recent open request. Read by the Reflection screen on appear and
    /// on scene-phase active to auto-focus the input.
    public static let deeplinkUserDefaultsKey = "ihsan.deeplink.reflection.open"

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
        defaults?.set(Date.now.timeIntervalSince1970, forKey: Self.deeplinkUserDefaultsKey)
        NotificationCenter.default.post(name: Self.inAppNotificationName, object: nil)
        return .result()
    }
}
