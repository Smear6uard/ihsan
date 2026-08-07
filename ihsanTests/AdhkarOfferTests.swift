import Foundation
import IhsanCore
import IhsanPrayerTimes
import Testing
@testable import ihsan

/// Every rule about when a remembrance card appears, held in one place.
@Suite("Adhkar offer")
struct AdhkarOfferTests {

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
                maghrib: time(19.5), isha: time(21),
                extendsAfterMaghrib: 60 * 60
            ),
            sleep: AdhkarWindowResolver.sleep(isha: time(21), nextFajr: time(29))
        )
    }

    private var allOn: AdhkarOffer.Preferences {
        AdhkarOffer.Preferences(
            layerEnabled: true,
            morningEnabled: true,
            eveningEnabled: true,
            sleepEnabled: true
        )
    }

    private func context(
        at hour: Double,
        preferences: AdhkarOffer.Preferences? = nil,
        isIshaLogged: Bool = false,
        isPaused: Bool = false,
        dismissed: Set<AdhkarCategory> = [],
        isContentAvailable: Bool = true
    ) -> AdhkarOffer.Context {
        AdhkarOffer.Context(
            now: time(hour),
            windows: windows,
            preferences: preferences ?? allOn,
            isIshaLogged: isIshaLogged,
            isPaused: isPaused,
            dismissedCategories: dismissed,
            isContentAvailable: isContentAvailable
        )
    }

    // MARK: - Off by default

    /// The layer is invisible until someone asks for it, exactly like
    /// the sunnah layer. Nothing about the off state hints at absence.
    @Test("Nothing is offered with the layer off")
    func layerOffOffersNothing() {
        let off = AdhkarOffer.Preferences()
        for hour in stride(from: 4.0, to: 28.0, by: 0.5) {
            #expect(AdhkarOffer.offer(context(at: hour, preferences: off)) == nil)
        }
    }

    /// The master toggle governs: a per-window toggle on its own does
    /// nothing.
    @Test("A window toggle without the master toggle offers nothing")
    func masterToggleGoverns() {
        let partial = AdhkarOffer.Preferences(
            layerEnabled: false, morningEnabled: true, eveningEnabled: true, sleepEnabled: true
        )
        #expect(AdhkarOffer.offer(context(at: 6.0, preferences: partial)) == nil)
    }

    @Test("Each window can be turned off on its own")
    func perWindowTogglesAreIndependent() {
        let morningOnly = AdhkarOffer.Preferences(
            layerEnabled: true, morningEnabled: true, eveningEnabled: false, sleepEnabled: false
        )
        #expect(AdhkarOffer.offer(context(at: 6.0, preferences: morningOnly))?.category == .morning)
        #expect(AdhkarOffer.offer(context(at: 20.0, preferences: morningOnly)) == nil)
    }

    // MARK: - Windows

    @Test("Each set is offered inside its own window and nowhere else")
    func offersFollowTheirWindows() {
        #expect(AdhkarOffer.offer(context(at: 5.5))?.category == .morning)
        #expect(AdhkarOffer.offer(context(at: 7.5))?.category == .morning)
        // Between mid-morning and Maghrib the day is offering nothing.
        #expect(AdhkarOffer.offer(context(at: 10.0)) == nil)
        #expect(AdhkarOffer.offer(context(at: 14.0)) == nil)
        #expect(AdhkarOffer.offer(context(at: 16.35)) == nil)
        #expect(AdhkarOffer.offer(context(at: 20.0))?.category == .evening)
    }

    @Test("The night remembrance window survives civil midnight until Fajr")
    func sleepWindowStaysOnTheSameCycleAcrossMidnight() throws {
        let timeZone = try #require(TimeZone(identifier: "America/Chicago"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        func date(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(from: DateComponents(
                year: 2026, month: 7, day: day, hour: hour, minute: minute
            ))!
        }
        let beforeMidnight = date(20, 23, 59)
        let afterMidnight = date(21, 0, 1)
        let provider = AdhanPrayerTimesProvider()
        func window(at instant: Date) throws -> PrayerScheduleWindow {
            try provider.scheduleWindow(
                for: instant,
                coordinates: Coordinates(latitude: 41.8781, longitude: -87.6298),
                timeZone: timeZone,
                calculationMethod: .isna,
                madhab: .standard,
                highLatitudeRule: .middleOfNight
            )
        }
        let beforeSchedule = try window(at: beforeMidnight)
        let afterSchedule = try window(at: afterMidnight)
        let before = AdhkarOffer.windows(
            cycleDay: beforeSchedule.cycleDayTimes(at: beforeMidnight),
            cycleEndFajr: beforeSchedule.cycle(at: beforeMidnight).rollsAt,
            morningEndsAfterSunrise: 90 * 60,
            eveningExtendsAfterMaghrib: 60 * 60
        )
        let after = AdhkarOffer.windows(
            cycleDay: afterSchedule.cycleDayTimes(at: afterMidnight),
            cycleEndFajr: afterSchedule.cycle(at: afterMidnight).rollsAt,
            morningEndsAfterSunrise: 90 * 60,
            eveningExtendsAfterMaghrib: 60 * 60
        )

        #expect(before.sleep == after.sleep)
        #expect(before.sleep?.contains(beforeMidnight) == true)
        #expect(after.sleep?.contains(afterMidnight) == true)
        #expect(after.sleep?.end == afterSchedule.day.fajr.scheduledTime)
    }

    /// Two cards must never be open at once.
    @Test("No two sets are ever offered at the same moment")
    func offersNeverOverlap() {
        for hour in stride(from: 4.0, to: 28.0, by: 0.1) {
            let matches = [AdhkarCategory.morning, .evening, .sleep].filter { category in
                guard let window = windows.window(for: category) else { return false }
                return window.contains(time(hour))
            }
            #expect(matches.count <= 1, "\(matches) all open at \(hour)")
        }
    }

    // MARK: - Sleep follows the prayer

    @Test("The sleep set waits for Isha to be logged")
    func sleepWaitsForIsha() {
        #expect(AdhkarOffer.offer(context(at: 22.0, isIshaLogged: false)) == nil)
        #expect(AdhkarOffer.offer(context(at: 22.0, isIshaLogged: true))?.category == .sleep)
    }

    // MARK: - The pause

    /// **Hard rule: an excused pause does not suppress remembrance.**
    ///
    /// Salah and fasting pause. Dhikr and duʿāʾ do not — they are
    /// precisely what a person in that state may still keep, and
    /// removing them would be the app deciding something it has no
    /// business deciding.
    @Test("A pause changes nothing about what is offered")
    func pauseDoesNotSuppressRemembrance() {
        for hour in stride(from: 4.0, to: 28.0, by: 0.25) {
            let running = AdhkarOffer.offer(context(at: hour, isIshaLogged: true))
            let paused = AdhkarOffer.offer(
                context(at: hour, isIshaLogged: true, isPaused: true)
            )
            #expect(running == paused, "the pause changed the offer at \(hour)")
        }
    }

    @Test("Every set is offered during a pause, not merely some")
    func everySetSurvivesAPause() {
        #expect(AdhkarOffer.offer(context(at: 6.0, isPaused: true))?.category == .morning)
        #expect(AdhkarOffer.offer(context(at: 20.0, isPaused: true))?.category == .evening)
        #expect(
            AdhkarOffer.offer(
                context(at: 22.0, isIshaLogged: true, isPaused: true)
            )?.category == .sleep
        )
    }

    /// The rule itself, stated once so it cannot be reintroduced by
    /// someone adding a pause check "for consistency".
    @Test("No category is suppressed by a pause")
    func noCategoryIsPauseSuppressed() {
        for category in AdhkarCategory.allCases {
            #expect(!AdhkarOffer.pauseSuppresses(category), "\(category) is suppressed by a pause")
        }
    }

    // MARK: - Dismissal

    @Test("A dismissed set stays away for the rest of the day")
    func dismissalHoldsForTheDay() {
        #expect(AdhkarOffer.offer(context(at: 6.0, dismissed: [.morning])) == nil)
        // …and only that set.
        #expect(
            AdhkarOffer.offer(context(at: 20.0, dismissed: [.morning]))?.category == .evening
        )
    }

    // MARK: - The review gate

    /// While the content file is unreviewed in a release build there is
    /// no adhkar at all — no card, no reader, nothing.
    @Test("Unavailable content offers nothing, whatever the toggles say")
    func gatedContentOffersNothing() {
        for hour in stride(from: 4.0, to: 28.0, by: 0.5) {
            #expect(
                AdhkarOffer.offer(
                    context(at: hour, isIshaLogged: true, isContentAvailable: false)
                ) == nil
            )
        }
    }
}

