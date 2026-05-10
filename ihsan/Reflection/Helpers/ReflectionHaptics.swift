import Foundation

#if os(iOS)
import UIKit

/// Reflection-specific haptics. Distinct file from the Today helper so
/// the two surfaces can evolve independently — the Today screen's tap
/// for prayer logging is a different feel from the recorder's start /
/// stop and the save success.
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

    /// Success notification — fires after a reflection saves.
    static func saveSuccess() {
        Haptics.notification(.success)
    }
}
#else
@MainActor
enum ReflectionHaptics {
    static func prepareAll() {}
    static func recordStart() {}
    static func recordStop() {}
    static func saveSuccess() {}
}
#endif
