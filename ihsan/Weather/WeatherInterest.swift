import Foundation
import IhsanCore

/// Whether anything in the app currently wants weather at all.
///
/// The fetch gate, written down once: with no interested consumer the
/// spine never touches the network, and the sky stays idealized. Two
/// consumers exist — the living sky rendering (its Set → Display
/// toggle) and the weather dua offers (the adhkar layer's availability
/// gate and master switch).
enum WeatherInterest {
    static let livingSkyDefaultsKey = "IhsanLivingSkyEnabled"

    @MainActor
    static func isActive(settings: UserSettings?) -> Bool {
        if UserDefaults.standard.bool(forKey: livingSkyDefaultsKey) {
            return true
        }
        guard let settings else { return false }
        return AdhkarAvailability.isAvailable && settings.adhkarLayerEnabled
    }
}
