import AppIntents
import IhsanCore

public struct PrayerStatusEntity: AppEntity, Identifiable, Sendable {
    public let id: String

    public var status: PrayerStatus? {
        PrayerStatus(rawValue: id)
    }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Prayer Status")
    }

    public static let defaultQuery = PrayerStatusQuery()

    public var displayRepresentation: DisplayRepresentation {
        guard let status else {
            return DisplayRepresentation(title: "Unknown")
        }

        // Siri says the same words the screens do — the entity reads
        // `PrayerStatus`'s vocabulary rather than keeping its own copy.
        return DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: status.displayName)
        )
    }

    public init(id: String) {
        self.id = id
    }

    public init(status: PrayerStatus) {
        self.id = status.rawValue
    }

    public static let all: [PrayerStatusEntity] = PrayerStatus.allCases.map(PrayerStatusEntity.init)
}
