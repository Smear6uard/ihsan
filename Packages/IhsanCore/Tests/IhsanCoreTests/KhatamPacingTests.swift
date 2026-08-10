import Foundation
import SwiftData
import Testing
@testable import IhsanCore

@Suite("Khatam pacing")
struct KhatamPacingTests {
    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }()

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: Date(timeIntervalSince1970: 1_767_225_600))!
    }

    @Test("604 pages over 30 days resolves to 21 daily and 5 per prayer")
    func classicalArithmeticRoundsWithoutLosingPages() {
        let plan = KhatamPacingPlan(startDate: day(0), endDate: day(29), targetUnits: 604)
        let pace = KhatamPacing.resolve(plan: plan, entries: [], today: day(0), calendar: calendar)
        #expect(pace.remaining == 604)
        #expect(pace.suggestedToday == 21)
        #expect(pace.perPrayerSuggestion == 5)
        #expect(pace.forecastCompletionDate == nil)
    }

    @Test("Sparse reading silently recomputes today's suggestion")
    func sparseReadingRecomputes() {
        let plan = KhatamPacingPlan(startDate: day(0), endDate: day(29), targetUnits: 600)
        let pace = KhatamPacing.resolve(
            plan: plan,
            entries: [.init(date: day(0), unitsRead: 10)],
            today: day(9),
            calendar: calendar
        )
        #expect(pace.remaining == 590)
        #expect(pace.suggestedToday == 29)
    }

    @Test("An early pace keeps the even split floor and forecasts factually")
    func earlyPace() {
        let plan = KhatamPacingPlan(startDate: day(0), endDate: day(29), targetUnits: 600)
        let entries = (0..<10).map { KhatamPacingEntry(date: day($0), unitsRead: 30) }
        let pace = KhatamPacing.resolve(plan: plan, entries: entries, today: day(9), calendar: calendar)
        #expect(pace.suggestedToday == 20)
        #expect(pace.forecastCompletionDate == day(18))
    }

    @Test("No recent reading produces no forecast")
    func zeroRecentPace() {
        let plan = KhatamPacingPlan(startDate: day(0), endDate: day(29), targetUnits: 600)
        let pace = KhatamPacing.resolve(plan: plan, entries: [], today: day(8), calendar: calendar)
        #expect(pace.forecastCompletionDate == nil)
        #expect(!pace.hasRecentPace)
    }

    @Test("An elapsed period continues at its original cadence")
    func elapsedPeriodContinues() {
        let plan = KhatamPacingPlan(startDate: day(0), endDate: day(29), targetUnits: 600)
        let entries = (0..<30).map { KhatamPacingEntry(date: day($0), unitsRead: 10) }
        let pace = KhatamPacing.resolve(plan: plan, entries: entries, today: day(34), calendar: calendar)
        #expect(pace.remaining == 300)
        #expect(pace.suggestedToday == 20)
        #expect(pace.forecastCompletionDate! > day(29))
    }

    @Test("Excused dates leave denominators and silence that day's prompt")
    func pauseBehavior() {
        let excused = Set([day(4), day(5)])
        let plan = KhatamPacingPlan(
            startDate: day(0), endDate: day(9), targetUnits: 80, excusedDates: excused
        )
        let paused = KhatamPacing.resolve(plan: plan, entries: [], today: day(4), calendar: calendar)
        #expect(paused.suggestedToday == 0)
        #expect(paused.perPrayerSuggestion == 0)

        let active = KhatamPacing.resolve(plan: plan, entries: [], today: day(0), calendar: calendar)
        #expect(active.suggestedToday == 10)

        let voluntaryEntry = KhatamPacing.resolve(
            plan: plan,
            entries: [.init(date: day(4), unitsRead: 7)],
            today: day(4),
            calendar: calendar
        )
        #expect(voluntaryEntry.remaining == 73)
    }

    @Test("Writer preserves one active plan and a seeded store round-trips")
    @MainActor
    func seededStore() throws {
        let container = try IhsanModelContainerFactory.makeContainer(inMemory: true)
        let context = container.mainContext
        let writer = KhatamPlanWriter()
        let first = try writer.begin(
            startDate: day(0), endDate: day(29), unit: .pages,
            isRamadan: true, now: day(0), in: context
        )
        let second = try writer.begin(
            startDate: day(30), endDate: day(59), unit: .juz,
            targetCount: 2, isRamadan: false, now: day(30), in: context
        )
        #expect(!first.isActive)
        #expect(second.isActive)
        #expect(second.targetUnits == 60)
        let entry = try writer.log(
            units: 3, on: day(30), after: .fajr, for: second, now: day(30), in: context
        )
        let fetched = try context.fetch(FetchDescriptor<KhatamEntry>())
        #expect(fetched.map(\.id).contains(entry.id))
        #expect(fetched.first?.afterPrayer == .fajr)
    }

    @Test("A completion settles once and undo reopens the plan")
    @MainActor
    func completionAndUndo() throws {
        let container = try IhsanModelContainerFactory.makeContainer(inMemory: true)
        let context = container.mainContext
        let writer = KhatamPlanWriter()
        let plan = try writer.begin(
            startDate: day(0), endDate: day(1), unit: .pages,
            mushafPageTotal: 5, isRamadan: false, now: day(0), in: context
        )
        let entry = try writer.log(
            units: 5, on: day(0), for: plan, now: day(0), in: context
        )
        #expect(plan.completedAt == day(0))
        #expect(plan.completionMomentShownAt == nil)
        try writer.markCompletionMomentShown(for: plan, at: day(0), in: context)
        #expect(plan.completionMomentShownAt == day(0))

        try writer.remove(entry, now: day(1), in: context)
        #expect(plan.completedAt == nil)
    }
}
