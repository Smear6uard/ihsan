import Foundation
import Testing
@testable import IhsanCore

@Suite("QiblaEngine")
struct QiblaEngineTests {

    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    /// New York: published qibla 58.481°, distance ≈ 10 306 km.
    private func newYorkEngine() -> QiblaEngine {
        QiblaEngine(latitude: 40.7128, longitude: -74.0059)
    }

    // MARK: - Static geometry

    @Test("exposes bearing and distance for the configured location")
    func staticGeometry() {
        let engine = newYorkEngine()
        #expect(abs(engine.qiblaBearing - 58.481) < 0.5)
        #expect(abs(engine.distanceKm - 10306.3) < 5)
    }

    // MARK: - Reading composition

    @Test("the first reading passes the raw heading through and signs the delta")
    func firstReading() {
        var engine = newYorkEngine()
        let reading = engine.ingest(
            trueHeading: 10, magneticHeading: 355, accuracy: 5, timestamp: t0
        )
        #expect(reading.rawHeading == 10)
        #expect(reading.smoothedHeading == 10)
        // Qibla at ~58.5°, facing 10°: the qibla is ~48.5° to the right.
        #expect(abs(reading.signedDelta - 48.481) < 0.5)
        #expect(reading.signedDelta > 0)
        #expect(abs(reading.distanceKm - 10306.3) < 5)
    }

    @Test("a target to the left carries a negative delta")
    func leftwardDelta() {
        var engine = newYorkEngine()
        let reading = engine.ingest(
            trueHeading: 90, magneticHeading: 90, accuracy: 5, timestamp: t0
        )
        // Facing 90°, qibla at ~58.5°: ~31.5° to the left.
        #expect(reading.signedDelta < 0)
        #expect(abs(reading.signedDelta + 31.519) < 0.5)
    }

    // MARK: - North reference resolution (automatic, no toggle)

    @Test("a valid true heading resolves to true north")
    func trueNorthPreferred() {
        var engine = newYorkEngine()
        let reading = engine.ingest(
            trueHeading: 58, magneticHeading: 45, accuracy: 5, timestamp: t0
        )
        #expect(reading.northReference == .trueNorth)
        #expect(reading.rawHeading == 58)
    }

    @Test("an invalid true heading falls back to magnetic north")
    func magneticFallback() {
        var engine = newYorkEngine()
        let reading = engine.ingest(
            trueHeading: -1, magneticHeading: 45, accuracy: 5, timestamp: t0
        )
        #expect(reading.northReference == .magneticNorth)
        #expect(reading.rawHeading == 45)
    }

    // MARK: - Calibration quality

    @Test("calibration quality tracks heading accuracy", arguments: [
        (5.0, QiblaEngine.CalibrationQuality.good),
        (20.0, QiblaEngine.CalibrationQuality.good),
        (25.0, QiblaEngine.CalibrationQuality.poor),
        (-1.0, QiblaEngine.CalibrationQuality.invalid),
    ])
    func calibrationQuality(accuracy: Double, expected: QiblaEngine.CalibrationQuality) {
        var engine = newYorkEngine()
        let reading = engine.ingest(
            trueHeading: 100, magneticHeading: 100, accuracy: accuracy, timestamp: t0
        )
        #expect(reading.calibration == expected)
    }

    @Test("an invalid sample cannot disturb an aligned instrument")
    func invalidSampleHoldsLastValidHeading() {
        var engine = newYorkEngine()
        let bearing = engine.qiblaBearing
        let aligned = engine.ingest(
            trueHeading: bearing,
            magneticHeading: bearing,
            accuracy: 4,
            timestamp: t0
        )
        #expect(aligned.isAligned)

        let invalid = engine.ingest(
            trueHeading: QiblaMath.normalized(bearing + 120),
            magneticHeading: QiblaMath.normalized(bearing + 120),
            accuracy: -1,
            timestamp: t0.addingTimeInterval(0.1)
        )

        #expect(invalid.smoothedHeading == aligned.smoothedHeading)
        #expect(invalid.signedDelta == aligned.signedDelta)
        #expect(invalid.alignmentEvent == .unchanged)
        #expect(invalid.isAligned)
    }

