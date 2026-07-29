import CloudKit
import Foundation
import IhsanCore
import os

/// Decides, once per launch, whether the SwiftData store opens with
/// CloudKit mirroring.
///
/// The container must exist synchronously at app init but the account
/// status is only knowable asynchronously — so the gate runs on a
/// one-launch delay: this launch opens the store using the answer
/// cached by the previous one, then refreshes the cache with a single
/// `accountStatus()` query. On `.noAccount` it logs once (on the
/// transition, not per launch) and the next launch runs local-only.
/// The only re-check after that is the system's `CKAccountChanged`
/// notification. No polling, no retry loops.
enum CloudAccountGate {

    static let cacheKey = "ihsan.cloudkit.accountAvailable"

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan", category: "CloudAccountGate"
    )

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: IhsanModelContainerFactory.appGroupIdentifier)
    }

    /// The synchronous launch decision: last known account
    /// availability, optimistically `true` on first run (SwiftData
    /// tolerates a missing account for one launch; the refresh below
    /// corrects the cache for the next).
    static func shouldEnableCloudSync() -> Bool {
        guard let defaults, defaults.object(forKey: cacheKey) != nil else { return true }
        return defaults.bool(forKey: cacheKey)
    }

    /// Pure decision core, unit-tested: what a status report does to
    /// the cache, and whether it deserves a log line. Only definitive
    /// answers act; indeterminate ones change nothing — which is what
    /// makes retry loops structurally impossible here.
    static func decision(
        status: CKAccountStatus,
        previouslyAvailable: Bool
    ) -> (cacheAvailable: Bool, shouldLog: Bool) {
        switch status {
        case .available:
            return (true, false)
        case .noAccount:
            return (false, previouslyAvailable)
        case .couldNotDetermine, .restricted, .temporarilyUnavailable:
            return (previouslyAvailable, false)
        @unknown default:
            return (previouslyAvailable, false)
        }
    }

    /// One status query, one cache write, at most one log line. Called
    /// from the app's launch task and again only when the system posts
    /// `CKAccountChanged`.
    static func refreshAccountStatus() async {
        let status: CKAccountStatus
        do {
            status = try await CKContainer(
                identifier: IhsanModelContainerFactory.cloudKitContainerIdentifier
            ).accountStatus()
        } catch {
            // Indeterminate — keep the cached decision; the account-
            // changed notification is the retry, not us.
            return
        }

        let previous = shouldEnableCloudSync()
        let outcome = decision(status: status, previouslyAvailable: previous)
        defaults?.set(outcome.cacheAvailable, forKey: cacheKey)
        if outcome.shouldLog {
            logger.notice(
                "iCloud account unavailable — running local-only from next launch; will re-check on account change."
            )
        }
    }

    /// Await account-change notifications for the life of the app and
    /// refresh the cache when one arrives. This is the sole re-check
    /// path beyond the single launch query.
    static func observeAccountChanges() async {
        for await _ in NotificationCenter.default.notifications(
            named: .CKAccountChanged
        ) {
            await refreshAccountStatus()
        }
    }
}
