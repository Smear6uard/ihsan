import Foundation

/// Formats a distance in km for display. Switches between km and Mm
/// scales with locale-sensitive separators. Used by Qibla info panel.
enum DistanceFormatter {
    static func format(km: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = [.naturalScale, .providedUnit]
        formatter.numberFormatter.maximumFractionDigits = 0
        let measurement = Measurement(value: km, unit: UnitLength.kilometers)
        return formatter.string(from: measurement)
    }
}
