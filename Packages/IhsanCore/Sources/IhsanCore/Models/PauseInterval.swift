import Foundation
import SwiftData

@Model
public final class PauseInterval {
    @Attribute(.unique)
    public var id: UUID = UUID()

    public var startDate: Date = Date.distantPast
    public var endDate: Date?
    public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier

    @Attribute(.allowsCloudEncryption)
    public var note: String?

    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        loggedTimeZoneIdentifier: String,
        note: String? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
        self.note = note
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public extension PauseInterval {
    var isActive: Bool {
        endDate == nil
    }

    func contains(_ date: Date) -> Bool {
        startDate <= date && date <= (endDate ?? .distantFuture)
    }
}
