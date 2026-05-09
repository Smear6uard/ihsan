import Foundation
import SwiftUI
import IhsanLocation
import IhsanPrayerTimes

@Observable
@MainActor
final class MasjidFinderViewModel {
    var state: MasjidFinderState = .loading
    var radius: SearchRadius = .fiveKm {
        didSet {
            guard radius != oldValue else { return }
            Task { await search() }
        }
    }
    var cityName: String?

    private let locationProvider: LocationProviding
    private let searchService = MasjidSearchService()
    private var currentCoordinates: Coordinates?

    init(locationProvider: LocationProviding = CoreLocationCoordinator.shared) {
        self.locationProvider = locationProvider
    }

    func bootstrap() async {
        do {
            let auth = await locationProvider.currentAuthorization()
            guard auth.isAuthorized else {
                state = .needsLocationPermission
                return
            }

            let place = try await locationProvider.currentPlace()
            self.currentCoordinates = place.coordinates
            self.cityName = place.cityName
            await search()
        } catch let error as LocationError {
            state = .error(error.userFacingMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func search() async {
        guard let coordinates = currentCoordinates else { return }
        state = .loading
        do {
            let results = try await searchService.search(
                near: coordinates,
                radiusKm: radius.rawValue
            )
            state = results.isEmpty ? .empty : .ready(results)
        } catch {
            state = .error("Could not search nearby masjids. Try again.")
        }
    }

    func openInMaps(_ result: MasjidResult) {
        result.openInMaps()
    }
}
