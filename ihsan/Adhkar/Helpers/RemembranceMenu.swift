import Foundation
import IhsanCore
import IhsanPrayerTimes

/// What the always-open door to remembrance offers.
///
/// Pure logic, in the shape of `AdhkarOffer` and for the same reason:
/// the rules about what a person can reach — and the one rule about
/// what they cannot — belong somewhere a test can read them, not spread
/// through a screen's `if` statements.
///
/// ## The rule this exists to state
///
/// **The hub lists every set, whatever the per-window toggles say.**
///
/// Those toggles govern the *automatic offer card* — whether the app
/// mentions the morning set at seven in the morning, unprompted. They
/// were never meant to govern whether a person who goes looking for the
/// evening adhkār at midnight is allowed to find them. Before this
/// existed, they did: adhkār were reachable only from a live window's
/// card, so wanting to read a set outside its window meant there was no
/// way in at all.
///
/// The windows still appear beside the sets that have one today, so the
/// hub keeps teaching when each set belongs. It just stops enforcing it.
enum RemembranceMenu {

    /// One row in the hub.
    struct Entry: Equatable, Identifiable {
        enum Destination: Equatable {
            case set(AdhkarCategory)
            /// The tasbīḥ instrument — counting with no text to read.
            case freeTasbih
        }

        var destination: Destination
        var title: String
        /// The set's window today, when it has one. Nil for the
        /// after-prayer set (which follows a prayer, not a clock) and
        /// for free tasbīḥ (which follows nothing).
        var window: AdhkarWindow?
        /// True while `now` falls inside `window` — the hub marks the
        /// set whose time it is rather than reordering the list, so the
        /// rows never move under a finger.
        var isCurrent: Bool = false

        var id: String {
            switch destination {
            case .set(let category): "set-\(category.rawValue)"
            case .freeTasbih: "free-tasbih"
            }
        }
    }

    /// The order the sets are listed in: the day's own order, morning
    /// through night, with the prayer-bound set in the middle where it
    /// falls. Not sorted by proximity — a list that reorders itself is a
    /// list you have to re-read every time.
    static let setOrder: [AdhkarCategory] = [.morning, .evening, .postPrayer, .sleep]

    /// Whether the door should open a hub at all.
    ///
    /// With the content unavailable — the scholar-review gate in a
    /// release build — every set row is withheld, and a hub containing
    /// one row is not a hub. The door goes straight to the instrument
    /// instead, and says so by being labelled `Tasbīḥ`.
    static func showsHub(isContentAvailable: Bool) -> Bool {
        isContentAvailable
    }

    static func entries(
        now: Date,
        windows: AdhkarOffer.Windows,
        isContentAvailable: Bool
    ) -> [Entry] {
        var entries: [Entry] = []

        if isContentAvailable {
            for category in setOrder {
                let window = windows.window(for: category)
                entries.append(
                    Entry(
                        destination: .set(category),
                        title: title(for: category),
                        window: window,
                        isCurrent: window?.contains(now) ?? false
                    )
                )
            }
        }

        entries.append(
            Entry(destination: .freeTasbih, title: "Free tasbīḥ", window: nil)
        )
        return entries
    }

    /// Named in full, the way the offer card names itself, so a row
    /// read out of the corner of an eye says what it is. "After prayer"
    /// and "Before sleep" already read as adhkār and do not take the
    /// word twice.
    static func title(for category: AdhkarCategory) -> String {
        switch category {
        case .morning, .evening:
            "\(category.displayName) adhkār"
        case .postPrayer, .sleep, .situational:
            category.displayName
        }
    }
}
