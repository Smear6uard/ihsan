import Foundation

public struct ReflectionPrompt: Codable, Sendable, Equatable, Identifiable, Hashable {
    public let id: String
    public let promptEn: String
    public let promptAr: String?
    public let citationEn: String
    public let citationAr: String?
    public let category: PromptCategory
    public let timeOfDay: PromptTimeOfDay?
    public let weight: Double
    public let isActive: Bool
    public let ramadanOnly: Bool

    public init(
        id: String,
        promptEn: String,
        promptAr: String? = nil,
        citationEn: String,
        citationAr: String? = nil,
        category: PromptCategory,
        timeOfDay: PromptTimeOfDay? = nil,
        weight: Double = 1.0,
        isActive: Bool = true,
        ramadanOnly: Bool = false
    ) {
        self.id = id
        self.promptEn = promptEn
        self.promptAr = promptAr
        self.citationEn = citationEn
        self.citationAr = citationAr
        self.category = category
        self.timeOfDay = timeOfDay
        self.weight = weight
        self.isActive = isActive
        self.ramadanOnly = ramadanOnly
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case promptEn
        case promptAr
        case citationEn
        case citationAr
        case category
        case timeOfDay
        case weight
        case isActive
        case ramadanOnly
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.promptEn = try container.decode(String.self, forKey: .promptEn)
        self.promptAr = try container.decodeIfPresent(String.self, forKey: .promptAr)
        self.citationEn = try container.decode(String.self, forKey: .citationEn)
        self.citationAr = try container.decodeIfPresent(String.self, forKey: .citationAr)
        self.category = try container.decode(PromptCategory.self, forKey: .category)
        self.timeOfDay = try container.decodeIfPresent(PromptTimeOfDay.self, forKey: .timeOfDay)
        self.weight = try container.decodeIfPresent(Double.self, forKey: .weight) ?? 1.0
        self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        self.ramadanOnly = try container.decodeIfPresent(Bool.self, forKey: .ramadanOnly) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(promptEn, forKey: .promptEn)
        try container.encodeIfPresent(promptAr, forKey: .promptAr)
        try container.encode(citationEn, forKey: .citationEn)
        try container.encodeIfPresent(citationAr, forKey: .citationAr)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(timeOfDay, forKey: .timeOfDay)
        try container.encode(weight, forKey: .weight)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(ramadanOnly, forKey: .ramadanOnly)
    }
}
