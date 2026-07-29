import Foundation

/// The Today surface's single clock.
///
/// Every time-dependent read on the Today screen — header, focused
/// card, countdown, sun and moon positions, marker states, plate
/// phase — resolves the moment through one injected `NowProvider`
/// rather than touching `Date()` directly. `.system` is a transparent
/// passthrough; an override anchors "now" at a chosen instant and then
/// flows forward at real rate, so countdowns still tick and window
/// boundaries still fire while the whole scene renders a different
/// time of day.
///
/// `now()` here is the one sanctioned `Date()` call site for that
/// surface. UI code driven by `TimelineView` should map the timeline's
/// tick through `resolve(_:)` instead, so a single tick date fans out
/// consistently to every consumer in that frame.
public struct NowProvider: Sendable, Equatable {

    /// The instant the override anchors to, and the real instant the
    /// anchor was established. `nil` means the real clock.
    private let anchor: (overrideStart: Date, systemStart: Date)?

    /// The real clock — `resolve` is the identity.
    public static let system = NowProvider(anchor: nil)

    /// The process's one clock, resolved from launch arguments exactly
    /// once. The app injects this same instance into the SwiftUI
    /// environment, and the intent layer stamps `loggedAt` from it —
    /// so a debug now-override moves EVERY clock together, and a
    /// logged timestamp can never run ahead of the time the rest of
    /// the surface displays. Extension processes (widgets, Siri) see
    /// no override argument and get the real clock.
    public static let active = NowProvider.fromLaunchArguments()

    private init(anchor: (overrideStart: Date, systemStart: Date)?) {
        self.anchor = anchor
    }

    /// A flowing override: at `systemStart` the provider reads
    /// `overrideStart`, and advances at 1× from there.
    public init(overrideStart: Date, systemStart: Date) {
        self.init(anchor: (overrideStart, systemStart))
    }

    /// The current moment through this provider's lens.
    public func now() -> Date {
        resolve(Date())
    }

    /// Map a real instant (typically a `TimelineView` tick date) into
    /// this provider's timeline.
    public func resolve(_ systemDate: Date) -> Date {
        guard let anchor else { return systemDate }
        return anchor.overrideStart.addingTimeInterval(
            systemDate.timeIntervalSince(anchor.systemStart)
        )
    }

    public static func == (lhs: NowProvider, rhs: NowProvider) -> Bool {
        lhs.anchor?.overrideStart == rhs.anchor?.overrideStart
            && lhs.anchor?.systemStart == rhs.anchor?.systemStart
    }

    // MARK: - Debug launch argument

    /// The debug override argument: `-IhsanNowOverride <ISO8601>`.
    public static let overrideArgumentName = "-IhsanNowOverride"

    /// Build a provider from process launch arguments. Debug builds
    /// honor `-IhsanNowOverride 2026-07-29T10:30:00Z` (anchored at
    /// `systemStart`, flowing forward); release builds and malformed
    /// arguments always yield `.system`.
    public static func fromLaunchArguments(
        _ arguments: [String] = ProcessInfo.processInfo.arguments,
        systemStart: Date = Date()
    ) -> NowProvider {
        #if DEBUG
        guard
            let flagIndex = arguments.firstIndex(of: overrideArgumentName),
            arguments.indices.contains(flagIndex + 1),
            let overrideStart = ISO8601DateFormatter().date(from: arguments[flagIndex + 1])
        else {
            return .system
        }
        return NowProvider(overrideStart: overrideStart, systemStart: systemStart)
        #else
        return .system
        #endif
    }
}
