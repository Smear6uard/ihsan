import Foundation
import Testing
@testable import IhsanCore

@Suite("HeadingFilter")
struct HeadingFilterTests {

    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    @Test("the first sample passes through unfiltered")
    func firstSamplePassesThrough() {
        var filter = HeadingFilter()
        #expect(filter.smooth(123.4, at: t0) == 123.4)
    }

    @Test("a held heading converges to the raw value")
    func convergesToConstantInput() {
        var filter = HeadingFilter()
        _ = filter.smooth(0, at: t0)
        var result = 0.0
        // 2 seconds of samples at 20 Hz, all pointing at 90°.
        for step in 1...40 {
            result = filter.smooth(90, at: t0.addingTimeInterval(Double(step) * 0.05))
        }
        #expect(abs(result - 90) < 0.5)
    }

    @Test("smoothing crosses the 360/0 seam the short way")
    func wraparoundShortWay() {
        var filter = HeadingFilter()
        _ = filter.smooth(359, at: t0)
        let next = filter.smooth(1, at: t0.addingTimeInterval(0.05))
        // Moving from 359° toward 1° must travel clockwise through 0 —
        // a small positive rotation from 359, never the 358° detour.
        let movement = QiblaMath.signedDelta(from: 359, to: next)
        #expect(movement > 0)
        #expect(movement < 2)
    }

    @Test("a longer gap between samples moves the output further")
    func timeCorrectedStep() {
        var quick = HeadingFilter()
        var slow = HeadingFilter()
        _ = quick.smooth(0, at: t0)
        _ = slow.smooth(0, at: t0)
        let afterShortGap = quick.smooth(90, at: t0.addingTimeInterval(0.05))
        let afterLongGap = slow.smooth(90, at: t0.addingTimeInterval(0.5))
        #expect(afterLongGap > afterShortGap)
        #expect(afterLongGap < 90)
    }

    @Test("a stale filter snaps to the raw value after a long pause")
    func staleFilterSnaps() {
        var filter = HeadingFilter()
        _ = filter.smooth(0, at: t0)
        let result = filter.smooth(90, at: t0.addingTimeInterval(5))
        #expect(abs(result - 90) < 1)
    }

    @Test("a non-advancing timestamp leaves the output unchanged")
    func nonAdvancingTimestampIsIgnored() {
        var filter = HeadingFilter()
        _ = filter.smooth(100, at: t0)
        #expect(filter.smooth(120, at: t0) == 100)
        #expect(filter.smooth(120, at: t0.addingTimeInterval(-1)) == 100)
    }

    @Test("output stays within [0, 360)")
    func outputStaysNormalized() {
        var filter = HeadingFilter()
        _ = filter.smooth(359.9, at: t0)
        let result = filter.smooth(0.3, at: t0.addingTimeInterval(0.05))
        #expect(result >= 0)
        #expect(result < 360)
    }

    @Test("reset forgets history so the next sample passes through")
    func resetForgetsHistory() {
        var filter = HeadingFilter()
        _ = filter.smooth(10, at: t0)
        filter.reset()
        #expect(filter.smooth(200, at: t0.addingTimeInterval(0.05)) == 200)
    }
}
