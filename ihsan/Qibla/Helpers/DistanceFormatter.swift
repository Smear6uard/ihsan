import Foundation

/// Locale-aware kilometer formatting for the qibla info panel.
/// Renders 11247.0 as "11,247 km" in en_US, "11.247 km" in de_DE, etc.
enum DistanceFormatter {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static func kilometers(_ km: Double) -> String {
        let rounded = Int(km.rounded())
        let value = formatter.string(from: NSNumber(value: rounded)) ?? "\(rounded)"
        return "\(value) km"
    }
}
