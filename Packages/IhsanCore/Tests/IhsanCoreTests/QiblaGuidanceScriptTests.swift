import Foundation
import Testing
@testable import IhsanCore

@Suite("QiblaGuidanceScript")
struct QiblaGuidanceScriptTests {

    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    @Test("the first update announces the current direction immediately")
    func firstUpdateAnnounces() {
        var script = QiblaGuidanceScript()
        let line = script.update(signedDelta: 42, isAligned: false, at: t0)
        #expect(line == "42 degrees to your right")
    }

    @Test("small movements inside one band stay silent")
    func smallMovementsAreSilent() {
        var script = QiblaGuidanceScript()
        _ = script.update(signedDelta: 42, isAligned: false, at: t0)
        let line = script.update(
            signedDelta: 38, isAligned: false, at: t0.addingTimeInterval(5)
        )
        #expect(line == nil)
    }

    @Test("crossing a band boundary announces the new direction")
    func bandCrossingAnnounces() {
        var script = QiblaGuidanceScript()
        _ = script.update(signedDelta: 42, isAligned: false, at: t0)
        let line = script.update(
            signedDelta: 22, isAligned: false, at: t0.addingTimeInterval(5)
        )
        #expect(line == "22 degrees to your right")
    }

    @Test("band crossings are rate-limited to avoid chatter")
    func rateLimited() {
        var script = QiblaGuidanceScript()
        _ = script.update(signedDelta: 80, isAligned: false, at: t0)
        // A fast sweep crosses two bands within the quiet period —
        // only the alignment may interrupt; bands must wait.
        let tooSoon = script.update(
            signedDelta: 40, isAligned: false, at: t0.addingTimeInterval(1)
        )
        #expect(tooSoon == nil)
        // After the quiet period the pending band change speaks.
        let later = script.update(
            signedDelta: 38, isAligned: false, at: t0.addingTimeInterval(3)
        )
        #expect(later == "38 degrees to your right")
    }

    @Test("alignment interrupts immediately, regardless of rate limit")
    func alignmentInterrupts() {
        var script = QiblaGuidanceScript()
        _ = script.update(signedDelta: 8, isAligned: false, at: t0)
        let line = script.update(
            signedDelta: 2, isAligned: true, at: t0.addingTimeInterval(0.3)
        )
        #expect(line == "Facing qibla")
    }

    @Test("alignment announces once, then holds silent")
    func alignmentAnnouncesOnce() {
        var script = QiblaGuidanceScript()
        _ = script.update(signedDelta: 2, isAligned: true, at: t0)
        let repeated = script.update(
            signedDelta: 1, isAligned: true, at: t0.addingTimeInterval(4)
        )
        #expect(repeated == nil)
    }

    @Test("losing alignment resumes direction guidance")
    func losingAlignmentResumes() {
        var script = QiblaGuidanceScript()
        _ = script.update(signedDelta: 2, isAligned: true, at: t0)
        let line = script.update(
            signedDelta: 9, isAligned: false, at: t0.addingTimeInterval(4)
        )
        #expect(line == "9 degrees to your left" || line == "9 degrees to your right")
    }

    @Test("side flips announce even within the same band")
    func sideFlipAnnounces() {
        var script = QiblaGuidanceScript()
        _ = script.update(signedDelta: 20, isAligned: false, at: t0)
        let line = script.update(
            signedDelta: -20, isAligned: false, at: t0.addingTimeInterval(5)
        )
        #expect(line == "20 degrees to your left")
    }
}
