import Foundation
import Synchronization

/// The process-wide Hijri display preference: the user's moonsighting
/// adjustment, published once from the settings row and read by every
/// surface that formats a Hijri date. Mirrors the `IhsanPageChrome`
/// publication pattern — one source, no per-view settings plumbing,
/// and a zero default for extension processes that never publish.
public enum HijriDisplay {

    private static let published = Mutex<Int>(0)

    /// The current adjustment in days, clamped to the supported ±2.
    public static var offsetDays: Int {
        published.withLock { $0 }
    }

    /// Publish the user's adjustment (on launch and on change).
    public static func publish(offsetDays: Int) {
        let clamped = max(
            HijriConverter.offsetRange.lowerBound,
            min(HijriConverter.offsetRange.upperBound, offsetDays)
        )
        published.withLock { $0 = clamped }
    }
}
