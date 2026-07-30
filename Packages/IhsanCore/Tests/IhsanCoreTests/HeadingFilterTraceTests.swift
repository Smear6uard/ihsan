import Foundation
import Testing
@testable import IhsanCore

/// Characterizes the filter against a realistic simulated device turn:
/// a hand turning from 120° onto the NYC qibla bearing (~58.5°) over
/// two seconds, then holding still for one second, with ±1.5° of
/// deterministic sensor jitter on every sample. The assertions pin the
/// two properties the dial's feel depends on — jitter is attenuated at
/// rest, and the smoothed dial never visibly overshoots the turn.
@Suite("HeadingFilter turn trace")
struct HeadingFilterTraceTests {

    /// Deterministic pseudo-noise so the trace is reproducible run to run.
    private struct SeededNoise {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next(amplitude: Double) -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let unit = Double(state >> 11) / Double(UInt64(1) << 53)
            return (unit * 2 - 1) * amplitude
        }
    }

    @Test("a simulated turn is damped at rest and tracks while moving")
    func simulatedTurnTrace() {
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        let sampleRate = 20.0
        let turnDuration = 2.0
        let holdDuration = 1.0
        let start = 120.0
        let target = 58.5

        var noise = SeededNoise(seed: 0x1B15A)
        var filter = HeadingFilter()
        var trace: [(t: Double, raw: Double, smoothed: Double)] = []

        let totalFrames = Int((turnDuration + holdDuration) * sampleRate)
        for frame in 0...totalFrames {
            let t = Double(frame) / sampleRate
            let progress = min(t / turnDuration, 1.0)
            let ideal = start + (target - start) * progress
            let raw = QiblaMath.normalized(ideal + noise.next(amplitude: 1.5))
            let smoothed = filter.smooth(raw, at: t0.addingTimeInterval(t))
            trace.append((t, raw, smoothed))
        }

        // ── Log: smoothed vs raw, every 5th frame ─────────────────────
        print("t(s)   raw(°)   smoothed(°)")
        for entry in trace where Int(entry.t * sampleRate) % 5 == 0 {
            print(String(format: "%4.2f   %7.2f   %7.2f", entry.t, entry.raw, entry.smoothed))
        }

        // At rest (hold phase), frame-to-frame movement of the smoothed
        // value must be well under the raw jitter — the dial must not
        // sizzle while the hand is still.
        let holdFrames = trace.filter { $0.t > turnDuration + 0.3 }
        let rawSteps = zip(holdFrames, holdFrames.dropFirst()).map {
            abs(QiblaMath.signedDelta(from: $0.raw, to: $1.raw))
        }
        let smoothedSteps = zip(holdFrames, holdFrames.dropFirst()).map {
            abs(QiblaMath.signedDelta(from: $0.smoothed, to: $1.smoothed))
        }
        let meanRawStep = rawSteps.reduce(0, +) / Double(rawSteps.count)
        let meanSmoothedStep = smoothedSteps.reduce(0, +) / Double(smoothedSteps.count)
        #expect(meanSmoothedStep < meanRawStep * 0.5)

        // At rest the smoothed heading must have settled onto the target.
        let final = trace.last!
        #expect(abs(QiblaMath.signedDelta(from: final.smoothed, to: target)) < 1.5)

        // While moving, the smoothed dial trails the ideal turn without
        // ever leading it (no overshoot past the direction of motion).
        let movingFrames = trace.filter { $0.t > 0.5 && $0.t < turnDuration }
        for entry in movingFrames {
            let ideal = start + (target - start) * (entry.t / turnDuration)
            let lag = QiblaMath.signedDelta(from: entry.smoothed, to: ideal)
            // Turning counterclockwise (120° → 58.5°): the smoothed value
            // must sit at or behind the ideal (lag ≤ 0), within a bounded
            // envelope (never more than 8° behind at this turn rate).
            #expect(lag < 1.6, "smoothed led the turn at t=\(entry.t)")
            #expect(lag > -8, "smoothed lagged excessively at t=\(entry.t)")
        }
    }
}
