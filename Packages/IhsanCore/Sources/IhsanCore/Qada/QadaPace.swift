import Foundation

/// Pace and forecast for the Repair surface, derived from the entry log's
/// recent made-up rate. Returns nil whenever there is nothing kind to say —
/// a zero pace produces no forecast, never a deadline.
public enum QadaPace {
    /// The window over which recent pace is measured.
    public static let windowDays = 28

    /// Projects when the remaining count reaches zero at the recent rate.
    /// Nil when nothing was made up inside the window or nothing remains.
    public static func forecast(
        entries: [QadaEntry],
        remaining: Int,
        asOf reference: Date
    ) -> Date? {
        guard remaining > 0 else {
            return nil
        }

        let windowStart = reference.addingTimeInterval(
            -Double(windowDays) * 86_400
        )
        let madeUpInWindow = entries
            .filter { $0.kind == .madeUp && $0.createdAt >= windowStart && $0.createdAt <= reference }
            .reduce(0) { $0 + $1.amount }

        guard madeUpInWindow > 0 else {
            return nil
        }

        let perDay = Double(madeUpInWindow) / Double(windowDays)
        let daysOut = (Double(remaining) / perDay).rounded(.up)
        return reference.addingTimeInterval(daysOut * 86_400)
    }
}
