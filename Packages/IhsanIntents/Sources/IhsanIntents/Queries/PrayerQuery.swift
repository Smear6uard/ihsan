import AppIntents
import IhsanCore

public struct PrayerQuery: EntityQuery, Sendable {
    public init() {}

    public func entities(for identifiers: [PrayerEntity.ID]) async throws -> [PrayerEntity] {
        identifiers.compactMap { id in
            Prayer(rawValue: id).map(PrayerEntity.init(prayer:))
        }
    }

    public func suggestedEntities() async throws -> [PrayerEntity] {
        PrayerEntity.allFardh
    }
}
