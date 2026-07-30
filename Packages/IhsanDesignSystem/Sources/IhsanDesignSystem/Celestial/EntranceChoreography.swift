import SwiftUI

/// The plate's entrance, as numbers rather than as scattered literals.
///
/// The scene arrives in a fixed order — the arc draws itself left to
/// right, the ornaments bloom in prayer order behind it, and the
/// celestial glow is last — and the order carries meaning: the day's
/// shape appears before the day's marks, and light arrives on a world
/// already drawn. Getting the order wrong would read as five things
/// appearing at once.
///
/// Under Reduce Motion every stagger collapses to one crossfade. That
/// is not a degraded version of the entrance; it is the entrance, for
/// someone who has asked the system not to move things.
public struct EntranceChoreography: Sendable, Equatable {

    /// The whole sequence, start to rest: the last ornament settles at
    /// 0.89 s, a little after the glow finishes at 0.80. Stated exactly
    /// because the scene's own comment used to round it to "~800 ms",
    /// which is the sort of number that quietly becomes wrong.
    public static let totalDuration: Double = 0.90

    /// The single crossfade Reduce Motion collapses everything into.
    public static let reducedDuration: Double = 0.30

    // The arc goes first, from nothing.
    public static let arcDelay: Double = 0
    public static let arcDuration: Double = 0.35

    // Ornaments follow, one per prayer, in the order of the day.
    public static let firstMarkerDelay: Double = 0.18
    public static let markerStagger: Double = 0.09
    public static let markerResponse: Double = 0.35
    public static let markerDamping: Double = 0.85

    // Light last.
    public static let glowDelay: Double = 0.55
    public static let glowDuration: Double = 0.25

    /// When the marker at `index` (0 = Fajr) begins.
    public static func markerDelay(index: Int) -> Double {
        firstMarkerDelay + markerStagger * Double(index)
    }

    /// When the last of `count` markers has come to rest.
    public static func markersSettled(count: Int) -> Double {
        markerDelay(index: max(0, count - 1)) + markerResponse
    }

    // MARK: - Animations

    public static func arc(reduceMotion: Bool) -> Animation {
        reduceMotion ? crossfade : .easeOut(duration: arcDuration)
    }

    public static func marker(index: Int, reduceMotion: Bool) -> Animation {
        reduceMotion
            ? crossfade
            : .spring(response: markerResponse, dampingFraction: markerDamping)
                .delay(markerDelay(index: index))
    }

    public static func glow(reduceMotion: Bool) -> Animation {
        reduceMotion ? crossfade : .easeOut(duration: glowDuration).delay(glowDelay)
    }

    public static let crossfade: Animation = .easeInOut(duration: reducedDuration)
}
