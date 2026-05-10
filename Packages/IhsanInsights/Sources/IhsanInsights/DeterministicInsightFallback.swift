import Foundation
import IhsanCore

enum DeterministicInsightFallback {
    static func weekly(from summary: PeriodSummary) -> WeeklyInsight {
        let materialized = materialize(from: summary)
        return WeeklyInsight(
            summarySentence: materialized.summarySentence,
            mostConsistentPrayer: materialized.mostConsistentPrayer,
            leastConsistentPrayer: materialized.leastConsistentPrayer,
            notableObservation: materialized.notableObservation
        )
    }

    static func monthly(from summary: PeriodSummary) -> MonthlyInsight {
        let materialized = materialize(from: summary)
        return MonthlyInsight(
            summarySentence: materialized.summarySentence,
            mostConsistentPrayer: materialized.mostConsistentPrayer,
            leastConsistentPrayer: materialized.leastConsistentPrayer,
            notableObservation: materialized.notableObservation
        )
    }

    private static func materialize(from summary: PeriodSummary) -> MaterializedInsight {
        let perPrayer = normalizedByPrayerStats(from: summary)
        guard let most = perPrayer.max(by: { $0.onTime < $1.onTime }),
              let least = perPrayer.min(by: { $0.onTime < $1.onTime })
        else {
            return MaterializedInsight(
                summarySentence: "No prayer activity was logged for this period.",
                mostConsistentPrayer: "None",
                leastConsistentPrayer: "None",
                notableObservation: nil
            )
        }

        var sentences: [String] = []
        let mostSentence = "\(most.prayer.displayNameEnglish) was prayed on time on \(most.onTime) of \(daysDescription(for: most, summary: summary)) days."
        sentences.append(mostSentence)

        if least.prayer != most.prayer {
            sentences.append(
                "\(least.prayer.displayNameEnglish) was prayed on time on \(least.onTime) of \(daysDescription(for: least, summary: summary)) days."
            )
        }

        var notableObservation: String?

        if summary.qadaLoggedCount > 0 {
            let prayerWord = summary.qadaLoggedCount == 1 ? "prayer" : "prayers"
            let sentence = "\(summary.qadaLoggedCount) \(prayerWord) made up as qada."
            sentences.append(sentence)
            notableObservation = sentence
        }

        if summary.traveledDayCount > 0 {
            let dayWord = summary.traveledDayCount == 1 ? "day" : "days"
            let sentence = "\(summary.traveledDayCount) \(dayWord) traveling."
            sentences.append(sentence)
            if notableObservation == nil {
                notableObservation = sentence
            }
        }

        return MaterializedInsight(
            summarySentence: sentences.joined(separator: " "),
            mostConsistentPrayer: most.prayer.displayNameEnglish,
            leastConsistentPrayer: least.prayer.displayNameEnglish,
            notableObservation: notableObservation
        )
    }

    private static func normalizedByPrayerStats(from summary: PeriodSummary) -> [ByPrayerStat] {
        let statsByPrayer = Dictionary(uniqueKeysWithValues: summary.byPrayer.map { ($0.prayer, $0) })
        return Prayer.allCases.compactMap { prayer in
            statsByPrayer[prayer]
        }
    }

    private static func daysDescription(for stat: ByPrayerStat, summary: PeriodSummary) -> Int {
        if stat.expected > 0 {
            return stat.expected
        }
        if summary.expectedPrayerCount > 0 {
            return max(1, summary.expectedPrayerCount / max(1, Prayer.allCases.count))
        }
        return max(1, summary.loggedPrayerCount / max(1, Prayer.allCases.count))
    }

    private struct MaterializedInsight: Sendable {
        var summarySentence: String
        var mostConsistentPrayer: String
        var leastConsistentPrayer: String
        var notableObservation: String?
    }
}
