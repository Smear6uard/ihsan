import Foundation

#if os(iOS)
import UIKit

@MainActor
enum Haptics {
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepareAll() {
        lightImpact.prepare()
        softImpact.prepare()
        notification.prepare()
    }

    /// Light tap — pairs with status-pill activation.
    static func tap() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    /// Soft tap — pairs with the jama'ah toggle.
    static func soft() {
        softImpact.impactOccurred()
        softImpact.prepare()
    }

    /// Success notification — fires after an Intent's perform() completes.
    static func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }
}
#else
@MainActor
enum Haptics {
    static func prepareAll() {}
    static func tap() {}
    static func soft() {}
    static func success() {}
}
#endif
