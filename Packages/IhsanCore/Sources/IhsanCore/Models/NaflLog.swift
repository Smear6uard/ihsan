import Foundation
import SwiftData

/// One recorded act of voluntary worship. Nafl is recorded, never scored:
/// no row here feeds a count, a goal, or a completion figure anywhere.
///
/// `naflDate` is the civil day the act belongs to. Night kinds (qiyam, witr)
/// logged after midnight belong to the *night of* the previous day — callers
/// pass that day, mirroring how the night itself runs Maghrib → Fajr.
@Model
public final class NaflLog {
    public var id: UUID = UUID()

    /// One row per kind per day across every surface, mirroring
    /// `PrayerLog.dedupKey` so intents stay idempotent.
    public var dedupKey: String = ""
    public var kindRaw: String = NaflKind.duha.storageKey

    public var naflDate: Date = Date.distantPast
    public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier

    /// Recorded only when the user opted into counts; absent otherwise.
    public var rakahCount: Int?

    public var loggedAt: Date = Date.distantPast
    public var sourceSurfaceRaw: String = SourceSurface.app.rawValue

    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    #Index<NaflLog>([\.naflDate])

    public init(
        id: UUID = UUID(),
        kind: NaflKind,
        naflDate: Date,
        loggedTimeZoneIdentifier: String = TimeZone.current.identifier,
        rakahCount: Int? = nil,
        loggedAt: Date = .now,
        sourceSurface: SourceSurface = .app,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.dedupKey = Self.makeDedupKey(kind: kind, naflDate: naflDate)
        self.kindRaw = kind.storageKey
        self.naflDate = naflDate
        self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
        self.rakahCount = rakahCount
        self.loggedAt = loggedAt
        self.sourceSurfaceRaw = sourceSurface.rawValue
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    public static func makeDedupKey(kind: NaflKind, naflDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(kind.storageKey)-\(formatter.string(from: naflDate))"
    }
}

public extension NaflLog {
    var kind: NaflKind? {
        NaflKind(storageKey: kindRaw)
    }

    var sourceSurface: SourceSurface? {
        SourceSurface(rawValue: sourceSurfaceRaw)
    }
}
