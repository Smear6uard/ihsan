import Foundation
import FoundationModels

protocol InsightModelResponding: Sendable {
    func generateWeekly(prompt: String) async throws -> WeeklyInsight
    func generateMonthly(prompt: String) async throws -> MonthlyInsight
}

struct FoundationInsightModelClient: InsightModelResponding {
    func generateWeekly(prompt: String) async throws -> WeeklyInsight {
        let session = LanguageModelSession(instructions: InsightSystemInstructions.text)
        let response = try await session.respond(
            to: prompt,
            generating: WeeklyInsight.self,
            options: GenerationOptions(sampling: .greedy, temperature: 0, maximumResponseTokens: 320)
        )
        return response.content
    }

    func generateMonthly(prompt: String) async throws -> MonthlyInsight {
        let session = LanguageModelSession(instructions: InsightSystemInstructions.text)
        let response = try await session.respond(
            to: prompt,
            generating: MonthlyInsight.self,
            options: GenerationOptions(sampling: .greedy, temperature: 0, maximumResponseTokens: 520)
        )
        return response.content
    }
}
