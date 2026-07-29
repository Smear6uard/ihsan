import Foundation
import IhsanCore
import Testing
@testable import IhsanInsights

/// Excused-pause data must never reach generated insight text in any form —
/// not as a count, not as a hint that days are missing. The model can only
/// echo what the prompt contains, so the invariant is enforced here: the
/// prompt carries no paused-day information at all. Excused days are
/// nonexistent days, not gaps.
@Test
func insightPromptsCarryNoPausedDayInformation() {
    let summary = PeriodSummary(
        periodKind: .week,
        periodStart: Date(timeIntervalSinceReferenceDate: 700_000_000),
        periodEnd: Date(timeIntervalSinceReferenceDate: 700_600_000),
        loggedTimeZoneIdentifier: "UTC",
        expectedPrayerCount: 25,
        loggedPrayerCount: 21,
        pausedDayCount: 2
    )

    for prompt in [
        InsightPromptBuilder.buildWeeklyPrompt(from: summary),
        InsightPromptBuilder.buildMonthlyPrompt(from: summary)
    ] {
        #expect(!prompt.localizedCaseInsensitiveContains("paused"))
        #expect(!prompt.localizedCaseInsensitiveContains("pause"))
        #expect(!prompt.contains("pausedDayCount"))
    }
}

/// The deterministic fallback is the other text source; it must be equally
/// silent about pauses.
@Test
func deterministicFallbackNeverMentionsPauses() {
    let summary = PeriodSummary(
        periodKind: .week,
        periodStart: Date(timeIntervalSinceReferenceDate: 700_000_000),
        periodEnd: Date(timeIntervalSinceReferenceDate: 700_600_000),
        loggedTimeZoneIdentifier: "UTC",
        expectedPrayerCount: 25,
        loggedPrayerCount: 21,
        pausedDayCount: 5
    )

    let weekly = DeterministicInsightFallback.weekly(from: summary)
    let text = [
        weekly.summarySentence,
        weekly.mostConsistentPrayer,
        weekly.leastConsistentPrayer,
        weekly.notableObservation ?? ""
    ].joined(separator: " ")

    #expect(!text.localizedCaseInsensitiveContains("pause"))
}
