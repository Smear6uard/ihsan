import Foundation
import IhsanCore

/// Routing flag written by `OpenReflectionIntent` and read by the Reflection
/// surface to auto-focus the input. The flag is a timestamp, not a boolean,
/// so we can distinguish a fresh request from an old one that was never
/// cleared (e.g. the app crashed during the auto-focus handoff).
///
/// The flag survives a process relaunch — `UserDefaults` for the App Group
/// suite persists across launches — so the cold-launch path (Siri /
/// Shortcuts) and the warm-launch path (in-app tap) both flow through it.
enum ReflectionDeeplink {
    static let userDefaultsKey = "ihsan.deeplink.reflection.open"
    static let inAppNotificationName = Notification.Name(
        "com.sameerstudios.ihsan.reflection.open"
    )

    /// A request is considered fresh for one minute. Anything older is
    /// stale and ignored — prevents us from auto-focusing input the user
    /// never asked for.
    static let freshnessWindow: TimeInterval = 60

    private static var defaults: UserDefaults? {
        UserDefaults(
            suiteName: IhsanModelContainerFactory.appGroupIdentifier
        )
    }

    /// Returns true if a fresh deeplink request is currently pending.
    /// Does not clear the flag — call `clear()` after the consumer has
    /// acted on the request.
    static func isFresh(now: Date = .now) -> Bool {
        guard let defaults,
              let stored = defaults.object(forKey: userDefaultsKey) as? Double
        else {
            return false
        }
        let age = now.timeIntervalSince1970 - stored
        return age >= 0 && age <= freshnessWindow
    }

    /// Clears the deeplink flag. Called by the terminal consumer (the
    /// reflection input) once auto-focus has been applied.
    static func clear() {
        defaults?.removeObject(forKey: userDefaultsKey)
    }
}
