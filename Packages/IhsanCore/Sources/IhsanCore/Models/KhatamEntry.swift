import Foundation
import SwiftData

/// One numeric recitation record. `afterPrayerRaw` is context for the
/// person's routine, never a source of religious instruction.
@Model
public final class KhatamEntry {
    public var id: UUID = UUID()
    public var planID: UUID = UUID()
    public var entryDate: Date = Date.distantPast
    public var unitsRead: Int = 0
    public var afterPrayerRaw: String?
    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    #Index<KhatamEntry>([\.planID], [\.entryDate], [\.createdAt])

    public init(
        id: UUID = UUID(),
        planID: UUID,
        entryDate: Date,
        unitsRead: Int,
        afterPrayer: Prayer? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.planID = planID
        self.entryDate = entryDate
        self.unitsRead = max(0, unitsRead)
        self.afterPrayerRaw = afterPrayer?.rawValue
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public extension KhatamEntry {
    var afterPrayer: Prayer? {
        get { afterPrayerRaw.flatMap(Prayer.init(rawValue:)) }
        set { afterPrayerRaw = newValue?.rawValue }
    }
}
