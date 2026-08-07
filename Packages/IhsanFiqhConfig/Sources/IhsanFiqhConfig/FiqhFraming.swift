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
    public let trajectoryInsight: TrajectoryInsightFraming?

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
        trajectoryEmptySubtitle: String,
        trajectoryInsight: TrajectoryInsightFraming? = nil
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
        self.trajectoryInsight = trajectoryInsight
    }
}

/// Review-gated explanatory copy that accompanies a factual Path readout.
/// It explains the ledger's categories without turning an observation
/// into a personal ruling.
public struct TrajectoryInsightFraming: Codable, Sendable, Equatable {
    public let title: String
    public let body: String
    public let citation: String

    public init(title: String, body: String, citation: String) {
        self.title = title
        self.body = body
        self.citation = citation
    }
}
