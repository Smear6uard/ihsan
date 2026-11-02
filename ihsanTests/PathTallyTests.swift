import Foundation
import IhsanCore
import Testing
@testable import ihsan

/// The numbers on the Path.
///
/// "132 prayers recorded" sat one line above "129 of 145", because one
/// count included today and the other did not. And "Missed: 0" sat beside
/// sixteen blank marks. These hold the key to one basis, and hold the
/// count and the marks to the same rule.
@Suite("Path tally")
struct PathTallyTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private static let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_754_654_400))

    /// Oldest first, as the aggregator hands them over.
    private func days(_ specs: [(daysAgo: Int, statuses: [Prayer: PrayerStatus])], paused: Set<Int> = []) -> [DayCompletion] {
        specs.sorted { $0.daysAgo > $1.daysAgo }.map { spec in
            let date = Self.calendar.date(byAdding: .day, value: -spec.daysAgo, to: Self.today)!
            return DayCompletion(
                id: date,
                date: date,
                prayerCompletions: Prayer.allCases.map {
                    PrayerCompletion(prayer: $0, status: spec.statuses[$0], withJamaah: false)
                },
                isPaused: paused.contains(spec.daysAgo),
                isTraveling: false
            )
        }
    }

    private func all(_ status: PrayerStatus) -> [Prayer: PrayerStatus] {
        Dictionary(uniqueKeysWithValues: Prayer.allCases.map { ($0, status) })
    }

    @Test("The counts add up, every time")
    func theArithmeticCloses() {
        let tally = PathTally(days: days([
            (3, [.fajr: .onTime, .dhuhr: .late, .asr: .missed, .maghrib: .qada]),
            (2, all(.onTime)),
            (1, [.fajr: .onTime]),
            (0, [.fajr: .onTime, .dhuhr: .late])
        ]))

        #expect(tally.onTime + tally.delayed + tally.qada + tally.missed == tally.recorded)
        #expect(tally.recorded + tally.noRecord == tally.counted)
        #expect(tally.onTime == 8)
        #expect(tally.delayed == 2)
        #expect(tally.missed == 1)
        #expect(tally.qada == 1)
        #expect(tally.recorded == 12)
    }

    /// The exact failure: today's recorded prayers were in one total
    /// and out of the other.
    @Test("Today's records count; today's blanks do not")
    func todayIsCountedOnOneBasis() {
        let tally = PathTally(days: days([
            (1, all(.onTime)),
            (0, [.fajr: .onTime, .dhuhr: .onTime, .asr: .onTime])
        ]))

        #expect(tally.recorded == 8)
        #expect(tally.noRecord == 0, "Maghrib and Isha have not happened yet")
        #expect(tally.counted == 8)
    }

    @Test("Missed and no record are different lines")
    func missedIsNotUnrecorded() {
        let tally = PathTally(days: days([
            (2, [.fajr: .missed]),
            (1, all(.onTime)),
            (0, [:])
        ]))

        #expect(tally.missed == 1)
        #expect(tally.noRecord == 4)
    }

    @Test("The days before the record began are not gaps")
    func daysBeforeTheFirstRecordAreNotCounted() {
        let began = Self.calendar.date(byAdding: .day, value: -1, to: Self.today)
        let tally = PathTally(
            days: days([(3, [:]), (2, [:]), (1, [.fajr: .onTime]), (0, [:])]),
            recordBegan: began
        )

        #expect(tally.noRecord == 4, "only yesterday's blanks are gaps")
        #expect(tally.counted == 5)
    }

    @Test("A paused day counts nothing")
    func pausedDaysAreLeftOut() {
        let tally = PathTally(
            days: days([(2, all(.onTime)), (1, [:]), (0, [:])], paused: [1])
        )

        #expect(tally.onTime == 5)
        #expect(tally.noRecord == 0)
    }

    /// The mark and the number read one rule, so a pip can never be
    /// counted and a counted blank can never draw as a pip.
    @Test("The mark's rule is the count's rule")
    func marksAndCountsAgree() {
        let began = Self.calendar.date(byAdding: .day, value: -2, to: Self.today)
        let window = days([(3, [:]), (2, [:]), (1, [:]), (0, [:])])
        let newest = window.last?.date

        let ringed = window.filter {
            PathTally.isCounted(dayDate: $0.date, newestDay: newest, recordBegan: began)
        }
        let tally = PathTally(days: window, recordBegan: began)

        #expect(tally.noRecord == ringed.count * 5)
    }

    @Test("Only make-ups with no mark of their own are separate")
    func separateMakeupsLeaveOutMarkedQada() {
        let window = days([(1, [.fajr: .qada]), (0, [:])])

        #expect(PathTally.separateMakeups(qadaCount: 1, days: window) == 0)
        #expect(PathTally.separateMakeups(qadaCount: 4, days: window) == 3)
        #expect(PathTally.separateMakeups(qadaCount: 0, days: window) == 0)
    }
}

/// One screen, one name, and no words a reader would have to be told.
@Suite("Path vocabulary")
struct PathVocabularyTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Words that were on screen and meant nothing to anyone outside
    /// the codebase. Quoted, so a comment recounting the history of one
    /// is not a violation; only a string that could reach the screen is.
    private static let retired = [
        "\"A pattern of days\"", "TRAJECTORY ·", "\"PERIOD READOUT\"", "\"DAILY PRACTICE\"",
        "\"VOLUNTARY PRACTICE\"", "\"ON DEVICE\"", "\"FIQH CONTEXT\"", "\"RETURNING\"",
        "\"IF YOU WANT IT\"", " slots", "carry a record", "hold their time",
        "makeup ledger", "weak point", "start your trajectory"
    ]

    @Test("No retired word can reach the screen")
    func retiredWordsAreGone() throws {
        for root in ["ihsan/Trajectory", "ihsan/Repair/Components"] {
            let base = repoRoot.appending(path: root)
            let walker = try #require(
                FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)
            )
            for case let url as URL in walker where url.pathExtension == "swift" {
                let source = try String(contentsOf: url, encoding: .utf8)
                let code = source
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                    .joined(separator: "\n")
                for word in Self.retired {
                    #expect(!code.contains(word), "\(url.lastPathComponent) still says \(word)")
                }
            }
        }
    }
}
