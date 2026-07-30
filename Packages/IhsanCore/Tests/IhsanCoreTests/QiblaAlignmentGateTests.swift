import Foundation
import Testing
@testable import IhsanCore

@Suite("QiblaAlignmentGate")
struct QiblaAlignmentGateTests {

    @Test("starts unaligned and stays unaligned outside the band")
    func startsUnaligned() {
        var gate = QiblaAlignmentGate()
        #expect(gate.isAligned == false)
        #expect(gate.update(signedDelta: 10) == .unchanged)
        #expect(gate.isAligned == false)
    }

    @Test("entering the ±3° band fires .entered exactly once")
    func entersAtThreeDegrees() {
        var gate = QiblaAlignmentGate()
        #expect(gate.update(signedDelta: 2.9) == .entered)
        #expect(gate.isAligned)
        #expect(gate.update(signedDelta: 1.0) == .unchanged)
    }

    @Test("the boundary is inclusive on entry, exclusive on exit")
    func boundaryConditions() {
        var gate = QiblaAlignmentGate()
        #expect(gate.update(signedDelta: 3.0) == .entered)
        #expect(gate.update(signedDelta: 6.0) == .unchanged)
        #expect(gate.isAligned)
        #expect(gate.update(signedDelta: 6.01) == .exited)
    }

    @Test("negative deltas align — the band is symmetric")
    func negativeDeltasAlign() {
        var gate = QiblaAlignmentGate()
        #expect(gate.update(signedDelta: -2.5) == .entered)
        #expect(gate.isAligned)
    }

    @Test("while aligned, drift into the 3–6° margin does not exit")
    func hysteresisHoldsInsideExitBand() {
        var gate = QiblaAlignmentGate()
        _ = gate.update(signedDelta: 1)
        #expect(gate.update(signedDelta: 4.5) == .unchanged)
        #expect(gate.update(signedDelta: 5.9) == .unchanged)
        #expect(gate.isAligned)
    }

    @Test("after exit, the 3–6° margin does not re-enter")
    func noReentryFromMargin() {
        var gate = QiblaAlignmentGate()
        _ = gate.update(signedDelta: 1)
        _ = gate.update(signedDelta: 7)
        #expect(gate.isAligned == false)
        #expect(gate.update(signedDelta: 4.5) == .unchanged)
        #expect(gate.isAligned == false)
    }

    @Test("rapid oscillation around the entry boundary fires once")
    func oscillationAroundEntryFiresOnce() {
        var gate = QiblaAlignmentGate()
        let deltas = [3.2, 2.8, 3.2, 2.8, 3.2, 2.8]
        let entries = deltas.map { gate.update(signedDelta: $0) }
            .filter { $0 == .entered }
        #expect(entries.count == 1)
        #expect(gate.isAligned)
    }

    @Test("rapid oscillation around the exit boundary exits once")
    func oscillationAroundExitExitsOnce() {
        var gate = QiblaAlignmentGate()
        _ = gate.update(signedDelta: 1)
        let deltas = [5.8, 6.2, 5.8, 6.2, 5.8]
        let exits = deltas.map { gate.update(signedDelta: $0) }
            .filter { $0 == .exited }
        #expect(exits.count == 1)
        #expect(gate.isAligned == false)
    }

    @Test("a full leave-and-return cycle fires .entered again")
    func reentryFiresAgain() {
        var gate = QiblaAlignmentGate()
        var entered = 0
        for delta in [2.0, 8.0, 2.0] where gate.update(signedDelta: delta) == .entered {
            entered += 1
        }
        #expect(entered == 2)
    }

    @Test("wraparound: headings straddling 0° still read as aligned")
    func wraparoundAlignment() {
        // Qibla at 0°: heading 358° is only 2° away — entered; swinging
        // across the seam to 2° stays inside the band with no re-fire.
        var gate = QiblaAlignmentGate()
        #expect(gate.update(signedDelta: QiblaMath.signedDelta(from: 358, to: 0)) == .entered)
        #expect(gate.update(signedDelta: QiblaMath.signedDelta(from: 2, to: 0)) == .unchanged)
        #expect(gate.isAligned)
    }

    @Test("custom thresholds are honored")
    func customThresholds() {
        var gate = QiblaAlignmentGate(enterDegrees: 10, exitDegrees: 20)
        #expect(gate.update(signedDelta: 9) == .entered)
        #expect(gate.update(signedDelta: 15) == .unchanged)
        #expect(gate.isAligned)
        #expect(gate.update(signedDelta: 21) == .exited)
    }
}
