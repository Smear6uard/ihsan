import Foundation
import IhsanCore

/// URL constants the widget hands to the system on tap.
///
/// The host app intercepts these in `onOpenURL` to navigate to the
/// correct screen. The qibla deeplink also writes a freshness-stamped
/// flag to the shared App Group `UserDefaults` so the receiving screen
/// can distinguish a deliberate widget tap from a stale URL replay.
///
/// Mirrors the pattern in `ReflectionDeeplink` used by Siri intents.
enum WidgetDeeplink {
    static let scheme = "ihsan"

    /// Generic "open the app to Today" tap target.
    static var today: URL {
        URL(string: "\(scheme)://today")!
    }

    /// "Open Today and present the qibla sheet" — the destination of the
    /// qibla indicator on the large home widget.
    static var qibla: URL {
        URL(string: "\(scheme)://today?qibla=1")!
    }

    /// "Open Today and present the Hijri month sheet" — the Hijri
    /// widget's destination.
    static var hijri: URL {
        URL(string: "\(scheme)://today?hijri=1")!
    }

    /// "Open Today scrolled to the night's state" — the night
    /// accessory's destination.
    static var night: URL {
        URL(string: "\(scheme)://today?night=1")!
    }

    /// The log sheet for one prayer — the destination of a passed
    /// prayer's mark, where the app asks the status question properly.
    static func logSheet(for prayer: Prayer) -> URL {
        URL(string: "\(scheme)://today?log=\(prayer.rawValue)")!
    }

    /// Marks a fresh "qibla requested via widget" intent. The Today
    /// surface reads this on launch and clears it after presenting.
    enum QiblaFlag {
        static let userDefaultsKey = "ihsan.deeplink.qibla.open"
        static let freshnessWindow: TimeInterval = 60

        static func markFresh(now: Date = .now) {
            UserDefaults(suiteName: IhsanModelContainerFactory.appGroupIdentifier)?
                .set(now.timeIntervalSince1970, forKey: userDefaultsKey)
        }

        static func isFresh(now: Date = .now) -> Bool {
            guard
                let defaults = UserDefaults(
                    suiteName: IhsanModelContainerFactory.appGroupIdentifier
                ),
                let stored = defaults.object(forKey: userDefaultsKey) as? Double
            else {
                return false
            }
            let age = now.timeIntervalSince1970 - stored
            return age >= 0 && age <= freshnessWindow
        }

        static func clear() {
            UserDefaults(suiteName: IhsanModelContainerFactory.appGroupIdentifier)?
                .removeObject(forKey: userDefaultsKey)
        }
    }
}
