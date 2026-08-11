import Foundation
import IhsanCore

/// PeriodSummary is a SwiftData model, so all reads and cache writes stay on
/// the main actor. The model client remains asynchronous and does not block
/// the actor while Foundation Models is producing a response.
@MainActor
public final class InsightGenerator {
    public static let shared = InsightGenerator()

    public static let modelVersion = "foundationmodels-system-language-model-default-v1"

    private static let cacheFreshnessInterval: TimeInterval = 7 * 24 * 60 * 60

    private let modelClient: any InsightModelResponding
    private let availability: @Sendable () -> Bool
    private let now: @Sendable () -> Date

    init(
        modelClient: any InsightModelResponding = FoundationInsightModelClient(),
        availability: @escaping @Sendable () -> Bool = { InsightAvailability.isAvailable },
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.modelClient = modelClient
        self.availability = availability
        self.now = now
    }

    public func generateWeeklyInsight(from summary: PeriodSummary) async throws -> WeeklyInsight {
        if let cached = cachedWeeklyInsight(from: summary) {
            return cached
        }

        guard availability() else {
            throw InsightError.modelUnavailable
        }

        let prompt = InsightPromptBuilder.buildWeeklyPrompt(from: summary)
        try enforceContextWindow(prompt: prompt)

        let insight = try await generateWithSingleRetry(
            prompt: prompt,
            modelCall: modelClient.generateWeekly(prompt:),
            isAccepted: InsightContentFilter.accepts(_:),
            fallback: { DeterministicInsightFallback.weekly(from: summary) }
        )

        cache(insight.summarySentence, on: summary)
        return insight
    }

    public func generateMonthlyInsight(from summary: PeriodSummary) async throws -> MonthlyInsight {
        if let cached = cachedMonthlyInsight(from: summary) {
            return cached
        }

        guard availability() else {
            throw InsightError.modelUnavailable
        }

        let prompt = InsightPromptBuilder.buildMonthlyPrompt(from: summary)
        try enforceContextWindow(prompt: prompt)

        let insight = try await generateWithSingleRetry(
            prompt: prompt,
            modelCall: modelClient.generateMonthly(prompt:),
            isAccepted: InsightContentFilter.accepts(_:),
            fallback: { DeterministicInsightFallback.monthly(from: summary) }
        )

        cache(insight.summarySentence, on: summary)
        return insight
    }

    private func generateWithSingleRetry<Insight: Sendable>(
        prompt: String,
        modelCall: (String) async throws -> Insight,
        isAccepted: (Insight) -> Bool,
        fallback: () -> Insight
    ) async throws -> Insight {
        do {
            let first = try await modelCall(prompt)
            if isAccepted(first) {
                return first
            }

            let second = try await modelCall(prompt)
            if isAccepted(second) {
                return second
            }

            return fallback()
        } catch let error as InsightError {
            throw error
        } catch {
            throw InsightError.generationFailed(String(describing: error))
        }
    }

    private func enforceContextWindow(prompt: String) throws {
        let fullInput = InsightSystemInstructions.text + "\n\n" + prompt
        let estimatedTokens = InsightPromptBuilder.estimatedTokenCount(for: fullInput)
        guard estimatedTokens <= InsightPromptBuilder.maximumContextTokens else {
            throw InsightError.contextWindowExceeded(
                estimatedTokens: estimatedTokens,
                maximumTokens: InsightPromptBuilder.maximumContextTokens
            )
        }
    }

    private func cachedWeeklyInsight(from summary: PeriodSummary) -> WeeklyInsight? {
        guard let cachedText = freshCachedText(from: summary) else {
            return nil
        }

        var fallback = DeterministicInsightFallback.weekly(from: summary)
        fallback.summarySentence = cachedText
        return fallback
    }

    private func cachedMonthlyInsight(from summary: PeriodSummary) -> MonthlyInsight? {
        guard let cachedText = freshCachedText(from: summary) else {
            return nil
        }

        var fallback = DeterministicInsightFallback.monthly(from: summary)
        fallback.summarySentence = cachedText
        return fallback
    }

    private func freshCachedText(from summary: PeriodSummary) -> String? {
        guard let text = summary.aiInsightText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              let generatedAt = summary.aiInsightGeneratedAt
        else {
            return nil
        }

        guard now().timeIntervalSince(generatedAt) < Self.cacheFreshnessInterval else {
            return nil
        }

        return text
    }

    private func cache(_ text: String, on summary: PeriodSummary) {
        let generationDate = now()
        summary.aiInsightText = text
        summary.aiInsightGeneratedAt = generationDate
        summary.aiInsightModelVersion = Self.modelVersion
        summary.modifiedAt = generationDate
    }
}
