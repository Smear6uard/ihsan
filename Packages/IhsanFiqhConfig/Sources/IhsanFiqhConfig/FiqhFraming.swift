import Foundation

public struct FiqhFraming: Codable, Sendable, Equatable {
    public let onTimeLabel: String
    public let lateLabel: String
    public let missedLabel: String
    public let qadaLabel: String

    public let pauseModeTitle: String
    public let pauseModeDescription: String

    public let travelModeTitle: String
    public let travelModeDescription: String

    public let reflectionEmptyTitle: String
    public let reflectionEmptySubtitle: String

    public let trajectoryEmptyTitle: String
    public let trajectoryEmptySubtitle: String

    public init(
        onTimeLabel: String,
        lateLabel: String,
        missedLabel: String,
        qadaLabel: String,
        pauseModeTitle: String,
        pauseModeDescription: String,
        travelModeTitle: String,
        travelModeDescription: String,
        reflectionEmptyTitle: String,
        reflectionEmptySubtitle: String,
        trajectoryEmptyTitle: String,
        trajectoryEmptySubtitle: String
    ) {
        self.onTimeLabel = onTimeLabel
        self.lateLabel = lateLabel
        self.missedLabel = missedLabel
        self.qadaLabel = qadaLabel
        self.pauseModeTitle = pauseModeTitle
        self.pauseModeDescription = pauseModeDescription
        self.travelModeTitle = travelModeTitle
        self.travelModeDescription = travelModeDescription
        self.reflectionEmptyTitle = reflectionEmptyTitle
        self.reflectionEmptySubtitle = reflectionEmptySubtitle
        self.trajectoryEmptyTitle = trajectoryEmptyTitle
        self.trajectoryEmptySubtitle = trajectoryEmptySubtitle
    }
}
