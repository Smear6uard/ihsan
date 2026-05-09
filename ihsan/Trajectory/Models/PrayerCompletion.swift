import Foundation
import IhsanCore

/// One prayer's outcome for a single day. `status == nil` means no log was
/// captured — the day is past, but the user did not record this prayer.
/// We render that the same as a missed prayer in the heatmap, but keep the
/// distinction in the model so the day popover can show "—" instead of a
/// "Missed" pill.
struct PrayerCompletion: Hashable, Sendable {
    let prayer: Prayer
    let status: PrayerStatus?
    let withJamaah: Bool
}
