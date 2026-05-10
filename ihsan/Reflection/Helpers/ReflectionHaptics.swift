import Foundation

#if os(iOS)
import UIKit

/// Reflection-specific haptics. Distinct file from the Today helper so
/// the two surfaces can evolve independently — the Today screen's tap
/// for prayer logging is a different feel from the recorder's start /
/// stop and the save success.
@MainActor
enum ReflectionHaptics {
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        notification.prepare()
    }

    /// Medium tap — fires when recording starts.
    static func recordStart() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    /// Light tap — fires when recording stops, and on cancel.
    static func recordStop() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    /// Success notification — fires after a reflection saves.
    static func saveSuccess() {
        notification.notificationOccurred(.success)
        notification.prepare()
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
