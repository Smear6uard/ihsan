import Testing
@testable import ihsan

@Suite("Qibla dial stabilizer")
struct QiblaDialStabilizerTests {
    @Test("alignment seats once and ignores in-band sensor shimmer")
    func alignmentHoldsStill() {
        var stabilizer = QiblaDialStabilizer()

        #expect(stabilizer.update(
            smoothedHeading: 54,
            qiblaBearing: 58,
            isAligned: false
        ) == 54)
        #expect(stabilizer.update(
            smoothedHeading: 56.5,
            qiblaBearing: 58,
            isAligned: true
        ) == 58)

        for noisyHeading in [57.2, 58.9, 56.4, 59.1] {
            #expect(stabilizer.update(
                smoothedHeading: noisyHeading,
                qiblaBearing: 58,
                isAligned: true
            ) == 58)
        }
    }

    @Test("leaving alignment releases by the shortest rotation")
    func exitReleasesContinuously() {
        var stabilizer = QiblaDialStabilizer()
        _ = stabilizer.update(smoothedHeading: 358, qiblaBearing: 0, isAligned: true)

        let released = stabilizer.update(
            smoothedHeading: 7,
            qiblaBearing: 0,
            isAligned: false
        )
        #expect(released == 7)
    }

    @Test("the 360 degree seam never takes the long way around")
    func wraparoundUsesShortArc() {
        var stabilizer = QiblaDialStabilizer()
        _ = stabilizer.update(smoothedHeading: 359, qiblaBearing: 80, isAligned: false)
        let next = stabilizer.update(
            smoothedHeading: 1,
            qiblaBearing: 80,
            isAligned: false
        )
        #expect(next == 361)
    }
}
