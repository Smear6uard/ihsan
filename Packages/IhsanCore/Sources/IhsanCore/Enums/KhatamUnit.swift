import Foundation

/// The two numeric measures a person may use with their own mushaf.
/// Ihsan stores only these counts; it has no recitation-content model.
public enum KhatamUnit: String, Codable, CaseIterable, Sendable {
    case pages
    case juz

    public var singularLabel: String {
        switch self {
        case .pages: "page"
        case .juz: "juz’"
        }
    }

    public var pluralLabel: String {
        switch self {
        case .pages: "pages"
        case .juz: "ajzā’"
        }
    }
}
