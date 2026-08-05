import Foundation
import IhsanCore

public enum InsightPromptBuilder {
    public static let maximumContextTokens = 4_096
    private static let conservativeCharactersPerToken = 3

    public static func buildWeeklyPrompt(from summary: PeriodSummary) -> String {
        buildPrompt(from: summary, requestedForm: "weekly", sentenceGuidance: "Return one concise sentence plus structured prayer names.")
    }

    public static func buildMonthlyPrompt(from summary: PeriodSummary) -> String {
        buildPrompt(from: summary, requestedForm: "monthly", sentenceGuidance: "Return two to three concise sentences plus structured prayer names.")
    }

    public static func estimatedTokenCount(for text: String) -> Int {
        Int(ceil(Double(text.count) / Double(conservativeCharactersPerToken)))
    }

    private static func buildPrompt(
        from summary: PeriodSummary,
        requestedForm: String,
        sentenceGuidance: String
    ) -> String {
        let byPrayerLines = normalizedByPrayerStats(from: summary)
            .map { stat in
                // "delayed", not "late": the model writes the summary a
                // person reads, and the app calls this state Delayed —
                // prayed inside its window, but late in it.
                "- \(stat.prayer.displayNameEnglish): expected \(stat.expected), logged \(stat.logged), onTime \(stat.onTime), delayed \(stat.late), missed \(stat.missed), jamaah \(stat.jamaah)"
            }
            .joined(separator: "\n")

        return """
        Produce a \(requestedForm) insight from this materialized PeriodSummary only. Do not infer from raw logs; raw logs are not provided.
        \(sentenceGuidance)

        Period:
        - kind: \(summary.periodKind?.rawValue ?? summary.periodKindRaw)
        - start: \(iso8601String(summary.periodStart))
        - end: \(iso8601String(summary.periodEnd))
        - timeZone: \(summary.loggedTimeZoneIdentifier)

        Totals:
        - expectedPrayerCount: \(summary.expectedPrayerCount)
        - loggedPrayerCount: \(summary.loggedPrayerCount)
        - onTimeCount: \(summary.onTimeCount)
        - delayedCount: \(summary.lateCount)
        - missedCount: \(summary.missedCount)
        - qadaLoggedCount: \(summary.qadaLoggedCount)
        - jamaahCount: \(summary.jamaahCount)
        - traveledDayCount: \(summary.traveledDayCount)

        Per-prayer statistics:
        \(byPrayerLines.isEmpty ? "- none" : byPrayerLines)

        Output constraints:
        - Use only the numeric fields above.
        - Use factual, neutral observation.
        - Do not advise, exhort, motivate, judge, interpret spiritual meaning, or generate religious content.
        - Do not use quotation marks.
        """
    }

    private static func normalizedByPrayerStats(from summary: PeriodSummary) -> [ByPrayerStat] {
        let statsByPrayer = Dictionary(uniqueKeysWithValues: summary.byPrayer.map { ($0.prayer, $0) })
        return Prayer.allCases.compactMap { prayer in
            statsByPrayer[prayer]
        }
    }

    private static func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
