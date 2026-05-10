import Foundation

/// A single compass heading reading from the device.
public struct HeadingSample: Sendable, Hashable {
    /// True heading (corrected for magnetic declination), in degrees
    /// from true north, 0-360. Returns -1 if true heading is unavailable
    /// (no recent location fix).
    public let trueHeading: Double

    /// Magnetic heading, in degrees from magnetic north, 0-360.
    /// Always available when the compass is reporting.
    public let magneticHeading: Double

    /// Heading accuracy in degrees. Negative values indicate invalid
    /// readings. Lower magnitudes are better (e.g., 5° is good, 40° is
    /// poor). iOS recommends prompting calibration when accuracy is
    /// negative or exceeds about 20°.
    public let accuracy: Double

    /// When this sample was recorded.
    public let timestamp: Date

    public init(
        trueHeading: Double,
        magneticHeading: Double,
        accuracy: Double,
        timestamp: Date
    ) {
        self.trueHeading = trueHeading
        self.magneticHeading = magneticHeading
        self.accuracy = accuracy
        self.timestamp = timestamp
    }

    /// The preferred heading to display. Returns trueHeading if valid,
    /// otherwise falls back to magneticHeading. The Qibla compass uses
    /// this since qibla bearing is computed in true coordinates.
    public var preferredHeading: Double {
        trueHeading >= 0 ? trueHeading : magneticHeading
    }

    /// Whether this sample's accuracy is good enough for direction-
    /// critical features (Qibla, navigation). Returns true when accuracy
    /// is non-negative and ≤ 20°.
    public var isAccuracyAcceptable: Bool {
        accuracy >= 0 && accuracy <= 20
    }
}
