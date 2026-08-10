import Foundation

/// Whether to raise the one-time Ramadan suggestion that a wake before
/// Fajr can mark the end of suhoor.
///
/// Offered, never assumed. Nothing here enables an anchor: the only path
/// to a ringing alarm is a person tapping to turn one on. And the offer
/// gets exactly one turn — a suggestion that reappears every Ramadan
/// stops being a suggestion and becomes nagging.
public enum SuhoorOffer {

    public static func shouldOffer(
        isRamadan: Bool,
        anchorEnabled: Bool,
        offeredAt: Date?
    ) -> Bool {
        // Already shown. Whatever was decided then stands, including a
        // yes later reversed: that is an answer, not an opening.
        guard offeredAt == nil else { return false }
        // Nothing is gained by offering someone what they already have.
        guard !anchorEnabled else { return false }
        return isRamadan
    }

    /// The line itself. It names what the wake would do and stops there.
    public static let message = "A wake before Fajr can mark the end of suhoor."
    public static let acceptTitle = "Turn on"
    public static let declineTitle = "Not now"
}
