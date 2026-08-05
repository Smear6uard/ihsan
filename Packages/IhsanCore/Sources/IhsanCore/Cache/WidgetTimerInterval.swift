import Foundation

/// Trap-proof intervals for `Text(timerInterval:)`.
///
/// `ClosedRange` traps when its bounds invert, and WidgetKit re-renders
/// archived entries at moments nobody chose — most often the last entry
/// of a timeline whose reload was deferred overnight. An interval built
/// from `.now` to a prayer time that has since passed took the whole
/// render process down with it, and a dead render is a blank widget.
/// Every countdown a widget shows is built here instead: anchored to
/// the entry's own date, clamped so the range can never invert, and
/// therefore incapable of taking the face down with it.
public enum WidgetTimerInterval {
    /// The interval for a countdown that ends at `target`, rendered
    /// inside the entry stamped `entryDate`. When the target has
    /// already passed relative to the entry, the interval collapses to
    /// a zero-length range — the label shows 0:00 — rather than
    /// trapping.
    public static func countdown(from entryDate: Date, to target: Date) -> ClosedRange<Date> {
        entryDate...max(target, entryDate)
    }
}
