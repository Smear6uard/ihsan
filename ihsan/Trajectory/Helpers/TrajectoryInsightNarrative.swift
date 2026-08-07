import Foundation
import IhsanCore

/// A deterministic, local reading of a Path period. It speaks only
/// from aggregate facts already on screen: no score, prediction,
/// diagnosis, or invented religious interpretation.
enum TrajectoryInsightNarrative {
    static func make(from aggregate: TrajectoryAggregate) -> String {
        let dayWord = aggregate.totalActiveDays == 1 ? "day" : "days"
        var sentences = [
            "Across \(aggregate.totalActiveDays) active \(dayWord), "
                + "\(aggregate.totalLogged) of \(aggregate.totalPossible) prayer slots have a record."
        ]

        var timingParts: [String] = []
        if aggregate.onTimeCount > 0 {
            timingParts.append("\(aggregate.onTimeCount) on time")
        }
        if aggregate.lateCount > 0 {
            timingParts.append("\(aggregate.lateCount) delayed within the window")
        }
        if aggregate.missedCount > 0 {
            timingParts.append("\(aggregate.missedCount) marked missed")
        }
        if !timingParts.isEmpty {
            sentences.append(join(timingParts).capitalizedFirst + ".")
        }

        if let strongest = aggregate.perPrayer.max(by: {
            $0.onTimeCount < $1.onTimeCount
        }), strongest.onTimeCount > 0 {
            sentences.append(
                "\(strongest.prayer.displayNameEnglish) has the most on-time records "
                    + "(\(strongest.onTimeCount))."
            )
        }

        if aggregate.qadaCount > 0 {
            let noun = aggregate.qadaCount == 1 ? "makeup is" : "makeups are"
            sentences.append(
                "\(aggregate.qadaCount) later \(noun) tracked separately."
            )
        }
        if aggregate.pausedDays > 0 {
            let noun = aggregate.pausedDays == 1 ? "day was" : "days were"
            sentences.append(
                "\(aggregate.pausedDays) paused \(noun) excluded from these counts."
            )
        }
        return sentences.joined(separator: " ")
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

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
