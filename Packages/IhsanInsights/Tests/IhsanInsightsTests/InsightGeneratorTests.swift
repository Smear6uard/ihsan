import Foundation
import IhsanCore
import Testing
@testable import IhsanInsights

@Test
func weeklyGeneratorRetriesRejectedModelOutputThenFallsBack() async throws {
    let summary = makeGeneratorSummary()
    let fixedNow = Date(timeIntervalSince1970: 10_000)
    let client = MockInsightModelClient(
        weeklyResponses: [
            WeeklyInsight(
                summarySentence: "You should pray Fajr earlier.",
                mostConsistentPrayer: "Asr",
                leastConsistentPrayer: "Fajr"
            ),
            WeeklyInsight(
                summarySentence: "A hadith mentions consistency.",
                mostConsistentPrayer: "Asr",
                leastConsistentPrayer: "Fajr"
            )
        ]
    )
    let generator = InsightGenerator(
        modelClient: client,
        availability: { true },
        now: { fixedNow }
    )

    let insight = try await generator.generateWeeklyInsight(from: summary)

    #expect(await client.weeklyCallCount == 2)
    #expect(insight.summarySentence == "Asr was prayed on time on 5 of 7 days. Fajr was prayed on time on 2 of 7 days. 1 prayer made up as qada.")
    #expect(InsightContentFilter.accepts(insight))
}

@Test
func weeklyGeneratorUsesSecondAcceptedModelOutput() async throws {
    let summary = makeGeneratorSummary()
    let client = MockInsightModelClient(
        weeklyResponses: [
            WeeklyInsight(
                summarySentence: "You should improve Fajr.",
                mostConsistentPrayer: "Asr",
                leastConsistentPrayer: "Fajr"
            ),
            WeeklyInsight(
                summarySentence: "Asr was prayed on time on 5 of 7 days.",
                mostConsistentPrayer: "Asr",
                leastConsistentPrayer: "Fajr",
                notableObservation: "Fajr was prayed on time on 2 of 7 days."
            )
        ]
    )
    let generator = InsightGenerator(modelClient: client, availability: { true })

    let insight = try await generator.generateWeeklyInsight(from: summary)

    #expect(await client.weeklyCallCount == 2)
    #expect(insight.summarySentence == "Asr was prayed on time on 5 of 7 days.")
}

@Test
func generatorReturnsFreshCachedInsightWithoutModelCall() async throws {
    let generatedAt = Date(timeIntervalSince1970: 10_000)
    let summary = makeGeneratorSummary(
        aiInsightText: "Cached factual summary.",
        aiInsightGeneratedAt: generatedAt,
        aiInsightModelVersion: "older-version"
    )
    let client = MockInsightModelClient()
    let generator = InsightGenerator(
        modelClient: client,
        availability: { true },
        now: { generatedAt.addingTimeInterval(60 * 60) }
    )

    let insight = try await generator.generateWeeklyInsight(from: summary)

    #expect(await client.weeklyCallCount == 0)
    #expect(insight.summarySentence == "Cached factual summary.")
}

@Test
func generatorThrowsTypedErrorWhenUnavailable() async throws {
    let generator = InsightGenerator(
        modelClient: MockInsightModelClient(),
        availability: { false }
    )

    await #expect(throws: InsightError.modelUnavailable) {
        _ = try await generator.generateWeeklyInsight(from: makeGeneratorSummary())
    }
}

private actor MockInsightModelClient: InsightModelResponding {
    private var weeklyResponses: [WeeklyInsight]
    private var monthlyResponses: [MonthlyInsight]
    private var weeklyCalls = 0
    private var monthlyCalls = 0

    init(
        weeklyResponses: [WeeklyInsight] = [],
        monthlyResponses: [MonthlyInsight] = []
    ) {
        self.weeklyResponses = weeklyResponses
        self.monthlyResponses = monthlyResponses
    }

    var weeklyCallCount: Int {
        weeklyCalls
    }

    var monthlyCallCount: Int {
        monthlyCalls
    }

    func generateWeekly(prompt: String) async throws -> WeeklyInsight {
        weeklyCalls += 1
        guard !weeklyResponses.isEmpty else {
            throw InsightError.generationFailed("No weekly mock response")
        }
        return weeklyResponses.removeFirst()
    }

    func generateMonthly(prompt: String) async throws -> MonthlyInsight {
        monthlyCalls += 1
        guard !monthlyResponses.isEmpty else {
            throw InsightError.generationFailed("No monthly mock response")
        }
        return monthlyResponses.removeFirst()
    }
}

private func makeGeneratorSummary(
    aiInsightText: String? = nil,
    aiInsightGeneratedAt: Date? = nil,
    aiInsightModelVersion: String? = nil
) -> PeriodSummary {
    PeriodSummary(
        periodKind: .week,
        periodStart: Date(timeIntervalSince1970: 0),
        periodEnd: Date(timeIntervalSince1970: 604_800),
        loggedTimeZoneIdentifier: "America/Chicago",
        expectedPrayerCount: 35,
        loggedPrayerCount: 29,
        onTimeCount: 17,
        lateCount: 8,
        missedCount: 6,
        qadaLoggedCount: 1,
        jamaahCount: 4,
        byPrayer: [
            ByPrayerStat(prayer: .fajr, expected: 7, logged: 5, onTime: 2, late: 3, missed: 2, jamaah: 0),
            ByPrayerStat(prayer: .dhuhr, expected: 7, logged: 6, onTime: 3, late: 2, missed: 1, jamaah: 1),
            ByPrayerStat(prayer: .asr, expected: 7, logged: 7, onTime: 5, late: 1, missed: 0, jamaah: 1),
            ByPrayerStat(prayer: .maghrib, expected: 7, logged: 6, onTime: 4, late: 1, missed: 1, jamaah: 1),
            ByPrayerStat(prayer: .isha, expected: 7, logged: 5, onTime: 3, late: 1, missed: 2, jamaah: 1)
        ],
        aiInsightText: aiInsightText,
        aiInsightGeneratedAt: aiInsightGeneratedAt,
        aiInsightModelVersion: aiInsightModelVersion
    )
}
