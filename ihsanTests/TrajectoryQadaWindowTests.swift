import Foundation
import IhsanCore
import Testing
@testable import ihsan

@Suite("Path qadā period window")
struct TrajectoryQadaWindowTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ day: Int) -> Date {
        calendar.date(
            from: DateComponents(year: 2026, month: 7, day: day, hour: 12)
        )!
    }

    private func completionDay(_ day: Int) -> DayCompletion {
        DayCompletion(
            id: date(day),
            date: date(day),
            prayerCompletions: Prayer.allCases.map {
                PrayerCompletion(prayer: $0, status: nil, withJamaah: false)
            },
            isPaused: false,
            isTraveling: false
        )
    }

    private func log(day: Int, status: PrayerStatus) -> PrayerLog {
        PrayerLog(
            prayer: .fajr,
            prayerDate: date(day),
            loggedTimeZoneIdentifier: "UTC",
            scheduledTime: date(day),
            status: status
        )
    }

    @MainActor
    @Test("Only qadā entries inside the selected Path window are summarized")
    func excludesAccountLifetimeQada() {
        let days = (1...7).map(completionDay)
        let selected = TrajectoryViewModel.qadaLogs(
            in: days,
            from: [
                log(day: 4, status: .qada),
                log(day: 20, status: .qada),
                log(day: 4, status: .onTime)
            ],
            calendar: calendar
        )

        #expect(selected.count == 1)
        #expect(selected.first?.prayerDate == date(4))
    }
}
