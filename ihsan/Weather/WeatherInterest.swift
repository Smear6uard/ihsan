import Foundation
import IhsanCore

/// Whether anything in the app currently wants weather at all.
///
/// The fetch gate, written down once: with no interested consumer the
/// spine never touches the network, and the sky stays idealized. The
/// weather dua offers ride the adhkar layer's own availability gate and
/// master switch. The living sky toggle joins this disjunction when it
/// ships behind its Phase 3 gates.
enum WeatherInterest {
    @MainActor
    static func isActive(settings: UserSettings?) -> Bool {
        guard let settings else { return false }
        return AdhkarAvailability.isAvailable && settings.adhkarLayerEnabled
    }
}
