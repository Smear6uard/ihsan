import Foundation
import IhsanCore

/// URL constants the widget hands to the system on tap.
///
/// The host app receives these in `RootTabView.onOpenURL`, parses
/// them with `WidgetDeeplinkRouter`, and the Today screen presents
/// the destination through its own sheet states.
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
}
