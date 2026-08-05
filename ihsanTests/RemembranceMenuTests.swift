import Foundation
import IhsanCore
import IhsanPrayerTimes
import Testing
@testable import ihsan

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

    // MARK: - Time-aware catalogue

    @Test
    func middayDoesNotShowEitherTimeBoundSet() {
        let midAfternoon = entries(at: 14)
        #expect(!midAfternoon.contains { $0.destination == .set(.morning) })
        #expect(!midAfternoon.contains { $0.destination == .set(.evening) })
    }

    @Test
    func morningShowsMorningButNeverEvening() {
        let morning = entries(at: 6)
        #expect(morning.contains { $0.destination == .set(.morning) })
        #expect(!morning.contains { $0.destination == .set(.evening) })
    }

    @Test
    func eveningShowsEveningButNeverMorning() {
        let evening = entries(at: 17)
        #expect(evening.contains { $0.destination == .set(.evening) })
        #expect(!evening.contains { $0.destination == .set(.morning) })
    }

    @Test
    func occasionBoundActionsStayAvailable() {
        for hour in [6.0, 14.0, 17.0, 23.0] {
            let destinations = entries(at: hour).map(\.destination)
            #expect(destinations.contains(.set(.postPrayer)))
            #expect(destinations.contains(.set(.sleep)))
            #expect(destinations.contains(.freeTasbih))
        }
    }

    @Test
    func freeTasbihIsAlwaysLast() {
        #expect(entries(at: 6).last?.destination == .freeTasbih)
    }

    // MARK: - Emphasis

    @Test
    func theCurrentTimeSetIsTheOnlyFeaturedEntry() {
        let duringMorning = entries(at: 6)
        let morning = duringMorning.first { $0.destination == .set(.morning) }
        #expect(morning?.isCurrent == true)
        #expect(morning?.isFeatured == true)
        #expect(duringMorning.filter(\.isFeatured).count == 1)
    }

    @Test
    func nothingIsFeaturedWhenNoTimeWindowIsOpen() {
        #expect(entries(at: 14).allSatisfy { !$0.isFeatured })
    }

    @Test
    func afterPrayerCarriesNoWindow() {
        let entry = entries(at: 7).first { $0.destination == .set(.postPrayer) }
        #expect(entry?.window == nil)
        #expect(entry?.isCurrent == false)
        #expect(entry?.isFeatured == false)
    }

    @Test
    func sleepIsCurrentAtNightButRemainsSupporting() {
        let entry = entries(at: 23).first { $0.destination == .set(.sleep) }
        #expect(entry?.isCurrent == true)
        #expect(entry?.isFeatured == false)
    }

    @Test
    func freeTasbihCarriesNoWindow() {
        let entry = entries(at: 7).first { $0.destination == .freeTasbih }
        #expect(entry?.window == nil)
    }

    // MARK: - Scholar-review gate

    @Test
    func unavailableContentWithholdsEverySet() {
        let entries = RemembranceMenu.entries(
            now: time(7), windows: windows, isContentAvailable: false
        )
        #expect(entries.map(\.destination) == [.freeTasbih])
    }

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
