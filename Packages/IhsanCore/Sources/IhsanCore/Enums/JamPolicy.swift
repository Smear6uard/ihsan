import Foundation

public enum JamPolicy: String, Codable, CaseIterable, Sendable {
    case always
    case ask
    case never
}
