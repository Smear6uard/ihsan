import Foundation
import SwiftData

/// One sitting with a remembrance set, stored as a quiet fact: the day,
/// which set, and how many of its items were counted through.
///
/// What is deliberately NOT here: the size of the set. Storing it would
/// invite a percentage, and a percentage across days is a score. Nobody
/// is going to be told they completed 60% of their mornings. The row
/// says a person sat with the morning adhkar and counted eleven items,
/// and that is the whole of it.
///
/// Nothing reads these yet. They exist so that if a quiet overlay is
/// ever wanted, the facts are already there rather than being
/// reconstructed from nothing.
@Model
public final class AdhkarSession {
    public var id: UUID = UUID()

    /// The civil day the sitting belongs to.
    public var sessionDate: Date = Date.distantPast

    /// `AdhkarCategory.rawValue`.
    public var categoryRaw: String = AdhkarCategory.morning.rawValue

    /// How many items of the set were counted to their transmitted
    /// number.
    public var completedItemCount: Int = 0

    public var startedAt: Date = Date.distantPast
    public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier
    public var sourceSurfaceRaw: String = SourceSurface.app.rawValue

    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    #Index<AdhkarSession>([\.sessionDate])

    public init(
        id: UUID = UUID(),
        sessionDate: Date,
        category: AdhkarCategory,
        completedItemCount: Int,
        startedAt: Date = .now,
        loggedTimeZoneIdentifier: String = TimeZone.current.identifier,
        sourceSurface: SourceSurface = .app,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.sessionDate = sessionDate
        self.categoryRaw = category.rawValue
        self.completedItemCount = completedItemCount
        self.startedAt = startedAt
        self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
        self.sourceSurfaceRaw = sourceSurface.rawValue
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public extension AdhkarSession {
    var category: AdhkarCategory? {
        AdhkarCategory(rawValue: categoryRaw)
    }
}
