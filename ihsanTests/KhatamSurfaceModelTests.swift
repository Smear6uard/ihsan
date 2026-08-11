import Foundation
import IhsanCore
import SwiftData
import Testing
@testable import ihsan

@Suite("Khatam surfaces")
@MainActor
struct KhatamSurfaceModelTests {
    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }()

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: Date(timeIntervalSince1970: 1_767_225_600))!
    }

    @Test("Only the unretired unfinished plan is active")
    func activePlan() {
        let completed = KhatamPlan(
            startDate: day(-60), endDate: day(-31), completedAt: day(-30)
        )
        let active = KhatamPlan(startDate: day(0), endDate: day(29))
        #expect(KhatamSurfaceModel.activePlan(in: [completed, active])?.id == active.id)
    }

    @Test("Today's reading is scoped to both day and plan")
    func todayTotal() {
        let plan = KhatamPlan(startDate: day(0), endDate: day(29))
        let entries = [
            KhatamEntry(planID: plan.id, entryDate: day(2), unitsRead: 4),
            KhatamEntry(planID: plan.id, entryDate: day(2).addingTimeInterval(3_600), unitsRead: 5),
            KhatamEntry(planID: plan.id, entryDate: day(1), unitsRead: 8),
            KhatamEntry(planID: UUID(), entryDate: day(2), unitsRead: 20),
        ]
        #expect(KhatamSurfaceModel.readToday(
            for: plan, entries: entries, today: day(2), calendar: calendar
        ) == 9)
    }

    @Test("A partial-day pause rests the whole civil day")
    func partialPause() {
        let pause = PauseInterval(
            startDate: day(3).addingTimeInterval(12 * 3_600),
            endDate: day(3).addingTimeInterval(15 * 3_600),
            loggedTimeZoneIdentifier: "UTC"
        )
        #expect(KhatamSurfaceModel.isPaused(
            on: day(3), pauses: [pause], calendar: calendar
        ))
    }

    @Test("A pause ending at midnight does not rest the next day")
    func pauseEndBoundary() {
        let pause = PauseInterval(
            startDate: day(3),
            endDate: day(4),
            loggedTimeZoneIdentifier: "UTC"
        )
        #expect(!KhatamSurfaceModel.isPaused(
            on: day(4), pauses: [pause], calendar: calendar
        ))
    }

    @Test("Unit lines pluralize without content")
    func unitLines() {
        #expect(KhatamSurfaceModel.unitLine(1, unit: .pages) == "1 page")
        #expect(KhatamSurfaceModel.unitLine(4, unit: .pages) == "4 pages")
        #expect(KhatamSurfaceModel.unitLine(1, unit: .juz) == "1 juz’")
    }

    @Test("The prayer offer uses the recomputed pace and recedes when today's intention is met")
    func prayerOfferPresence() {
        let plan = KhatamPlan(
            startDate: day(0), endDate: day(29), mushafPageTotal: 600
        )
        let sparse = [
            KhatamEntry(planID: plan.id, entryDate: day(0), unitsRead: 10)
        ]
        let offer = KhatamSurfaceModel.prayerOffer(
            for: plan, entries: sparse, pauses: [], today: day(9), calendar: calendar
        )
        #expect(offer == KhatamPrayerOffer(count: 6, unit: .pages))
        #expect(offer?.inscription == "6 PAGES")

        let met = sparse + [
            KhatamEntry(planID: plan.id, entryDate: day(9), unitsRead: 29)
        ]
        #expect(KhatamSurfaceModel.prayerOffer(
            for: plan, entries: met, pauses: [], today: day(9), calendar: calendar
        ) == nil)
    }

    @Test("A pause silences the prayer offer without closing numeric logging")
    func prayerOfferPause() throws {
        let plan = KhatamPlan(
            startDate: day(0), endDate: day(29), mushafPageTotal: 600
        )
        let pause = PauseInterval(
            startDate: day(4),
            endDate: day(5),
            loggedTimeZoneIdentifier: "UTC"
        )
        #expect(KhatamSurfaceModel.prayerOffer(
            for: plan, entries: [], pauses: [pause], today: day(4), calendar: calendar
        ) == nil)

        let container = try IhsanModelContainerFactory.makeContainer(inMemory: true)
        let storedPlan = try KhatamPlanWriter().begin(
            startDate: day(0), endDate: day(29), unit: .pages,
            mushafPageTotal: 600, isRamadan: false,
            now: day(0), in: container.mainContext
        )
        let entry = try KhatamPlanWriter().log(
            units: 4, on: day(4), after: .dhuhr, for: storedPlan,
            now: day(4), in: container.mainContext
        )
        #expect(entry.unitsRead == 4)
        #expect(entry.afterPrayer == Prayer.dhuhr)
    }
}
