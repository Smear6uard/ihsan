import WatchKit

/// Thin façade over `WKInterfaceDevice.play(...)` so screens never reference
/// the raw API directly. The semantic names mirror the iOS Haptics enum so
/// shared view models can stay platform-agnostic at the call site.
@MainActor
enum WatchHaptics {
    static func success() {
        WKInterfaceDevice.current().play(.success)
    }

    static func failure() {
        WKInterfaceDevice.current().play(.failure)
    }

    /// Used for the alignment moment on the qibla compass.
    static func notification() {
        WKInterfaceDevice.current().play(.notification)
    }

    static func directionUp() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    static func click() {
        WKInterfaceDevice.current().play(.click)
    }

    static func start() {
        WKInterfaceDevice.current().play(.start)
    }
}
