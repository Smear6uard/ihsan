import Foundation
import SwiftData

/// One sitting at the tasbīḥ instrument, stored as a quiet fact:
/// the day, the count reached, and the phrase. Recorded, never
/// scored — no row here feeds a goal, a chain, or a completion
/// figure anywhere.
@Model
public final class DhikrSession {
    public var id: UUID = UUID()

    /// The civil day the session belongs to.
    public var sessionDate: Date = Date.distantPast
    public var count: Int = 0
    public var phraseRaw: String = DhikrPhrase.subhanallah.rawValue

    /// The user's own phrase when `phrase == .custom`.
    @Attribute(.allowsCloudEncryption)
    public var customPhrase: String?

    public var startedAt: Date = Date.distantPast
    public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier
    public var sourceSurfaceRaw: String = SourceSurface.app.rawValue

    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    #Index<DhikrSession>([\.sessionDate])

    public init(
        id: UUID = UUID(),
        sessionDate: Date,
        count: Int,
        phrase: DhikrPhrase,
        customPhrase: String? = nil,
        startedAt: Date = .now,
        loggedTimeZoneIdentifier: String = TimeZone.current.identifier,
        sourceSurface: SourceSurface = .app,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.sessionDate = sessionDate
        self.count = count
        self.phraseRaw = phrase.rawValue
        self.customPhrase = customPhrase
        self.startedAt = startedAt
        self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
        self.sourceSurfaceRaw = sourceSurface.rawValue
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public extension DhikrSession {
    var phrase: DhikrPhrase? {
        DhikrPhrase(rawValue: phraseRaw)
    }

    /// The label a surface shows for this session.
    var displayLabel: String {
        if phrase == .custom, let customPhrase, !customPhrase.isEmpty {
            return customPhrase
        }
        return phrase?.displayTransliteration ?? phraseRaw
    }
}