@Suite("Adhkar dismissal encoding")
struct AdhkarDismissalTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago") ?? .gmt
        return calendar
    }

    @Test("A dismissal round-trips")
    func roundTrips() {
        let key = "2026-08-02"
        let encoded = AdhkarDismissal.encode([.morning, .sleep], dayKey: key)
        #expect(AdhkarDismissal.decode(encoded, dayKey: key) == [.morning, .sleep])
    }

    /// A new cycle clears the previous cycle's dismissals without a
    /// scheduled reset job.
    @Test("Yesterday's dismissals do not carry into today")
    func dismissalsExpireWithTheDay() {
        let encoded = AdhkarDismissal.encode([.morning], dayKey: "2026-08-01")
        #expect(AdhkarDismissal.decode(encoded, dayKey: "2026-08-02").isEmpty)
    }

    @Test("Nonsense decodes to nothing rather than crashing")
    func garbageDecodesEmpty() {
        #expect(AdhkarDismissal.decode("", dayKey: "2026-08-02").isEmpty)
        #expect(AdhkarDismissal.decode("2026-08-02", dayKey: "2026-08-02").isEmpty)
        #expect(AdhkarDismissal.decode("2026-08-02:nonsense", dayKey: "2026-08-02").isEmpty)
    }

    @Test("The day key follows the place's calendar")
    func dayKeyUsesTheGivenCalendar() {
        let date = Date(timeIntervalSince1970: 1_785_000_000)
        #expect(AdhkarDismissal.dayKey(date, calendar: calendar).count == 10)
    }
}
