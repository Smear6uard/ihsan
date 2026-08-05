import Foundation
import IhsanCore
import IhsanPrayerTimes

/// What the always-open door to remembrance offers at this moment.
///
/// Morning and evening adhkār are clock-bound, so the menu shows at
/// most one of them and only while its window is open. Occasion-bound
/// remembrance remains available beneath it: after prayer, before
/// sleep, and the free tasbīḥ instrument.
enum RemembranceMenu {

    struct Entry: Equatable, Identifiable {
        enum Destination: Equatable {
            case set(AdhkarCategory)
            case freeTasbih
        }

        var destination: Destination
        var title: String
        var window: AdhkarWindow?
        var isCurrent: Bool = false
        /// The one time-of-day set for this moment. It receives the
        /// sheet's visual emphasis; occasion-bound actions stay quiet.
        var isFeatured: Bool = false

        var id: String {
            switch destination {
            case .set(let category): "set-\(category.rawValue)"
            case .freeTasbih: "free-tasbih"
            }
        }
    }

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
            if let category = currentTimeCategory(now: now, windows: windows),
               let window = windows.window(for: category) {
                entries.append(
                    Entry(
                        destination: .set(category),
                        title: title(for: category),
                        window: window,
                        isCurrent: true,
                        isFeatured: true
                    )
                )
            }

            entries.append(
                Entry(
                    destination: .set(.postPrayer),
                    title: title(for: .postPrayer)
                )
            )
            entries.append(
                Entry(
                    destination: .set(.sleep),
                    title: title(for: .sleep),
                    window: windows.sleep,
                    isCurrent: windows.sleep?.contains(now) ?? false
                )
            )
        }

        entries.append(
            Entry(destination: .freeTasbih, title: "Free tasbīḥ", window: nil)
        )
        return entries
    }

    /// Sleep remains an occasion-bound action even while its window is
    /// open, because it follows intent to sleep rather than merely the
    /// hour.
    private static func currentTimeCategory(
        now: Date,
        windows: AdhkarOffer.Windows
    ) -> AdhkarCategory? {
        if windows.morning?.contains(now) == true { return .morning }
        if windows.evening?.contains(now) == true { return .evening }
        return nil
    }

    static func title(for category: AdhkarCategory) -> String {
        switch category {
        case .morning, .evening:
            "\(category.displayName) adhkār"
        case .postPrayer, .sleep, .situational:
            category.displayName
        }
    }
}
