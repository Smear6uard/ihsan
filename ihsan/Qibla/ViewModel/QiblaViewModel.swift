import Foundation
import SwiftUI
import IhsanLocation
import IhsanPrayerTimes

@Observable
@MainActor
final class QiblaViewModel {
    var state: QiblaState = .loading
    /// Smoothed device heading in degrees (0–360). Drives the dial rotation.
    var smoothedHeading: Double = 0
    /// Negative when invalid; > 20° when the magnetometer wants a figure-8.
    /// LocationProviding's heading stream currently emits only heading values,
    /// so this stays at -1 until accuracy is plumbed through the API.
    var headingAccuracy: Double = -1
    /// True when the device is pointed within ±3° of qibla.
    var isAligned: Bool = false

    private let locationProvider: LocationProviding
    private let smoother = HeadingSmoother(alpha: 0.18)
    @ObservationIgnored private nonisolated(unsafe) var headingTask: Task<Void, Never>?

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
            state = .ready(.init(
                cityName: place.cityName,
                coordinates: place.coordinates,
                qiblaBearing: place.coordinates.qiblaBearing,
                distanceToMakkahKm: place.coordinates.distanceToKaaba
            ))

            startHeadingUpdates()
        } catch let error as LocationError {
            state = .error(error.userFacingMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func startHeadingUpdates() {
        headingTask?.cancel()
        headingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let stream = try await self.locationProvider.headingUpdates()
                for await rawHeading in stream {
                    self.smoothedHeading = self.smoother.smooth(rawHeading)
                    self.checkAlignment()
                }
            } catch {
                // Heading unavailable (iPad, simulator). The dial stays
                // static at 0; bearing/distance still display correctly.
            }
        }
    }

    private func checkAlignment() {
        guard case .ready(let snapshot) = state else { return }
        let delta = Self.angleDelta(smoothedHeading, snapshot.qiblaBearing)
        let alignedNow = abs(delta) <= 3
        if alignedNow && !isAligned {
            Haptics.success()
        }
        isAligned = alignedNow
    }

    /// Signed shortest angular difference between two compass bearings,
    /// in (-180, 180]. Used to decide when the device is "facing" qibla.
    static func angleDelta(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    deinit {
        headingTask?.cancel()
    }
}
