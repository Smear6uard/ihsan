import Foundation
import IhsanCore
import Testing
@testable import ihsan

@Suite("Khatam surfaces")
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

    @Test("Unit lines pluralize without content")
    func unitLines() {
        #expect(KhatamSurfaceModel.unitLine(1, unit: .pages) == "1 page")
        #expect(KhatamSurfaceModel.unitLine(4, unit: .pages) == "4 pages")
        #expect(KhatamSurfaceModel.unitLine(1, unit: .juz) == "1 juz’")
    }

}