    @Test("an invalid first sample cannot announce alignment")
    func invalidFirstSampleCannotEnterAlignment() {
        var engine = newYorkEngine()
        let bearing = engine.qiblaBearing
        let reading = engine.ingest(
            trueHeading: bearing,
            magneticHeading: bearing,
            accuracy: -1,
            timestamp: t0
        )

        #expect(reading.alignmentEvent == .unchanged)
        #expect(!reading.isAligned)
    }

    // MARK: - Alignment through the engine

    @Test("a slow turn into the band fires .entered exactly once")
    func syntheticTurnSingleFire() {
        var engine = newYorkEngine()
        let bearing = engine.qiblaBearing
        var entered = 0
        var exited = 0

        // Sweep from 90° off-axis onto the bearing in 1° steps at 20 Hz,
        // then jitter ±1° inside the band — the boundary crossing must
        // fire once and the jitter must never re-fire it.
        var step = 0
        for offset in stride(from: 90.0, through: 0, by: -1) {
            let heading = QiblaMath.normalized(bearing + offset)
            let reading = engine.ingest(
                trueHeading: heading, magneticHeading: heading, accuracy: 5,
                timestamp: t0.addingTimeInterval(Double(step) * 0.05)
            )
            if reading.alignmentEvent == .entered { entered += 1 }
            if reading.alignmentEvent == .exited { exited += 1 }
            step += 1
        }
        for jitter in [0.8, -0.6, 1.0, -1.0, 0.5] {
            let heading = QiblaMath.normalized(bearing + jitter)
            let reading = engine.ingest(
                trueHeading: heading, magneticHeading: heading, accuracy: 5,
                timestamp: t0.addingTimeInterval(Double(step) * 0.05)
            )
            if reading.alignmentEvent == .entered { entered += 1 }
            step += 1
        }

        #expect(entered == 1)
        #expect(exited == 0)
        #expect(engine.isAligned)
    }

    @Test("leaving and returning fires .entered a second time")
    func reentryFiresAgain() {
        var engine = newYorkEngine()
        let bearing = engine.qiblaBearing
        var entered = 0
        var step = 0

        // Approach → aligned → swing 30° away → return. Large dt between
        // samples so the filter tracks the raw heading closely.
        for target in [bearing + 40, bearing, bearing + 30, bearing] {
            for _ in 0..<30 {
                let reading = engine.ingest(
                    trueHeading: QiblaMath.normalized(target),
                    magneticHeading: QiblaMath.normalized(target),
                    accuracy: 5,
                    timestamp: t0.addingTimeInterval(Double(step) * 0.1)
                )
                if reading.alignmentEvent == .entered { entered += 1 }
                step += 1
            }
        }
        #expect(entered == 2)
    }

    @Test("alignment is judged on the smoothed heading, not the raw jump")
    func alignmentUsesSmoothedHeading() {
        var engine = newYorkEngine()
        let bearing = engine.qiblaBearing
        // Seed the filter far off-axis, then jump raw straight onto the
        // bearing 50 ms later. The smoothed dial hasn't arrived yet, so
        // alignment must not fire on that first jump.
        _ = engine.ingest(
            trueHeading: QiblaMath.normalized(bearing + 90),
            magneticHeading: 0, accuracy: 5, timestamp: t0
        )
        let reading = engine.ingest(
            trueHeading: bearing, magneticHeading: bearing, accuracy: 5,
            timestamp: t0.addingTimeInterval(0.05)
        )
        #expect(reading.alignmentEvent == .unchanged)
        #expect(reading.isAligned == false)
    }

    // MARK: - Availability ladder

    @Test("availability resolves denied above missing hardware", arguments: [
        (true, true, QiblaAvailability.ready),
        (false, true, QiblaAvailability.locationDenied),
        (true, false, QiblaAvailability.noCompassHardware),
        (false, false, QiblaAvailability.locationDenied),
    ])
    func availabilityLadder(
        locationAuthorized: Bool, compassAvailable: Bool, expected: QiblaAvailability
    ) {
        let resolved = QiblaAvailability.resolve(
            locationAuthorized: locationAuthorized,
            compassAvailable: compassAvailable
        )
        #expect(resolved == expected)
    }
}
