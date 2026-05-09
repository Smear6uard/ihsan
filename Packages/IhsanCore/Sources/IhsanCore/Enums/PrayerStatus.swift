import Foundation

public enum PrayerStatus: String, Codable, CaseIterable, Sendable {
    case onTime
    case late
    case missed
    case qada
}
