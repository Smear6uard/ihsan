import Foundation

#if os(iOS)
import UIKit

@MainActor
enum Haptics {
    enum Impact: CaseIterable, Equatable, Sendable {
        case light
        case medium
        case soft
    }

    enum Notification: CaseIterable, Equatable, Sendable {
        case success
        case warning
    }

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        softImpact.prepare()
        notificationGenerator.prepare()
    }

    static func impact(_ impact: Impact) {
        switch impact {
        case .light:
            lightImpact.impactOccurred()
            lightImpact.prepare()
        case .medium:
            mediumImpact.impactOccurred()
            mediumImpact.prepare()
        case .soft:
            softImpact.impactOccurred()
            softImpact.prepare()
        }
    }

    static func notification(_ notificationType: Notification) {
        switch notificationType {
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        }
        notificationGenerator.prepare()
    }

    /// Light tap — pairs with status-pill activation and low-stakes selectors.
    static func tap() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    /// Soft tap — retained for legacy call sites; new jama'ah interactions use `.light`.
    static func soft() {
        softImpact.impactOccurred()
        softImpact.prepare()
    }

    /// **The settle.** One soft impact, and the only haptic a worship
    /// commit ever makes.
    ///
    /// Every act the app records — a prayer logged from any surface, a
    /// fast, a dhikr boundary, the qibla coming into alignment — is the
    /// same physical event under the thumb: a small weight coming to
    /// rest. Not a click, which reads as a machine acknowledging input,
    /// and not a success notification's rising double-tap, which reads
    /// as praise. Worship is recorded, not applauded.
    ///
    /// Soft rather than light because the commit is the heaviest thing
    /// a person does here, and it should feel like it landed.
    static func settle() {
        softImpact.impactOccurred(intensity: 0.85)
        softImpact.prepare()
    }

    /// Success notification — fires after an Intent's perform()
    /// completes. **Not for worship commits** — those use `settle()`.
    /// Reserved for operations that either succeed or fail and where
    /// the person needs to know which (an export finishing, a
    /// destructive action completing).
    static func success() {
        notification(.success)
    }

    static func warning() {
        notification(.warning)
    }
}
#else
@MainActor
enum Haptics {
    enum Impact: CaseIterable, Equatable, Sendable {
        case light
        case medium
        case soft
    }

    enum Notification: CaseIterable, Equatable, Sendable {
        case success
        case warning
    }

    static func prepareAll() {}
    static func impact(_ impact: Impact) {}
    static func notification(_ notificationType: Notification) {}
    static func tap() {}
    static func soft() {}
    static func settle() {}
    static func success() {}
    static func warning() {}
}
#endif
