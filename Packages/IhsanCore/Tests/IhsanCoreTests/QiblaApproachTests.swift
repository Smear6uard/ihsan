import Foundation
import Testing
@testable import IhsanCore

@Suite("QiblaApproach")
struct QiblaApproachTests {

    @Test("far off-axis the instrument rests at the standing glow")
    func farIsAtRest() {
        let approach = QiblaApproach(absDelta: 90, isAligned: false)
        #expect(approach.stage == .far)
        #expect(approach.lancetGlow == QiblaApproach.standingGlow)
        #expect(approach.indexWarmth == 0)
        #expect(approach.bridgeStrength == 0)
        #expect(approach.ringWarmth == 0)
    }

    @Test("the approach band ramps the lancet glow and ring warmth")
    func approachRamps() {
        let mid = QiblaApproach(absDelta: 37.5, isAligned: false)
        #expect(mid.stage == .approach)
        #expect(mid.lancetGlow > QiblaApproach.standingGlow)
        #expect(mid.lancetGlow < 1)
        #expect(mid.ringWarmth > 0)
        #expect(mid.ringWarmth < 1)
        // The index and bridge wait for the near band.
        #expect(mid.indexWarmth == 0)
        #expect(mid.bridgeStrength == 0)
    }

    @Test("the near band wakes the index and the bridge")
    func nearWakesIndexAndBridge() {
        let near = QiblaApproach(absDelta: 9, isAligned: false)
        #expect(near.stage == .near)
        #expect(near.indexWarmth > 0)
        #expect(near.indexWarmth < 1)
        #expect(near.bridgeStrength > 0)
        #expect(near.bridgeStrength < 1)
        #expect(near.ringWarmth == 1)
    }

    @Test("alignment saturates every curve regardless of delta")
    func alignedSaturates() {
        // Hysteresis can hold alignment out to 6°; the visuals follow
        // the gate, not the raw delta.
        let aligned = QiblaApproach(absDelta: 5, isAligned: true)
        #expect(aligned.stage == .aligned)
        #expect(aligned.lancetGlow == 1)
        #expect(aligned.indexWarmth == 1)
        #expect(aligned.bridgeStrength == 1)
    }

    @Test("every curve is monotone as the delta shrinks")
    func curvesAreMonotone() {
        var previous = QiblaApproach(absDelta: 120, isAligned: false)
        for delta in stride(from: 119.0, through: 3.0, by: -1.0) {
            let next = QiblaApproach(absDelta: delta, isAligned: false)
            #expect(next.lancetGlow >= previous.lancetGlow, "lancetGlow at \(delta)")
            #expect(next.indexWarmth >= previous.indexWarmth, "indexWarmth at \(delta)")
            #expect(next.bridgeStrength >= previous.bridgeStrength, "bridgeStrength at \(delta)")
            #expect(next.ringWarmth >= previous.ringWarmth, "ringWarmth at \(delta)")
            previous = next
        }
    }

    @Test("stage boundaries are continuous — no visible jumps")
    func boundariesAreContinuous() {
        for boundary in [60.0, 15.0] {
            let above = QiblaApproach(absDelta: boundary + 0.01, isAligned: false)
            let below = QiblaApproach(absDelta: boundary - 0.01, isAligned: false)
            #expect(abs(above.lancetGlow - below.lancetGlow) < 0.01)
            #expect(abs(above.indexWarmth - below.indexWarmth) < 0.01)
            #expect(abs(above.bridgeStrength - below.bridgeStrength) < 0.01)
            #expect(abs(above.ringWarmth - below.ringWarmth) < 0.01)
        }
    }

    @Test("Reduce Motion quantizes to one value per stage")
    func reducedMotionIsDiscrete() {
        let a = QiblaApproach(absDelta: 55, isAligned: false, discrete: true)
        let b = QiblaApproach(absDelta: 20, isAligned: false, discrete: true)
        #expect(a.lancetGlow == b.lancetGlow)
        #expect(a.stage == b.stage)
        let near1 = QiblaApproach(absDelta: 12, isAligned: false, discrete: true)
        let near2 = QiblaApproach(absDelta: 4, isAligned: false, discrete: true)
        #expect(near1.lancetGlow == near2.lancetGlow)
        #expect(near1.bridgeStrength == near2.bridgeStrength)
    }
}

@Suite("QiblaDetentLatch")
struct QiblaDetentLatchTests {

    @Test("crossing under the threshold fires once")
    func firesOnceOnCrossing() {
        var latch = QiblaDetentLatch(threshold: 15)
        #expect(latch.update(absDelta: 20) == false)
        #expect(latch.update(absDelta: 14.5) == true)
        #expect(latch.update(absDelta: 13) == false)
        #expect(latch.update(absDelta: 14.9) == false)
    }

    @Test("jitter around the threshold cannot re-fire")
    func jitterCannotRefire() {
        var latch = QiblaDetentLatch(threshold: 15)
        _ = latch.update(absDelta: 14)
        var fires = 0
        for delta in [15.4, 14.6, 15.8, 14.2, 16.5, 14.0] where latch.update(absDelta: delta) {
            fires += 1
        }
        #expect(fires == 0)
    }

    @Test("re-arms only after retreating past threshold plus margin")
    func rearmsAfterRetreat() {
        var latch = QiblaDetentLatch(threshold: 15, rearmMargin: 5)
        #expect(latch.update(absDelta: 10) == true)
        #expect(latch.update(absDelta: 18) == false)  // inside re-arm margin
        #expect(latch.update(absDelta: 14) == false)  // not re-armed: no fire
        #expect(latch.update(absDelta: 21) == false)  // retreated past 20: re-arms
        #expect(latch.update(absDelta: 12) == true)   // second genuine approach
    }
}
