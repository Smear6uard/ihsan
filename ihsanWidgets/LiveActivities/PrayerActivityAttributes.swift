#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation
import IhsanCore

nonisolated public struct PrayerActivityAttributes: ActivityAttributes, Equatable, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var countdownPhase: CountdownPhase
        public var hasBeenLoggedThisActivity: Bool

        public init(
            countdownPhase: CountdownPhase,
            hasBeenLoggedThisActivity: Bool = false
        ) {
            self.countdownPhase = countdownPhase
            self.hasBeenLoggedThisActivity = hasBeenLoggedThisActivity
        }
    }

    public enum CountdownPhase: String, Codable, Hashable, Sendable {
        case preAdhan
        case adhanWindow
        case postAdhan
    }

    public var prayer: Prayer
    public var scheduledTime: Date
    /// Exact resolver boundary captured from the shared day snapshot.
    /// The widget counts down to it; the scheduler updates/ends at it.
    public var windowEnd: Date
    public var timeZoneIdentifier: String
    public var arabicName: String
    public var englishName: String

    public init(
        prayer: Prayer,
        scheduledTime: Date,
        windowEnd: Date,
        timeZoneIdentifier: String,
        arabicName: String,
        englishName: String
    ) {
        self.prayer = prayer
        self.scheduledTime = scheduledTime
        self.windowEnd = windowEnd
        self.timeZoneIdentifier = timeZoneIdentifier
        self.arabicName = arabicName
        self.englishName = englishName
    }
}
#endif
