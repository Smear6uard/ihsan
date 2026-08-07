import Foundation
import IhsanCore
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

@Test
func ramadanOnlyPromptsAreExcludedOutsideRamadan() async throws {
    var calendar = Calendar(identifier: .islamicUmmAlQura)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let shabanDate = try #require(
        calendar.date(from: DateComponents(year: 1447, month: 8, day: 20, hour: 12))
    )
    let service = FiqhConfigService(initialConfig: testPromptConfig())

    for offset in 0..<8 {
        let date = try #require(calendar.date(byAdding: .day, value: offset, to: shabanDate))
        let chosen = try await service.prompt(for: date, hijriCalendar: calendar)
        #expect(chosen.id == "year-round")
    }
}

@Test
func ramadanOnlyPromptsJoinRotationDuringRamadan() async throws {
    var calendar = Calendar(identifier: .islamicUmmAlQura)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let ramadanStart = try #require(
        calendar.date(from: DateComponents(year: 1447, month: 9, day: 1, hour: 12))
    )
    let service = FiqhConfigService(initialConfig: testPromptConfig())

    var selectedIds = Set<String>()
    for offset in 0..<20 {
        let date = try #require(calendar.date(byAdding: .day, value: offset, to: ramadanStart))
        let chosen = try await service.prompt(for: date, hijriCalendar: calendar)
        selectedIds.insert(chosen.id)
    }

    #expect(selectedIds.contains("year-round"))
    #expect(selectedIds.contains("ramadan"))
}

private func testPromptConfig() -> FiqhConfig {
    FiqhConfig(
        schemaVersion: FiqhConfig.supportedSchemaVersion,
        contentVersion: "test",
        locale: "en",
        prompts: [
            ReflectionPrompt(
                id: "year-round",
                promptEn: "What is one action to preserve?",
                citationEn: "Test",
                category: .general,
                weight: 1
            ),
            ReflectionPrompt(
                id: "ramadan",
                promptEn: "What did fasting clarify today?",
                citationEn: "Test",
                category: .presence,
                weight: 1,
                ramadanOnly: true
            )
        ],
        framing: FiqhFraming(
            onTimeLabel: "On time",
            lateLabel: "Delayed",
            missedLabel: "Missed",
            qadaLabel: "Qada",
            pauseModeTitle: "Pause",
            pauseModeDescription: "Pause tracking",
            travelModeTitle: "Travel",
            travelModeDescription: "Travel mode",
            reflectionEmptyTitle: "Reflect",
            reflectionEmptySubtitle: "Start here",
            trajectoryEmptyTitle: "Trajectory",
            trajectoryEmptySubtitle: "No data"
        ),
        thresholds: FiqhThresholds(lateDefinitionDescription: "Test")
    )
}
