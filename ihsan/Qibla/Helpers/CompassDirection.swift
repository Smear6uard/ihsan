import Foundation

/// Bearing-to-text formatting for the qibla info panel.
enum CompassDirection {
    /// Returns "47° NE" — integer degrees followed by the cardinal/intercardinal
    /// abbreviation for the same bearing.
    static func format(_ bearing: Double) -> String {
        let normalized = normalize(bearing)
        let cardinal = cardinalAbbreviation(normalized)
        let rounded = Int(normalized.rounded()) % 360
        return "\(rounded)° \(cardinal)"
    }

    /// One of N, NE, E, SE, S, SW, W, NW. Each cardinal owns a 45° slice
    /// centered on its true bearing.
    static func cardinalAbbreviation(_ bearing: Double) -> String {
        let normalized = normalize(bearing)
        switch normalized {
        case 337.5...360, 0..<22.5: return "N"
        case 22.5..<67.5: return "NE"
        case 67.5..<112.5: return "E"
        case 112.5..<157.5: return "SE"
        case 157.5..<202.5: return "S"
        case 202.5..<247.5: return "SW"
        case 247.5..<292.5: return "W"
        case 292.5..<337.5: return "NW"
        default: return "N"
        }
    }

    private static func normalize(_ bearing: Double) -> Double {
        let r = bearing.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }
}
