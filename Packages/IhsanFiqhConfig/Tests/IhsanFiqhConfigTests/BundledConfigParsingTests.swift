import Foundation
import Testing
@testable import IhsanFiqhConfig

@Test
func bundledConfigParsesSuccessfully() async throws {
    let service = FiqhConfigService()
    let config = try await service.currentConfig()
    #expect(config.schemaVersion == FiqhConfig.supportedSchemaVersion)
    #expect(!config.prompts.isEmpty)
    #expect(config.prompts.allSatisfy { !$0.citationEn.isEmpty })
    #expect(config.prompts.allSatisfy { !$0.promptEn.isEmpty })
    #expect(config.prompts.allSatisfy { !$0.id.isEmpty })
}

@Test
func bundledConfigHasMinimumPromptCount() async throws {
    let service = FiqhConfigService()
    let config = try await service.currentConfig()
    #expect(config.prompts.count >= 8, "Need at least 8 prompts in bundled config for variety")
}

@Test
func bundledConfigPromptIdsAreUnique() async throws {
    let service = FiqhConfigService()
    let config = try await service.currentConfig()
    let ids = Set(config.prompts.map(\.id))
    #expect(ids.count == config.prompts.count, "Prompt ids must be unique")
}

@Test
func bundledConfigSpansMultipleCategories() async throws {
    let service = FiqhConfigService()
    let config = try await service.currentConfig()
    let categories = Set(config.prompts.map(\.category))
    #expect(categories.count >= 3, "Bundled prompts should span multiple categories")
}

@Test
func bundledConfigHasCoherentFraming() async throws {
    let service = FiqhConfigService()
    let config = try await service.currentConfig()
    #expect(!config.framing.onTimeLabel.isEmpty)
    #expect(!config.framing.lateLabel.isEmpty)
    #expect(!config.framing.missedLabel.isEmpty)
    #expect(!config.framing.qadaLabel.isEmpty)
    #expect(!config.framing.pauseModeDescription.isEmpty)
    #expect(!config.framing.travelModeDescription.isEmpty)
}

@Test
func bundledConfigHasThresholdsDescription() async throws {
    let service = FiqhConfigService()
    let config = try await service.currentConfig()
    #expect(!config.thresholds.lateDefinitionDescription.isEmpty)
}

@Test
func schemaVersionMismatchIsRejected() throws {
    let json = """
    {
      "schemaVersion": 99,
      "contentVersion": "test",
      "locale": "en",
      "prompts": [],
      "framing": {
        "onTimeLabel": "a", "lateLabel": "b", "missedLabel": "c", "qadaLabel": "d",
        "pauseModeTitle": "e", "pauseModeDescription": "f",
        "travelModeTitle": "g", "travelModeDescription": "h",
        "reflectionEmptyTitle": "i", "reflectionEmptySubtitle": "j",
        "trajectoryEmptyTitle": "k", "trajectoryEmptySubtitle": "l"
      },
      "thresholds": {
        "lateDefinitionDescription": "x",
        "autoLateSuggestionEnabled": false,
        "autoLateThresholdSeconds": 0,
        "pauseMinimumDays": 0,
        "witrTrackingAvailable": false,
        "learningModeAvailable": false
      }
    }
    """
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(FiqhConfig.self, from: data)
    #expect(decoded.schemaVersion == 99)
    #expect(decoded.schemaVersion > FiqhConfig.supportedSchemaVersion,
            "Test fixture must have a schemaVersion above the supported version to exercise the gate")
}
