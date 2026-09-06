import Foundation
import IhsanCore

/// The widget family's URL routes into the app.
///
/// Every widget declares one destination via `widgetURL`/`Link`; the
/// app parses it here and forwards through the same
/// NotificationCenter pattern the Siri intents use, so the Today
/// screen presents its own sheets and no second presentation path
/// exists. Unknown or malformed URLs quietly land on Today — a tap on
/// a widget must never dead-end.
enum WidgetDeeplinkRouter {
    enum Destination: Equatable, Sendable {
        /// The Today screen itself — also the "night state": at night
        /// Today's plate and focused card are the night surface.
        case today
        case qibla
        case hijri
        case logSheet(Prayer)
    }

    static let notificationName = Notification.Name("ihsan.widget.deeplink")
    static let destinationKey = "destination"

    /// `ihsan://today`, `ihsan://today?qibla=1`, `?hijri=1`,
    /// `?night=1`, `?log=<prayer>`.
    static func destination(for url: URL) -> Destination? {
        guard url.scheme?.lowercased() == "ihsan" else { return nil }
        guard url.host()?.lowercased() == "today" else { return .today }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems ?? []
        for item in queryItems {
            switch item.name.lowercased() {
            case "qibla" where item.value == "1":
                return .qibla
            case "hijri" where item.value == "1":
                return .hijri
            case "night" where item.value == "1":
                return .today
            case "log":
                if let raw = item.value, let prayer = Prayer(rawValue: raw) {
                    return .logSheet(prayer)
                }
            default:
                continue
            }
        }
        return .today
    }

    /// The destination of a tap that arrived before Today was on
    /// screen — a cold launch from a widget. Today takes it on appear;
    /// a warm launch is served by the notification and leaves this nil.
    @MainActor
    private(set) static var pending: Destination?

    @MainActor
    static func post(_ destination: Destination) {
        pending = destination
        NotificationCenter.default.post(
            name: notificationName,
            object: nil,
            userInfo: [destinationKey: destination]
        )
    }

    /// Hands over and clears whatever a cold launch left behind.
    @MainActor
    static func takePending() -> Destination? {
        defer { pending = nil }
        return pending
    }
}
