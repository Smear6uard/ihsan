import Foundation

public enum HighLatitudeRule: String, Codable, CaseIterable, Sendable {
    case middleOfNight
    case oneSeventh
    case angleBased
    case twilightAngle
}
