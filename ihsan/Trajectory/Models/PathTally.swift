import Foundation
import IhsanCore

/// What the key under the pattern counts — and the only numbers the
/// Path states about a period's prayers.
///
/// Every figure here is a count of marks you can see. There used to be
/// two bases side by side: a total that included today, and a coverage
/// line that did not, so "132 prayers recorded" sat one line above "129
/// of 145". Now one rule decides what is counted, the marks follow the
/// same rule, and the arithmetic closes:
///
///     onTime + delayed + qada + missed == recorded
///     recorded + noRecord              == counted
///
/// `inJamaah` is the one figure outside that sum: it says how some of
/// those prayers were offered, not what became of them.
///
/// **A blank is not always a gap.** Today's blanks may simply not have
/// happened yet, and the days before a person's first record are days
/// before they began. Neither is counted, and both draw as the small
/// pip rather than the empty ring (`isCounted`). Paused days are the
/// app agreeing not to keep count, so nothing on them is counted either.
struct PathTally: Equatable, Sendable {
    let onTime: Int
    let inJamaah: Int
    let delayed: Int
    let qada: Int
    let missed: Int
    let noRecord: Int

    var recorded: Int { onTime + delayed + qada + missed }
    var counted: Int { recorded + noRecord }

    /// - Parameter recordBegan: The day of the person's earliest record
    ///   anywhere, not just in this window. `nil` counts every day.
    init(days: [DayCompletion], recordBegan: Date? = nil) {
        let newest = days.map(\.date).max()
        var onTime = 0, inJamaah = 0, delayed = 0, qada = 0, missed = 0, noRecord = 0

        for day in days where !day.isPaused {
            for completion in day.prayerCompletions {
                switch completion.status {
                case .onTime: onTime += 1
                case .late: delayed += 1
                case .qada: qada += 1
                case .missed: missed += 1
                case nil:
                    if Self.isCounted(dayDate: day.date, newestDay: newest, recordBegan: recordBegan) {
                        noRecord += 1
                    }
                }
                if completion.withJamaah && completion.status != nil {
                    inJamaah += 1
                }
            }
        }

        self.onTime = onTime
        self.inJamaah = inJamaah
        self.delayed = delayed
        self.qada = qada
        self.missed = missed
        self.noRecord = noRecord
    }

    /// Whether a blank on this day is a real gap. The one rule the
    /// count and the mark share, so the two cannot disagree.
    static func isCounted(dayDate: Date, newestDay: Date?, recordBegan: Date?) -> Bool {
        if let newestDay, dayDate >= newestDay { return false }
        if let recordBegan, dayDate < recordBegan { return false }
        return true
    }

    /// Make-up acts performed in this window for prayers elsewhere.
    ///
    /// `aggregate.qadaCount` counts every qadā row in the window, but a
    /// linked make-up deliberately leaves its own day's slate alone, so
    /// it draws no mark here. This is the difference, stated in words
    /// by the readout rather than folded into a count that the marks
    /// could not account for. Paused days stay in on purpose: the rows
    /// being subtracted from were counted without regard to pause.
    static func separateMakeups(qadaCount: Int, days: [DayCompletion]) -> Int {
        let onTheirOwnDay = days.reduce(0) { total, day in
            total + day.prayerCompletions.filter { $0.status == .qada }.count
        }
        return max(0, qadaCount - onTheirOwnDay)
    }
}

extension PrayerStatus {
    /// Sentence case, as the Path's key and day card say it. The
    /// title-case `displayName` belongs to the seals, which stand alone.
    var sentenceName: String {
        switch self {
        case .onTime: "On time"
        case .late: "Delayed"
        case .qada: displayName
        case .missed: "Missed"
        }
    }
}
