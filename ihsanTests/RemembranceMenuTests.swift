import Foundation
import IhsanCore
import IhsanPrayerTimes
import Testing
@testable import ihsan

/// The rules for the always-open door to remembrance.
@Suite("Remembrance menu")
struct RemembranceMenuTests {

    private func time(_ hour: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: 700_000_000 + hour * 3600)
    }

    private var windows: AdhkarOffer.Windows {
        AdhkarOffer.Windows(
            morning: AdhkarWindowResolver.morning(
                fajr: time(5), sunrise: time(6.5), dhuhr: time(12.5),
                endsAfterSunrise: 90 * 60
            ),
            evening: AdhkarWindowResolver.evening(
                asr: time(16), maghrib: time(19.5), isha: time(21),
                extendsAfterMaghrib: 60 * 60
            ),
            sleep: AdhkarWindowResolver.sleep(isha: time(21), nextFajr: time(29))
        )
    }

    private func entries(at hour: Double) -> [RemembranceMenu.Entry] {
        RemembranceMenu.entries(
            now: time(hour), windows: windows, isContentAvailable: true
        )
    }

    // MARK: - The rule the hub exists for

    /// Every set is reachable at every hour. The per-window toggles
    /// govern whether the app *offers* a set unprompted; they were never
    /// meant to govern whether someone who goes looking can find one.
    @Test
    func everySetIsListedOutsideItsWindow() {
        // 2pm: no remembrance window is open at all.
        let midAfternoon = entries(at: 14)
        for category in RemembranceMenu.setOrder {
            #expect(
                midAfternoon.contains { $0.destination == .set(category) },
                "\(category) must be reachable outside its window"
            )
        }
    }

    @Test
    func theListDoesNotChangeWithTheHour() {
        let morning = entries(at: 6).map(\.id)
        let night = entries(at: 23).map(\.id)
        #expect(morning == night)
    }

    @Test
    func freeTasbihIsAlwaysLast() {
        #expect(entries(at: 6).last?.destination == .freeTasbih)
    }

    @Test
    func setsAreListedInTheDaysOwnOrder() {
        let sets = entries(at: 14).compactMap { entry -> AdhkarCategory? in
            if case .set(let category) = entry.destination { return category }
            return nil
        }
        #expect(sets == [.morning, .evening, .postPrayer, .sleep])
    }

    // MARK: - Windows are shown, not enforced

    @Test
    func aSetInsideItsWindowIsMarkedCurrent() {
        let duringMorning = entries(at: 7)
        let morning = duringMorning.first { $0.destination == .set(.morning) }
        #expect(morning?.isCurrent == true)

        let evening = duringMorning.first { $0.destination == .set(.evening) }
        #expect(evening?.isCurrent == false)
    }

    @Test
    func nothingIsCurrentWhenNoWindowIsOpen() {
        #expect(entries(at: 14).allSatisfy { !$0.isCurrent })
    }

    /// The after-prayer set follows a prayer, not a clock, so it carries
    /// no window and can never be marked current by the hour.
    @Test
    func afterPrayerCarriesNoWindow() {
        let entry = entries(at: 7).first { $0.destination == .set(.postPrayer) }
        #expect(entry?.window == nil)
        #expect(entry?.isCurrent == false)
    }

    @Test
    func freeTasbihCarriesNoWindow() {
        let entry = entries(at: 7).first { $0.destination == .freeTasbih }
        #expect(entry?.window == nil)
    }

    // MARK: - The scholar-review gate

    /// Unreviewed content in a release build surfaces no text at all.
    /// The instrument survives — it has nothing to read.
    @Test
    func unavailableContentWithholdsEverySet() {
        let entries = RemembranceMenu.entries(
            now: time(7), windows: windows, isContentAvailable: false
        )
        #expect(entries.map(\.destination) == [.freeTasbih])
    }

    /// And in that state the door does not open a hub of one row.
    @Test
    func theHubOnlyOpensWhenThereIsSomethingToList() {
        #expect(RemembranceMenu.showsHub(isContentAvailable: true))
        #expect(!RemembranceMenu.showsHub(isContentAvailable: false))
    }

    // MARK: - Copy

    @Test
    func titlesNameTheSetWithoutSayingAdhkarTwice() {
        #expect(RemembranceMenu.title(for: .morning) == "Morning adhkār")
        #expect(RemembranceMenu.title(for: .evening) == "Evening adhkār")
        #expect(RemembranceMenu.title(for: .postPrayer) == "After prayer")
        #expect(RemembranceMenu.title(for: .sleep) == "Before sleep")
    }
}
