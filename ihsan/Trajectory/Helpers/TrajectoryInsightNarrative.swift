import Foundation
import IhsanCore

/// The line under the finding.
///
/// It used to restate the period totals, which the quiet summary row
/// already prints two inches above it and the gestalt grid already
/// draws. So it says the two things neither of those can: how much of
/// the period is actually covered, and which prayers hold versus which
/// move around. No score, prediction, diagnosis, or religious reading —
/// the finding above carries the point, and the cited context below it
/// carries the fiqh.
///
/// It counts the same elapsed, unpaused days the finding counts. Two
/// adjacent sentences disagreeing about how long the week was — "4 of 6
/// days" over "across 7 active days" — reads as a bug even when both
/// numbers are defensible, and one of them always was: today's later
/// prayers are not late, they have not happened.
enum TrajectoryInsightNarrative {
    /// A prayer at or above this share of elapsed days reads as settled.
    private static let holdsThreshold = 0.7
    /// At or below this, it reads as unsettled.
    private static let variesThreshold = 0.4

    static func make(
        days: [DayCompletion],
        aggregate: TrajectoryAggregate,
        now: Date,
        calendar: Calendar = .current
    ) -> String {
        let today = calendar.startOfDay(for: now)
        let elapsed = days.filter { !$0.isPaused && $0.date < today }
        var sentences: [String] = []

        if !elapsed.isEmpty {
            let slots = elapsed.count * 5
            let recorded = elapsed.reduce(0) { total, day in
                total + day.prayerCompletions.filter { $0.status != nil }.count
            }
            let dayWord = elapsed.count == 1 ? "day" : "days"
            sentences.append(
                "\(recorded) of \(slots) slots across \(elapsed.count) elapsed \(dayWord) "
                    + "carry a record."
            )
        }

        if let shape = shapeSentence(from: elapsed) {
            sentences.append(shape)
        }

        if aggregate.qadaCount > 0 {
            let noun = aggregate.qadaCount == 1 ? "makeup is" : "makeups are"
            sentences.append("\(aggregate.qadaCount) later \(noun) tracked separately.")
        }
        if aggregate.pausedDays > 0 {
            let noun = aggregate.pausedDays == 1 ? "day was" : "days were"
            sentences.append("\(aggregate.pausedDays) paused \(noun) excluded from these counts.")
        }
        return sentences.joined(separator: " ")
    }

    /// Which prayers sit still and which move. Named only when the two
    /// groups actually differ — on a uniform period there is no shape
    /// to report, and inventing one would be the old problem again.
    private static func shapeSentence(from elapsed: [DayCompletion]) -> String? {
        guard !elapsed.isEmpty else { return nil }
        let days = Double(elapsed.count)

        var holds: [Prayer] = []
        var varies: [Prayer] = []
        for prayer in Prayer.allCases {
            let onTime = elapsed.filter { day in
                day.prayerCompletions.contains { $0.prayer == prayer && $0.status == .onTime }
            }.count
            let rate = Double(onTime) / days
            if rate >= holdsThreshold {
                holds.append(prayer)
            } else if rate <= variesThreshold {
                varies.append(prayer)
            }
        }

        switch (holds.isEmpty, varies.isEmpty) {
        case (false, false):
            return "\(clause(holds, verb: "hold")); \(clause(varies, verb: "move"))."
        case (false, true):
            return "\(clause(holds, verb: "hold"))."
        case (true, false):
            return "\(clause(varies, verb: "move"))."
        case (true, true):
            return nil
        }
    }

    /// One prayer holds ITS time; three hold THEIR time. English
    /// agreement, which the first draft of this got wrong on screen.
    private static func clause(_ prayers: [Prayer], verb: String) -> String {
        let names = join(prayers.map(\.displayNameEnglish))
        let isPlural = prayers.count > 1
        switch verb {
        case "hold":
            return "\(names) \(isPlural ? "hold their" : "holds its") time"
        default:
            return "\(names) \(isPlural ? "move" : "moves") around"
        }
    }

    /// Rejects generic model prose such as "the user logged a total of
    /// eight prayers." A generated addition must name a prayer or a
    /// timing dimension already present in the bounded summary.
    static func isUsefulGeneratedObservation(_ text: String) -> Bool {
        let normalized = text.lowercased()
        let concreteTerms = Prayer.allCases.map { $0.displayNameEnglish.lowercased() }
            + ["on time", "delayed", "missed", "jamā", "jama"]
        return concreteTerms.contains { normalized.contains($0) }
            && !normalized.contains("the user")
    }

    private static func join(_ parts: [String]) -> String {
        switch parts.count {
        case 0: return ""
        case 1: return parts[0]
        case 2: return parts.joined(separator: " and ")
        default: return parts.dropLast().joined(separator: ", ") + ", and " + parts.last!
        }
    }
}
