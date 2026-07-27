import Foundation
import Synchronization

/// Collects per-frame draw durations from the celestial render loop.
///
/// Attach one to `CelestialSkyView` (previews and the gallery do) to
/// measure how long each Canvas draw closure takes on the CPU. The
/// budget for the whole plate is ≤4 ms/frame on iPhone 15 Pro-class
/// hardware; the gallery overlays the live numbers so the maintainer
/// can read them during on-device verification.
public final class FrameTimeProbe: Sendable {

    private struct Samples {
        var durations: [Double] = []
    }

    private let storage = Mutex(Samples())

    public init() {}

    /// Record one draw duration in seconds. Keeps a rolling window of
    /// the last 600 frames (~10 s at 60 fps).
    public func record(_ seconds: Double) {
        storage.withLock { samples in
            samples.durations.append(seconds)
            if samples.durations.count > 600 {
                samples.durations.removeFirst(samples.durations.count - 600)
            }
        }
    }

    public var sampleCount: Int {
        storage.withLock { $0.durations.count }
    }

    /// Mean draw time over the rolling window, in milliseconds.
    public var averageMilliseconds: Double {
        storage.withLock { samples in
            guard !samples.durations.isEmpty else { return 0 }
            return samples.durations.reduce(0, +) / Double(samples.durations.count) * 1000
        }
    }

    /// Worst draw time over the rolling window, in milliseconds.
    public var maximumMilliseconds: Double {
        storage.withLock { samples in
            (samples.durations.max() ?? 0) * 1000
        }
    }
}
