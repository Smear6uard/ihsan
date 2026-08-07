import IhsanCore

/// Converts filtered compass headings into one continuous visual angle.
///
/// The engine deliberately accepts a small alignment band because a
/// hand-held magnetometer never sits at an exact degree. Once that band
/// is entered, the dial takes its seat at the qibla bearing and holds
/// there until the engine's wider exit threshold is crossed. Sensor
/// shimmer can therefore never make an already-aligned lancet chatter
/// around the fixed index.
struct QiblaDialStabilizer {
    private(set) var rotation: Double = 0
    private var displayedHeading: Double?

    mutating func update(
        smoothedHeading: Double,
        qiblaBearing: Double,
        isAligned: Bool
    ) -> Double {
        let target = QiblaMath.normalized(isAligned ? qiblaBearing : smoothedHeading)

        if let displayedHeading {
            rotation += QiblaMath.signedDelta(from: displayedHeading, to: target)
        } else {
            rotation = target
        }

        displayedHeading = target
        return rotation
    }

    mutating func reset() {
        rotation = 0
        displayedHeading = nil
    }
}
