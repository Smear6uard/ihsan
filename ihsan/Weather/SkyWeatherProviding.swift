import Foundation
import IhsanCore
import IhsanPrayerTimes

/// One question, asked of whatever weather source stands behind it:
/// what is the sky doing here, now?
///
/// The coordinates are used to ask and then discarded — implementations
/// must retain, persist, and log nothing about where the question was
/// asked, in the exact mold of `MasjidSearching`.
protocol SkyWeatherProviding: Sendable {
    func currentConditions(at coordinates: Coordinates, asOf now: Date) async throws -> SkyConditions
}
