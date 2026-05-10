import Foundation
import Testing
@testable import IhsanFiqhConfig

@Test
func sameDateProducesSamePrompt() async throws {
    let service = FiqhConfigService()
    let date = ISO8601DateFormatter().date(from: "2026-05-09T12:00:00Z")!
    let p1 = try await service.prompt(for: date)
    let p2 = try await service.prompt(for: date)
    #expect(p1.id == p2.id)
}

@Test
func sameDateAndTimeOfDayProducesSamePrompt() async throws {
    let service = FiqhConfigService()
    let date = ISO8601DateFormatter().date(from: "2026-05-09T22:00:00Z")!
    let p1 = try await service.prompt(for: date, timeOfDay: .night)
    let p2 = try await service.prompt(for: date, timeOfDay: .night)
    #expect(p1.id == p2.id)
}

@Test
func differentDatesUsuallyProduceDifferentPrompts() async throws {
    let service = FiqhConfigService()
    let dates = (0..<20).map {
        ISO8601DateFormatter().date(from: "2026-05-\(String(format: "%02d", $0 + 1))T12:00:00Z")!
    }
    var ids = Set<String>()
    for date in dates {
        let prompt = try await service.prompt(for: date)
        ids.insert(prompt.id)
    }
    #expect(ids.count >= 3, "Selection should distribute across multiple prompts over 20 days")
}

@Test
func filteredByTimeOfDayPrefersMatchingPrompts() async throws {
    let service = FiqhConfigService()
    let config = try await service.currentConfig()
    let nightPromptIds = Set(
        config.prompts
            .filter { $0.isActive && $0.timeOfDay == .night }
            .map(\.id)
    )
    let untimedPromptIds = Set(
        config.prompts
            .filter { $0.isActive && $0.timeOfDay == nil }
            .map(\.id)
    )
    let allowed = nightPromptIds.union(untimedPromptIds)

    for offset in 0..<10 {
        let date = ISO8601DateFormatter().date(from: "2026-05-\(String(format: "%02d", offset + 1))T22:00:00Z")!
        let chosen = try await service.prompt(for: date, timeOfDay: .night)
        #expect(allowed.contains(chosen.id),
                "Selected prompt \(chosen.id) is neither night-tagged nor time-agnostic")
    }
}

@Test
func selectionOnlyReturnsActivePrompts() async throws {
    let service = FiqhConfigService()
    for offset in 0..<30 {
        let date = ISO8601DateFormatter().date(from: "2026-05-\(String(format: "%02d", (offset % 28) + 1))T08:00:00Z")!
        let chosen = try await service.prompt(for: date)
        #expect(chosen.isActive, "Selection must never return an inactive prompt")
    }
}
