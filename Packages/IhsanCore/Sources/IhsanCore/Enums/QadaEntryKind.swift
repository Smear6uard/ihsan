import Foundation

/// The kind of an append-only `QadaEntry` event.
public enum QadaEntryKind: String, Codable, CaseIterable, Sendable {
    /// Setup wrote an initial per-category count (manual or estimated).
    case estimated
    /// The user corrected a count by a signed delta.
    case adjusted
    /// One or more prayers were made up.
    case madeUp
    /// A day's prayer passed unlogged and flowed into the ledger.
    case missedFlowedIn
}
