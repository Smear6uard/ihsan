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

    public init(
        id: String,
        promptEn: String,
        promptAr: String? = nil,
        citationEn: String,
        citationAr: String? = nil,
        category: PromptCategory,
        timeOfDay: PromptTimeOfDay? = nil,
        weight: Double = 1.0,
        isActive: Bool = true
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
    }
}
