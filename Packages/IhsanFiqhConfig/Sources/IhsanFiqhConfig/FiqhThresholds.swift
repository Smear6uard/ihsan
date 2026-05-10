import Foundation

public struct FiqhThresholds: Codable, Sendable, Equatable {
    public let lateDefinitionDescription: String
    public let autoLateSuggestionEnabled: Bool
    public let autoLateThresholdSeconds: Int
    public let pauseMinimumDays: Int
    public let witrTrackingAvailable: Bool
    public let learningModeAvailable: Bool

    public init(
        lateDefinitionDescription: String,
        autoLateSuggestionEnabled: Bool = false,
        autoLateThresholdSeconds: Int = 0,
        pauseMinimumDays: Int = 0,
        witrTrackingAvailable: Bool = false,
        learningModeAvailable: Bool = false
    ) {
        self.lateDefinitionDescription = lateDefinitionDescription
        self.autoLateSuggestionEnabled = autoLateSuggestionEnabled
        self.autoLateThresholdSeconds = autoLateThresholdSeconds
        self.pauseMinimumDays = pauseMinimumDays
        self.witrTrackingAvailable = witrTrackingAvailable
        self.learningModeAvailable = learningModeAvailable
    }
}
