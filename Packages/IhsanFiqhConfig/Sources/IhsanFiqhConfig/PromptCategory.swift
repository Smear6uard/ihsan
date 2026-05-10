import Foundation

public enum PromptCategory: String, Codable, Sendable, CaseIterable, Hashable {
    case muhasaba
    case gratitude
    case reliance
    case repentance
    case presence
    case patience
    case general
}

public enum PromptTimeOfDay: String, Codable, Sendable, CaseIterable, Hashable {
    case morning
    case midday
    case afternoon
    case evening
    case night
    case lastThird
}
