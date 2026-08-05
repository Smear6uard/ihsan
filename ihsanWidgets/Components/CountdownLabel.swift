import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// Auto-updating countdowns over `Text(timerInterval:)`, so the
/// visible "1h 23m" ticks without rebuilding the timeline entry.
///
/// Every variant takes a pre-clamped interval — faces build it with
/// `WidgetTimerInterval.countdown(from:to:)` (usually via
/// `entry.nextPrayerCountdown`), never with `.now` and never by hand.
/// An inverted range traps the render process, and a dead render is a
/// blank widget; the clamp makes that impossible by construction.
enum CountdownLabel {
    /// Big thin numerals — the moment of "how long until next".
    struct Hero: View {
        let interval: ClosedRange<Date>
        var scale: CGFloat = 1.0

        var body: some View {
            Text(timerInterval: interval, countsDown: true)
                .font(.system(size: 40 * scale, weight: .thin, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    /// Inline "1h 23m" at body scale — sits on a header line beside
    /// the prayer's name rather than standing alone.
    struct Compact: View {
        let interval: ClosedRange<Date>

        var body: some View {
            Text(timerInterval: interval, countsDown: true)
                .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    /// Tabular "1h 23m" — for the small widget and lock screen.
    struct Tabular: View {
        let interval: ClosedRange<Date>
        var scale: CGFloat = 1.0

        var body: some View {
            Text(timerInterval: interval, countsDown: true)
                .font(.system(size: 28 * scale, weight: .regular, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}
