import Foundation
import IhsanCore

/// The line under the finding.
///
/// The key above already counts the period and the grid already draws
/// it, so this says only what neither of those can: which prayers were
/// steady and which varied, the make-ups that have no mark of their own,
/// and the days left out. No score, prediction, diagnosis, or religious
/// reading — the finding above carries the point, and the cited context
/// below it carries the fiqh. It states no coverage figure: a second
/// count of the same prayers on a different basis is how "132 recorded"
/// came to sit one line above "129 of 145".
enum TrajectoryInsightNarrative {
    /// A prayer at or above this share of elapsed days reads as settled.
    private static let holdsThreshold = 0.7
    /// At or below this, it reads as unsettled.
    private static let variesThreshold = 0.4

    static func make(
        days: [DayCompletion],
        aggregate: TrajectoryAggregate,
        now: Date,
        recordBegan: Date? = nil,
        calendar: Calendar = .current
    ) -> String {
        let today = calendar.startOfDay(for: now)
        let elapsed = days.filter {
            !$0.isPaused && $0.date < today && $0.date >= (recordBegan ?? .distantPast)
        }
        var sentences: [String] = []

        if let shape = shapeSentence(from: elapsed) {
            sentences.append(shape)
        }

        let makeups = PathTally.separateMakeups(qadaCount: aggregate.qadaCount, days: days)
        if makeups > 0 {
            let noun = makeups == 1 ? "earlier prayer was" : "earlier prayers were"
            sentences.append("\(makeups) \(noun) made up in this period.")
        }
        if aggregate.pausedDays > 0 {
            let noun = aggregate.pausedDays == 1 ? "day isn’t" : "days aren’t"
            sentences.append("\(aggregate.pausedDays) paused \(noun) counted.")
        }
        return sentences.joined(separator: " ")
    }

    /// Which prayers were steady and which varied. Named only when the
    /// two groups actually differ — on a uniform period there is no
    /// shape to report, and inventing one would be the old problem again.
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

    /// One prayer WAS; three WERE. English agreement, which the first
    /// draft of this got wrong on screen.
    private static func clause(_ prayers: [Prayer], verb: String) -> String {
        let names = prayers.count == Prayer.allCases.count
            ? "All five prayers"
            : join(prayers.map(\.displayNameEnglish))
        switch verb {
        case "hold":
            return "\(names) \(prayers.count > 1 ? "were" : "was") usually on time"
        default:
            return "\(names) varied"
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
