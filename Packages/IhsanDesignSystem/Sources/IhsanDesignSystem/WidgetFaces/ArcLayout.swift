import CoreGraphics
import Foundation

/// Time-true positions along an arc, with a floor under how close two
/// marks may stand.
///
/// The arc's spacing is information — the crowding of Maghrib against
/// Isha in summer is a true fact about the day — but two ornaments
/// overlapping into one unreadable blot is not information, it is
/// noise. Positions start at their exact time fractions and are then
/// relaxed apart just enough to honour a minimum gap, ends pinned
/// inside the span, so the day keeps its shape and every mark stays a
/// mark.
public enum ArcLayout {
    /// Fraction (0...1) of each time across the span.
    public static func fractions(
        times: [Date], span: ClosedRange<Date>
    ) -> [CGFloat] {
        let total = span.upperBound.timeIntervalSince(span.lowerBound)
        guard total > 0 else { return times.map { _ in 0 } }
        return times.map {
            CGFloat(min(max($0.timeIntervalSince(span.lowerBound) / total, 0), 1))
        }
    }

    /// The same fractions with a minimum gap enforced. `minimumGap` is
    /// in fraction units (the caller divides its point gap by the arc
    /// width). Ascending input order is assumed, as prayer times are.
    public static func separated(
        _ fractions: [CGFloat], minimumGap: CGFloat
    ) -> [CGFloat] {
        guard fractions.count > 1 else { return fractions }
        // A gap so large it cannot fit degrades to even spacing.
        let gap = min(minimumGap, 1 / CGFloat(fractions.count - 1))
        var positions = fractions

        // Forward: nobody stands closer than `gap` to their left
        // neighbour. Backward from the pinned right edge: nobody is
        // pushed past the end, and the compression flows back through
        // the crowd instead of piling on the last mark.
        for index in 1..<positions.count {
            positions[index] = max(positions[index], positions[index - 1] + gap)
        }
        positions[positions.count - 1] = min(positions[positions.count - 1], 1)
        for index in stride(from: positions.count - 2, through: 0, by: -1) {
            positions[index] = min(positions[index], positions[index + 1] - gap)
        }
        positions[0] = max(positions[0], 0)
        for index in 1..<positions.count {
            positions[index] = max(positions[index], positions[index - 1] + gap)
        }
        return positions.map { min(max($0, 0), 1) }
    }
}
