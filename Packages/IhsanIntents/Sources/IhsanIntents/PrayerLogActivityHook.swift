import Foundation
import IhsanCore

/// The Live Activity's ear on the intent funnel.
///
/// `LogPrayerIntent` conforms to `LiveActivityIntent`, so the system
/// performs it in the app's process — but a background intent launch
/// never evaluates the SwiftUI scene, and `RootGate`'s log watcher only
/// runs when the UI does. Without this seam, a tap on "I prayed" on the
/// lock screen writes the log and then leaves the activity standing in
/// its un-logged state until the app next foregrounds.
///
/// The app registers its scheduler at init; every prayer-logging intent
/// notifies after a successful write. Ending an already-ended activity
/// is a lookup miss, so the seam stays idempotent alongside RootGate's
/// own pass.
public actor PrayerLogActivityHook {
    public static let shared = PrayerLogActivityHook()

    private var handler: (@Sendable (Prayer, Date) async -> Void)?

    public func register(_ handler: @escaping @Sendable (Prayer, Date) async -> Void) {
        self.handler = handler
    }

    /// `prayerDate` is the log's cycle date — the same key RootGate
    /// hands `endActivity(for:on:)`.
    public func notify(prayer: Prayer, prayerDate: Date) async {
        await handler?(prayer, prayerDate)
    }
}
