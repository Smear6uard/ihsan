import Foundation

/// The qibla instrument's brain: pure, synchronous, and platform-free.
///
/// The engine owns the whole heading pipeline — smoothing, delta,
/// alignment hysteresis, calibration quality, north-reference
/// resolution — so the view layer only renders `Reading`s. Feed it one
/// heading sample at a time (the view model adapts CoreLocation's
/// stream); every input and output is plain degrees, kilometers, and
/// value types, which is what makes the alignment choreography
/// testable without a magnetometer in the room.
public struct QiblaEngine: Sendable {

    /// How trustworthy the current compass reading is.
    public enum CalibrationQuality: Sendable {
        /// Accuracy within 20° — normal operation.
        case good
        /// Accuracy worse than 20° — show the calibration state.
        case poor
        /// Negative accuracy: the reading is invalid.
        case invalid
    }

    /// Which north the displayed heading is measured from. Resolution
    /// is automatic — never a user toggle. CoreLocation supplies true
    /// heading whenever it has a location fix; when only the magnetic
    /// heading exists the instrument keeps working against magnetic
    /// north and says so in a quiet inscription (the qibla bearing is
    /// computed from true north, so a local declination-sized error is
    /// possible in that fallback — being honest about the mode is the
    /// design).
    public enum NorthReference: Sendable {
        case trueNorth
        case magneticNorth
    }

    /// One frame of instrument state, derived from one heading sample.
    public struct Reading: Sendable {
        /// The heading as delivered by the hardware, degrees [0, 360).
        public let rawHeading: Double
        /// The damped heading that drives the dial, degrees [0, 360).
        public let smoothedHeading: Double
        /// Great-circle bearing to the Kaaba, degrees from true north.
        public let qiblaBearing: Double
        /// Shortest rotation from the smoothed heading to the qibla,
        /// (-180, 180]. Positive means the qibla is to the user's right.
        public let signedDelta: Double
        /// Great-circle distance to the Kaaba in kilometers.
        public let distanceKm: Double
        /// Which north the heading is measured from this frame.
        public let northReference: NorthReference
        /// Compass trustworthiness this frame.
        public let calibration: CalibrationQuality
        /// Hysteresis transition, if any, caused by this sample.
        public let alignmentEvent: QiblaAlignmentGate.Event
        /// Whether the instrument is inside the aligned band.
        public let isAligned: Bool
    }

    /// Bearing to the Kaaba from the configured location, degrees from
    /// true north.
    public let qiblaBearing: Double
    /// Distance to the Kaaba from the configured location, kilometers.
    public let distanceKm: Double

    /// Whether the smoothed heading currently sits inside the aligned band.
    public var isAligned: Bool { gate.isAligned }

    private var filter: HeadingFilter
    private var gate: QiblaAlignmentGate

    public init(
        latitude: Double,
        longitude: Double,
        timeConstant: TimeInterval = HeadingFilter.defaultTimeConstant,
        enterDegrees: Double = 3,
        exitDegrees: Double = 6
    ) {
        self.qiblaBearing = QiblaMath.qiblaBearing(latitude: latitude, longitude: longitude)
        self.distanceKm = QiblaMath.kaabaDistanceKm(latitude: latitude, longitude: longitude)
        self.filter = HeadingFilter(timeConstant: timeConstant)
        self.gate = QiblaAlignmentGate(enterDegrees: enterDegrees, exitDegrees: exitDegrees)
    }

    /// Ingests one heading sample and returns the instrument state it
    /// produces. CoreLocation reports an unavailable true heading as a
    /// negative value; the engine then falls back to magnetic north.
    /// Alignment is judged on the smoothed heading — the dial the eye
    /// is watching — so the haptic can never fire ahead of the visual.
    public mutating func ingest(
        trueHeading: Double,
        magneticHeading: Double,
        accuracy: Double,
        timestamp: Date
    ) -> Reading {
        let (raw, reference): (Double, NorthReference) = trueHeading >= 0
            ? (trueHeading, .trueNorth)
            : (magneticHeading, .magneticNorth)

        let normalizedRaw = QiblaMath.normalized(raw)
        let smoothed = filter.smooth(normalizedRaw, at: timestamp)
        let delta = QiblaMath.signedDelta(from: smoothed, to: qiblaBearing)
        let event = gate.update(signedDelta: delta)

        let calibration: CalibrationQuality = if accuracy < 0 {
            .invalid
        } else if accuracy > 20 {
            .poor
        } else {
            .good
        }

        return Reading(
            rawHeading: normalizedRaw,
            smoothedHeading: smoothed,
            qiblaBearing: qiblaBearing,
            signedDelta: delta,
            distanceKm: distanceKm,
            northReference: reference,
            calibration: calibration,
            alignmentEvent: event,
            isAligned: gate.isAligned
        )
    }
}

/// The explicit fallback ladder for the qibla screen. Exactly one state
/// is active; each maps to a distinct, designed surface — never a blank
/// or broken instrument.
public enum QiblaAvailability: Sendable, Equatable {
    /// Location and compass both live — show the instrument.
    case ready
    /// Location permission missing: without a location there is no
    /// bearing at all, so this outranks a missing compass. Explain,
    /// with a one-line path to Settings.
    case locationDenied
    /// No magnetometer (iPad, simulator): show the static bearing card
    /// with a fixed dial.
    case noCompassHardware

    public static func resolve(
        locationAuthorized: Bool,
        compassAvailable: Bool
    ) -> QiblaAvailability {
        guard locationAuthorized else { return .locationDenied }
        guard compassAvailable else { return .noCompassHardware }
        return .ready
    }
}
