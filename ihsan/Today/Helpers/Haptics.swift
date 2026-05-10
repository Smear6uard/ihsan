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

    /// Success notification — fires after an Intent's perform() completes.
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
    static func success() {}
    static func warning() {}
}
#endif
