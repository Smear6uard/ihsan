import Foundation

/// How a night's witr stands relative to the makeup ledger's witr category.
public enum WitrNightState: Sendable, Equatable {
    /// The user does not track witr in Repair; the bridge says nothing.
    case notTracked
    /// A witr was recorded for this night — tonight's witr is current.
    case current
    /// Witr is tracked and tonight's has no record yet.
    case open
}

/// The informational bridge between night logging and the witr qada category.
///
/// The ledger is historical: logging tonight's witr never mutates it. This
/// bridge only reads, so surfaces can show "tonight's witr is current"
/// without a single write.
public enum NaflWitrBridge {
    public static func state(
        forNightOf date: Date,
        witrLogs: [NaflLog],
        tracksWitrQada: Bool
    ) -> WitrNightState {
        guard tracksWitrQada else { return .notTracked }

        let nightKey = NaflLog.makeDedupKey(kind: .witr, naflDate: date)
        let hasWitr = witrLogs.contains { log in
            log.kind == .witr && log.dedupKey == nightKey
        }
        return hasWitr ? .current : .open
    }
}
