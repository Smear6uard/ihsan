import Foundation
import IhsanCore
import IhsanPrayerTimes

/// Which remembrance set, if any, the day is offering right now.
///
/// Pure logic on purpose. Every rule about when a card appears —
/// the toggles, the windows, the pause, the dismissal, the review gate
/// — lives here and is tested here, rather than being spread across a
/// screen's `if` statements where nobody can check it.
enum AdhkarOffer {

    /// The windows of a single day, already resolved from its solar
    /// events.
    struct Windows: Equatable {
        var morning: AdhkarWindow?
        var evening: AdhkarWindow?
        var sleep: AdhkarWindow?

        func window(for category: AdhkarCategory) -> AdhkarWindow? {
            switch category {
            case .morning: morning
            case .evening: evening
            case .sleep: sleep
            case .postPrayer, .situational: nil
            }
        }
    }

    /// The person's preferences, lifted out of `UserSettings` so this
    /// stays testable without a store.
    struct Preferences: Equatable {
        var layerEnabled: Bool = false
        var morningEnabled: Bool = false
        var eveningEnabled: Bool = false
        var sleepEnabled: Bool = false

        init(
            layerEnabled: Bool = false,
            morningEnabled: Bool = false,
            eveningEnabled: Bool = false,
            sleepEnabled: Bool = false
        ) {
            self.layerEnabled = layerEnabled
            self.morningEnabled = morningEnabled
            self.eveningEnabled = eveningEnabled
            self.sleepEnabled = sleepEnabled
        }

        init(settings: UserSettings?) {
            self.init(
                layerEnabled: settings?.adhkarLayerEnabled ?? false,
                morningEnabled: settings?.adhkarMorningEnabled ?? false,
                eveningEnabled: settings?.adhkarEveningEnabled ?? false,
                sleepEnabled: settings?.adhkarSleepEnabled ?? false
            )
        }

        func isEnabled(_ category: AdhkarCategory) -> Bool {
            guard layerEnabled else { return false }
            switch category {
            case .morning: return morningEnabled
            case .evening: return eveningEnabled
            case .sleep: return sleepEnabled
            case .postPrayer, .situational: return false
            }
        }
    }

    struct Context {
        var now: Date
        var windows: Windows
        var preferences: Preferences
        /// The sleep set follows the prayer, not the hour.
        var isIshaLogged: Bool
        var isPaused: Bool
        var dismissedCategories: Set<AdhkarCategory>
        /// False while the content file is unreviewed in a release
        /// build — see `AdhkarAvailability`.
        var isContentAvailable: Bool
    }

    struct Offer: Equatable {
        var category: AdhkarCategory
        var window: AdhkarWindow
    }

    /// Builds remembrance windows from the prayer cycle in progress.
    /// The sleep set therefore spans its Isha through the Fajr that
    /// closes that cycle, even when midnight falls between them.
    static func windows(
        cycleDay: DayPrayerTimes,
        cycleEndFajr: Date,
        morningEndsAfterSunrise: TimeInterval,
        eveningExtendsAfterMaghrib: TimeInterval
    ) -> Windows {
        Windows(
            morning: AdhkarWindowResolver.morning(
                fajr: cycleDay.fajr.scheduledTime,
                sunrise: cycleDay.sunrise,
                dhuhr: cycleDay.dhuhr.scheduledTime,
                endsAfterSunrise: morningEndsAfterSunrise
            ),
            evening: AdhkarWindowResolver.evening(
                maghrib: cycleDay.maghrib.scheduledTime,
                isha: cycleDay.isha.scheduledTime,
                extendsAfterMaghrib: eveningExtendsAfterMaghrib
            ),
            sleep: AdhkarWindowResolver.sleep(
                isha: cycleDay.isha.scheduledTime,
                nextFajr: cycleEndFajr
            )
        )
    }

    /// **An excused pause does not suspend remembrance.**
    ///
    /// A pause suspends salah and fasting, because those are the things
    /// a person in that state is excused from. Dhikr and duʿāʾ are not
    /// among them — they are precisely what remains available, and
    /// taking them away would be the app deciding something it has no
    /// business deciding, at the moment a person is most likely to
    /// notice the app deciding it.
    ///
    /// This returns false for every category. It exists as a function
    /// rather than as the absence of a line of code so that the rule is
    /// written down once, is exercised by `AdhkarOfferTests`, and
    /// cannot be reintroduced by someone adding a pause check "for
    /// consistency".
    static func pauseSuppresses(_ category: AdhkarCategory) -> Bool {
        switch category {
        case .morning, .evening, .postPrayer, .sleep, .situational:
            false
        }
    }

    /// The order sets are considered in. The windows cannot overlap by
    /// construction, so this only decides a tie that should not arise.
    private static let considered: [AdhkarCategory] = [.morning, .evening, .sleep]

    static func offer(_ context: Context) -> Offer? {
        guard context.isContentAvailable else { return nil }

        for category in considered {
            guard context.preferences.isEnabled(category) else { continue }
            guard !context.dismissedCategories.contains(category) else { continue }
            guard !(context.isPaused && pauseSuppresses(category)) else { continue }
            guard let window = context.windows.window(for: category),
                  window.contains(context.now)
            else { continue }
            // The sleep set waits for the prayer it follows.
            if category == .sleep, !context.isIshaLogged { continue }
            return Offer(category: category, window: window)
        }
        return nil
    }
}

/// The cycle's dismissals, stored as presentation state — never worship
/// data. Encoded as `"2026-08-02:morning,evening"` so the next Fajr
/// clears them without anything having to run at a boundary.
enum AdhkarDismissal {

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0, components.month ?? 0, components.day ?? 0
        )
    }

    static func decode(_ stored: String, dayKey: String) -> Set<AdhkarCategory> {
        let parts = stored.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, parts[0] == dayKey else { return [] }
        return Set(
            parts[1]
                .split(separator: ",")
                .compactMap { AdhkarCategory(rawValue: String($0)) }
        )
    }

    static func encode(_ categories: Set<AdhkarCategory>, dayKey: String) -> String {
        let names = categories.map(\.rawValue).sorted().joined(separator: ",")
        return "\(dayKey):\(names)"
    }
}
