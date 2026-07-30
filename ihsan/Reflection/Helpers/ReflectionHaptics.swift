import Foundation

#if os(iOS)
import UIKit

/// The recorder's own two haptics, plus the commit.
///
/// Start and stop are transport controls and feel like controls. The
/// save is not: a reflection written or spoken is a worship record,
/// the same kind of thing as a logged prayer, and it wears the same
/// settle. It used to fire a success notification.
@MainActor
enum ReflectionHaptics {
    static func prepareAll() {
        Haptics.prepareAll()
    }

    /// Medium tap — fires when recording starts.
    static func recordStart() {
        Haptics.impact(.medium)
    }

    /// Light tap — fires when recording stops, and on cancel.
    static func recordStop() {
        Haptics.impact(.light)
    }

    /// The settle — a reflection has been recorded.
    static func saved() {
        Haptics.settle()
    }
}
#else
@MainActor
enum ReflectionHaptics {
    static func prepareAll() {}
    static func recordStart() {}
    static func recordStop() {}
    static func saved() {}
}
#endif
