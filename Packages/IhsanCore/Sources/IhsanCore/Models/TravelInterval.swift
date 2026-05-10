import Foundation
import SwiftData

@Model
public final class TravelInterval {
    public var id: UUID = UUID()

    public var startDate: Date = Date.distantPast
    public var endDate: Date?
    public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier

    @Attribute(.allowsCloudEncryption)
    public var fromLocationLabel: String?

    @Attribute(.allowsCloudEncryption)
    public var toLocationLabel: String?

    public var qasrEnabled: Bool = true
    public var jamPolicyRaw: String = JamPolicy.none.rawValue

    @Attribute(.allowsCloudEncryption)
    public var note: String?

    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        loggedTimeZoneIdentifier: String,
        fromLocationLabel: String? = nil,
        toLocationLabel: String? = nil,
        qasrEnabled: Bool = true,
        jamPolicy: JamPolicy = .none,
        note: String? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
        self.fromLocationLabel = fromLocationLabel
        self.toLocationLabel = toLocationLabel
        self.qasrEnabled = qasrEnabled
        self.jamPolicyRaw = jamPolicy.rawValue
        self.note = note
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public extension TravelInterval {
    var isActive: Bool {
        endDate == nil
    }

    var jamPolicy: JamPolicy {
        if let policy = JamPolicy(rawValue: jamPolicyRaw) {
            return policy
        }

        return .none
    }

    func contains(_ date: Date) -> Bool {
        startDate <= date && date <= (endDate ?? .distantFuture)
    }
}
