import Foundation
import IhsanCore

public struct PrayerTime: Sendable, Hashable {
    public let prayer: Prayer
    public let scheduledTime: Date

    public init(prayer: Prayer, scheduledTime: Date) {
        self.prayer = prayer
        self.scheduledTime = scheduledTime
    }
}
