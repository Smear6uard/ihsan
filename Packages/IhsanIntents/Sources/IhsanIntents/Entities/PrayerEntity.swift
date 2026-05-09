import AppIntents
import IhsanCore

public struct PrayerEntity: AppEntity, Identifiable, Sendable {
    public let id: String

    public var prayer: Prayer? {
        Prayer(rawValue: id)
    }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Prayer")
    }

    public static let defaultQuery = PrayerQuery()

    public var displayRepresentation: DisplayRepresentation {
        guard let prayer else {
            return DisplayRepresentation(title: "Unknown Prayer")
        }

        return DisplayRepresentation(
            title: "\(prayer.displayNameEnglish)",
            subtitle: "\(prayer.displayNameArabic)"
        )
    }

    public init(id: String) {
        self.id = id
    }

    public init(prayer: Prayer) {
        self.id = prayer.rawValue
    }

    public static let allFardh: [PrayerEntity] = Prayer.allCases.map(PrayerEntity.init)
}
