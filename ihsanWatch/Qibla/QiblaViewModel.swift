import Foundation
import SwiftUI
import IhsanLocation
import IhsanPrayerTimes

@Observable
@MainActor
final class QiblaViewModel {
    var state: QiblaState = .loading
    var smoothedHeading: Double = 0
    var headingAccuracy: Double = -1
    var isAligned: Bool = false

    private let locationProvider: LocationProviding
    private let smoother = HeadingSmoother(alpha: 0.18)

    @ObservationIgnored
    private nonisolated(unsafe) var headingTask: Task<Void, Never>?

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
            let snapshot = QiblaState.Snapshot(
                cityName: place.cityName,
                coordinates: place.coordinates,
                qiblaBearing: place.coordinates.qiblaBearing,
                distanceToMakkahKm: place.coordinates.distanceToKaaba
            )

            // Hardware check before subscribing to the heading stream.
            // On Series 3/4 and the first SE, the magnetometer isn't
            // available — show distance + bearing only, no spinning
            // dial. The check is delegated to `LocationProviding` so
            // the watch app doesn't import CoreLocation directly.
            guard locationProvider.isHeadingAvailable() else {
                state = .compassUnavailable(snapshot)
                return
            }

            state = .ready(snapshot)
            startHeadingUpdates()
        } catch let error as LocationError {
            state = .error(error.userFacingMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func stop() {
        headingTask?.cancel()
        headingTask = nil
    }

    private func startHeadingUpdates() {
        headingTask?.cancel()
        headingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let stream = try await self.locationProvider.headingUpdates()
                for await sample in stream {
                    self.smoothedHeading = self.smoother.smooth(sample.preferredHeading)
                    self.headingAccuracy = sample.accuracy
                    self.checkAlignment()
                }
            } catch {
                // Heading stream threw mid-flight; demote to compass-
                // unavailable so the view stops promising a live dial.
                if case .ready(let snapshot) = self.state {
                    self.state = .compassUnavailable(snapshot)
                }
            }
        }
    }

    private func checkAlignment() {
        guard case .ready(let snapshot) = state else { return }
        let delta = Self.angleDelta(smoothedHeading, snapshot.qiblaBearing)
        let alignedNow = abs(delta) <= 3
        if alignedNow && !isAligned {
            WatchHaptics.notification()
        }
        isAligned = alignedNow
    }

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
