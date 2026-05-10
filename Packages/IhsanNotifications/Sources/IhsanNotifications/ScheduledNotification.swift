import Foundation
import IhsanCore

public struct ScheduledNotification: Equatable, Identifiable, Sendable {
    public let id: String
    public let prayer: Prayer
    public let scheduledDate: Date
    public let title: String
    public let subtitle: String
    public let body: String
    public let soundFileName: String?

    public init(
        id: String,
        prayer: Prayer,
        scheduledDate: Date,
        title: String,
        subtitle: String,
        body: String,
        soundFileName: String?
    ) {
        self.id = id
        self.prayer = prayer
        self.scheduledDate = scheduledDate
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.soundFileName = soundFileName
    }
}
