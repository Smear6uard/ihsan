import AppIntents
import IhsanCore

public struct PrayerStatusQuery: EntityQuery, Sendable {
    public init() {}

    public func entities(for identifiers: [PrayerStatusEntity.ID]) async throws -> [PrayerStatusEntity] {
        identifiers.compactMap { id in
            PrayerStatus(rawValue: id).map(PrayerStatusEntity.init(status:))
        }
    }

    public func suggestedEntities() async throws -> [PrayerStatusEntity] {
        PrayerStatusEntity.all
    }
}
