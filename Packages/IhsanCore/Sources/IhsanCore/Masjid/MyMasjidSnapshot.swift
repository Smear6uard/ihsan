import Foundation

/// A `Sendable` copy of the masjid for views, actors, and the notification
/// scheduler.
///
/// `@Model` types are not `Sendable` under Swift 6 and must never cross an
/// isolation boundary; this does.
///
/// The coordinate is deliberately absent. No display surface needs it, and
/// the narrowest snapshot is the one least able to leak.
public struct MyMasjidSnapshot: Sendable, Equatable {
    public let name: String?
    public let streetLabel: String?
    public let entries: [IqamahEntry]
    public let jumuahKhutbahMinutesFromMidnight: Int?
    public let reminderLeadMinutes: Int

    public init(
        name: String?,
        streetLabel: String?,
        entries: [IqamahEntry],
        jumuahKhutbahMinutesFromMidnight: Int?,
        reminderLeadMinutes: Int
    ) {
        self.name = name
        self.streetLabel = streetLabel
        self.entries = entries
        self.jumuahKhutbahMinutesFromMidnight = jumuahKhutbahMinutesFromMidnight
        self.reminderLeadMinutes = reminderLeadMinutes
    }

    public func entry(for prayer: Prayer) -> IqamahEntry {
        entries.first { $0.prayer == prayer } ?? IqamahEntry(prayer: prayer)
    }

    public var hasAnyIqamah: Bool {
        entries.contains(where: \.isSet) || jumuahKhutbahMinutesFromMidnight != nil
    }
}
