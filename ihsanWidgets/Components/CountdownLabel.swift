import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// Auto-updating countdown that uses SwiftUI's built-in
/// `Text(timerInterval:)` so the visible "1h 23m" ticks without
/// rebuilding the timeline entry. The Hero variant is used by the
/// large widget; the Tabular variant is used by the medium and small
/// widgets and the lock screen rectangular widget.
enum CountdownLabel {
    /// Big thin tabular numerals — the moment of "how long until next".
    /// Used in the large widget's hero band.
    struct Hero: View {
        let untilDate: Date
        let scale: CGFloat

        init(until: Date, scale: CGFloat = 1.0) {
            self.untilDate = until
            self.scale = scale
        }

        var body: some View {
            Text(timerInterval: .now...untilDate, countsDown: true)
                .font(.system(size: 40 * scale, weight: .thin, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(IhsanColor.textPrimary)
        }
    }

    /// Tabular "1h 23m" — for the small widget and lock screen.
    struct Tabular: View {
        let untilDate: Date
        let scale: CGFloat

        init(until: Date, scale: CGFloat = 1.0) {
            self.untilDate = until
            self.scale = scale
        }

        var body: some View {
            Text(timerInterval: .now...untilDate, countsDown: true)
                .font(.system(size: 28 * scale, weight: .regular, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(IhsanColor.textPrimary)
        }
    }
}
