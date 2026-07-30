import Foundation
import IhsanCore
import IhsanLocation
import SwiftUI

/// Drives the qibla instrument from `QiblaEngine`. This is the only
/// object between CoreLocation's heading stream and the view — the
/// view renders `reading` and `dialRotation`, nothing else. No view
/// code touches CLLocationManager; the stream arrives through
/// `LocationProviding` and every derived number comes from the engine.
@Observable
@MainActor
final class QiblaViewModel {

    /// Which surface to show. `nil` while the ladder is resolving.
    private(set) var availability: QiblaAvailability?

    /// Latest engine output; `nil` until the first heading sample.
    private(set) var reading: QiblaEngine.Reading?

    /// Continuous, unwrapped dial angle in degrees. Equal to the
    /// smoothed heading but accumulated across the 360/0 seam, so the
    /// view can rotate the card by `-dialRotation` and SwiftUI never
    /// tweens the long way around.
    private(set) var dialRotation: Double = 0

    /// Great-circle bearing to the Kaaba, degrees from true north.
    private(set) var qiblaBearing: Double = 0
    /// Great-circle distance to the Kaaba, kilometers.
    private(set) var distanceKm: Double = 0

    private var engine: QiblaEngine?
    private let locationProvider: LocationProviding
    @ObservationIgnored private var headingTask: Task<Void, Never>?
    /// `-IhsanQiblaHeadingLog` launch argument: prints one line per
    /// sample (raw vs smoothed) so a real-device turn can be captured
    /// from the console for filter verification.
    private let logsHeading: Bool

    init(locationProvider: LocationProviding = CoreLocationCoordinator.shared) {
        self.locationProvider = locationProvider
        self.logsHeading = ProcessInfo.processInfo.arguments
            .contains("-IhsanQiblaHeadingLog")
    }

    /// Resolves the availability ladder and, when the instrument is
    /// live, starts consuming heading samples. The coordinates arrive
    /// from the Today snapshot's already-resolved place — transient,
    /// never persisted (privacy invariant #1).
    func bootstrap(latitude: Double, longitude: Double) async {
        let engine = QiblaEngine(latitude: latitude, longitude: longitude)
        qiblaBearing = engine.qiblaBearing
        distanceKm = engine.distanceKm
        self.engine = engine

        #if DEBUG
        if startSimulatedHeadingIfRequested() { return }
        #endif

        let authorization = await locationProvider.currentAuthorization()
        let resolved = QiblaAvailability.resolve(
            locationAuthorized: authorization.isAuthorized,
            compassAvailable: locationProvider.isHeadingAvailable()
        )
        availability = resolved
        guard resolved == .ready else { return }

        headingTask?.cancel()
        headingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let stream = try await self.locationProvider.headingUpdates()
                for await sample in stream {
                    if Task.isCancelled { return }
                    self.ingest(sample)
                }
            } catch {
                // The hardware probe said yes but the stream refused —
                // degrade to the static card rather than a dead dial.
                self.availability = .noCompassHardware
            }
        }
    }

    func stop() {
        headingTask?.cancel()
        headingTask = nil
    }

    private func ingest(_ sample: HeadingSample) {
        guard var engine else { return }
        let previous = reading?.smoothedHeading
        let next = engine.ingest(
            trueHeading: sample.trueHeading,
            magneticHeading: sample.magneticHeading,
            accuracy: sample.accuracy,
            timestamp: sample.timestamp
        )
        self.engine = engine

        if let previous {
            dialRotation += QiblaMath.signedDelta(from: previous, to: next.smoothedHeading)
        } else {
            dialRotation = next.smoothedHeading
        }
        reading = next

        if logsHeading {
            print(String(
                format: "QIBLA-TRACE t=%.3f raw=%7.2f smoothed=%7.2f delta=%7.2f",
                sample.timestamp.timeIntervalSinceReferenceDate,
                next.rawHeading,
                next.smoothedHeading,
                next.signedDelta
            ))
        }
    }

    deinit {
        headingTask?.cancel()
    }

    // MARK: - Simulator verification harness

    #if DEBUG
    /// `-IhsanQiblaSimulateHeading <mode>` — the simulator has no
    /// magnetometer, so screenshots and turn recordings drive the
    /// instrument through a synthetic sample stream at 20 Hz:
    ///
    /// - `turn` — a continuous slow rotation (18°/s), for ring-motion
    ///   recordings and the full choreography sweep.
    /// - `delta:<degrees>` — hold the heading at a fixed signed offset
    ///   from the qibla bearing, for state screenshots.
    ///
    /// Debug builds only; the real ladder never runs in this mode.
    private func startSimulatedHeadingIfRequested() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-IhsanQiblaSimulateHeading"),
              let mode = arguments.dropFirst(flagIndex + 1).first
        else { return false }

        availability = .ready
        let bearing = qiblaBearing

        headingTask?.cancel()
        headingTask = Task { @MainActor [weak self] in
            let start = Date()
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(start)
                let heading: Double
                if mode.hasPrefix("delta:"), let offset = Double(mode.dropFirst(6)) {
                    heading = QiblaMath.normalized(bearing - offset)
                } else {
                    heading = QiblaMath.normalized(elapsed * 18)
                }
                self.ingest(HeadingSample(
                    trueHeading: heading,
                    magneticHeading: QiblaMath.normalized(heading + 4.2),
                    accuracy: 8,
                    timestamp: Date()
                ))
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        return true
    }
    #endif
}
