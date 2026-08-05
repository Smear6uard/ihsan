import Foundation
import IhsanCore
import Testing
@testable import ihsan

/// The rule that replaced the Path's two overlay chips.
///
/// Those chips toggled `Set<Date>?` into and out of the grid. With no
/// nafl or dhikr recorded — every new account, and most accounts —
/// pressing either one produced a row of blanks, which is pixel-for-
/// pixel identical to no row at all. The switch could not demonstrate
/// its own effect, so it taught nothing.
///
/// The rows now follow the data, and this is where that is enforced:
/// a row is drawn when it has at least one mark in it, and never
/// otherwise.
@Suite("Gestalt presence rows")
struct GestaltPresenceTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ offset: Int) -> Date {
        calendar.startOfDay(
            for: Date(timeIntervalSinceReferenceDate: 700_000_000)
                .addingTimeInterval(Double(offset) * 86_400)
        )
    }

    private func days(_ count: Int) -> [DayCompletion] {
        (0..<count).map { index in
            let date = day(index)
            return DayCompletion(
                id: date,
                date: date,
                prayerCompletions: Prayer.allCases.map {
                    PrayerCompletion(prayer: $0, status: nil, withJamaah: false)
                },
                isPaused: false,
                isTraveling: false
            )
        }
    }

    // MARK: - Drawn only when there is something in it

    @Test
    func noRecordsMeansNoRow() {
        #expect(
            !GestaltAggregation.hasAnyPresence(
                days: days(30), period: .thirtyDays, daysWithRecord: []
            )
        )
    }

    @Test
    func aLayerThatIsOffMeansNoRow() {
        #expect(
            !GestaltAggregation.hasAnyPresence(
                days: days(30), period: .thirtyDays, daysWithRecord: nil
            )
        )
    }

    @Test
    func oneRecordInsideTheWindowIsEnoughToDrawTheRow() {
        #expect(
            GestaltAggregation.hasAnyPresence(
                days: days(30), period: .thirtyDays, daysWithRecord: [day(11)]
            )
        )
    }

    /// Records exist, but all of them fall outside the period being
    /// shown. The row would be blank, so it is not drawn — this is the
    /// case the old chips got wrong most visibly, since the setting was
    /// on and the panel looked broken.
    @Test
    func recordsOutsideTheWindowDrawNothing() {
        #expect(
            !GestaltAggregation.hasAnyPresence(
                days: days(7), period: .sevenDays, daysWithRecord: [day(400)]
            )
        )
    }

    // MARK: - Column alignment

    @Test
    func columnsAlignOneToOneWithTheDays() {
        let columns = GestaltAggregation.presenceColumns(
            days: days(30), period: .thirtyDays, daysWithRecord: [day(0), day(29)]
        )
        #expect(columns.count == 30)
        #expect(columns.first == true)
        #expect(columns.last == true)
        #expect(columns.dropFirst().dropLast().allSatisfy { $0 == false })
    }

    /// YEAR mode reduces seven days to one column, so a single record
    /// anywhere in a week lights that week.
    @Test
    func yearModeCollapsesAWeekIntoOneColumn() {
        let source = days(364)
        let columns = GestaltAggregation.presenceColumns(
            days: source, period: .year, daysWithRecord: [source[10].date]
        )
        #expect(columns.count == 52)
        #expect(columns.filter { $0 }.count == 1)
    }

    @Test
    func yearModeColumnsMatchTheFardhColumnCount() {
        let source = days(364)
        let fardh = GestaltAggregation.yearWeekColumns(days: source)
        let presence = GestaltAggregation.presenceColumns(
            days: source, period: .year, daysWithRecord: [source[3].date]
        )
        #expect(fardh.count == presence.count)
    }
}
