import Foundation
import SwiftUI
import IhsanLocation
import IhsanPrayerTimes

@Observable
@MainActor
final class MasjidFinderViewModel {
    var state: MasjidFinderState = .loading
    var cityName: String?

    private let locationProvider: LocationProviding
    private let searchService: any MasjidSearching
    private var currentCoordinates: Coordinates?

    /// The default service is built in the body, not as a default
    /// argument: default arguments are evaluated outside the main actor,
    /// and on the Xcode 27 toolchain building the service there warned.
    init(
        locationProvider: any LocationProviding = CoreLocationCoordinator.shared,
        searchService: (any MasjidSearching)? = nil
    ) {
        self.locationProvider = locationProvider
        self.searchService = searchService ?? MasjidSearchService()
    }

    func bootstrap() async {
        do {
            let auth = await locationProvider.currentAuthorization()
            guard auth.isAuthorized else {
                if auth == .denied || auth == .restricted {
                    Haptics.notification(.warning)
                }
                state = .needsLocationPermission
                return
            }

            let place = try await locationProvider.currentPlace()
            self.currentCoordinates = place.coordinates
            self.cityName = place.cityName
            await search()
        } catch let error as LocationError {
            if error == .permissionDenied || error == .permissionRestricted {
                Haptics.notification(.warning)
                state = .needsLocationPermission
            } else {
                state = .failure
            }
        } catch {
            state = .failure
        }
    }

    private func search() async {
        guard let coordinates = currentCoordinates else { return }
        state = .loading
        do {
            let results = try await searchService.search(near: coordinates)
            state = results.isEmpty ? .empty : .ready(results)
        } catch {
            state = .failure
        }
    }

    func retry() async {
        if currentCoordinates == nil {
            await bootstrap()
        } else {
            await search()
        }
    }

    func openInMaps(_ result: MasjidResult) {
        result.openInMaps()
    }
}
