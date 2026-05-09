import Foundation

public enum SourceSurface: String, Codable, CaseIterable, Sendable {
    case app
    case widget
    case watch
    case notification
    case siri
    case liveActivity
    case shortcuts
}
