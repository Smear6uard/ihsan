import AppIntents
import IhsanCore

public struct QadaCategoryEntity: AppEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Makeup Prayer"
    )
    public static let defaultQuery = QadaCategoryQuery()

    public let id: String

    public init(id: String) {
        self.id = id
    }

    public init(category: QadaCategory) {
        self.id = category.rawValue
    }

    public var category: QadaCategory? {
        QadaCategory(rawValue: id)
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(category?.displayNameEnglish ?? id)",
            subtitle: "\(category?.displayNameArabic ?? "")"
        )
    }
}

public struct QadaCategoryQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [QadaCategoryEntity] {
        identifiers.compactMap { identifier in
            QadaCategory(rawValue: identifier).map(QadaCategoryEntity.init(category:))
        }
    }

    public func suggestedEntities() async throws -> [QadaCategoryEntity] {
        QadaCategory.allCases.map(QadaCategoryEntity.init(category:))
    }
}
