import Foundation
import IhsanCore
import IhsanLocation
import SwiftUI
import UIKit

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

    /// The continuous choreography values for the current delta. The
    /// view quantizes these itself under Reduce Motion.
    private(set) var approach = QiblaApproach(absDelta: 180, isAligned: false)

    /// Increments once per alignment entry — the view's bloom plays
    /// exactly once per change, so it can structurally never repeat
    /// while alignment holds.
    private(set) var bloomCount = 0

    /// True after alignment has been held ~3 s: the inscriptions ease
    /// to their quietest opacity and the screen becomes just the
    /// instrument and the light.
    private(set) var isSettled = false

    private var engine: QiblaEngine?
    /// The two soft ticks of the approach — a fine instrument finding
    /// its seat. Latched: jitter at a boundary cannot re-fire them.
    private var detent15 = QiblaDetentLatch(threshold: 15)
    private var detent5 = QiblaDetentLatch(threshold: 5, rearmMargin: 4)
    private var guidanceScript = QiblaGuidanceScript()
    private var hasAnnouncedEntry = false
    @ObservationIgnored private var settleTask: Task<Void, Never>?
    @ObservationIgnored private var lastDetentAt: Date?
    private let locationProvider: LocationProviding
    @ObservationIgnored private var headingTask: Task<Void, Never>?
    /// `-IhsanQiblaHeadingLog` launch argument: prints one line per
    /// sample (raw vs smoothed) so a real-device turn can be captured
    /// from the console for filter verification.
    private let logsHeading: Bool

    init(locationProvider: LocationProviding = CoreLocationCoordinator.shared) {
        self.locationProvider = locationProvider
        self.logsHeading = DebugLaunch.flag("-IhsanQiblaHeadingLog")
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
        settleTask?.cancel()
        settleTask = nil
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
        choreograph(next)
        announceGuidance(next, at: sample.timestamp)

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

    // MARK: - Choreography

    /// One reading → one choreography step: curves, detents, the
    /// single alignment haptic, and the settle timer. All single-fire
    /// guarantees live in the tested latches and the engine's
    /// hysteresis gate — nothing here can machine-gun.
    private func choreograph(_ next: QiblaEngine.Reading) {
        let absDelta = abs(next.signedDelta)
        approach = QiblaApproach(absDelta: absDelta, isAligned: next.isAligned)

        if !next.isAligned {
            let clicked15 = detent15.update(absDelta: absDelta)
            let clicked5 = detent5.update(absDelta: absDelta)
            if clicked15 || clicked5 { playDetent() }
        }

        switch next.alignmentEvent {
        case .entered:
            // Arrival is the qibla's commit: the same settle a logged
            // prayer makes. Never rate-limited away.
            Haptics.settle()
            if logsHeading { print("QIBLA-HAPTIC aligned-entry") }
            bloomCount += 1
            settleTask?.cancel()
            settleTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                self?.isSettled = true
            }
        case .exited:
            // Graceful reversal: no feedback, no negative state — the
            // instrument never scolds.
            settleTask?.cancel()
            isSettled = false
        case .unchanged:
            break
        }
    }

    // MARK: - VoiceOver guidance

    /// Speaks the guidance script's lines. The script owns the whole
    /// policy (bands, rate limit, alignment priority) and is unit
    /// tested; this method only adds the one-time entry orientation
    /// (distance + direction) and posts the announcement.
    private func announceGuidance(_ next: QiblaEngine.Reading, at timestamp: Date) {
        guard let line = guidanceScript.update(
            signedDelta: next.signedDelta,
            isAligned: next.isAligned,
            at: timestamp
        ) else { return }

        let spoken: String
        if hasAnnouncedEntry {
            spoken = line
        } else {
            hasAnnouncedEntry = true
            spoken = QiblaInscriptions.spokenDistance(km: distanceKm) + ". " + line
        }
        if logsHeading { print("QIBLA-VOICE \(spoken)") }
        guard UIAccessibility.isVoiceOverRunning else { return }
        AccessibilityNotification.Announcement(spoken).post()
    }

    /// The detents are spaced 10° apart, so they cannot stack in
    /// normal turning; the interval guard only catches pathological
    /// sample bursts.
    private func playDetent() {
        let now = Date()
        if let last = lastDetentAt, now.timeIntervalSince(last) < 0.2 { return }
        lastDetentAt = now
        Haptics.impact(.light)
        if logsHeading { print("QIBLA-HAPTIC detent") }
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
    /// - `calib` — hold 30° off with degraded accuracy, for the
    ///   calibration state.
    /// - `denied` — resolve straight to the location-denied surface.
    ///
    /// Debug builds only; the real ladder never runs in this mode.
    private func startSimulatedHeadingIfRequested() -> Bool {
        guard let mode = DebugLaunch.value(after: "-IhsanQiblaSimulateHeading")
        else { return false }

        if mode == "denied" {
            availability = .locationDenied
            return true
        }

        availability = .ready
        let bearing = qiblaBearing

        headingTask?.cancel()
        headingTask = Task { @MainActor [weak self] in
            let start = Date()
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(start)
                let heading: Double
                var accuracy = 8.0
                if mode.hasPrefix("delta:"), let offset = Double(mode.dropFirst(6)) {
                    heading = QiblaMath.normalized(bearing - offset)
                } else if mode == "calib" {
                    heading = QiblaMath.normalized(bearing - 30)
                    accuracy = 35
                } else {
                    heading = QiblaMath.normalized(elapsed * 18)
                }
                self.ingest(HeadingSample(
                    trueHeading: heading,
                    magneticHeading: QiblaMath.normalized(heading + 4.2),
                    accuracy: accuracy,
                    timestamp: Date()
                ))
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        return true
    }
    #endif
}
