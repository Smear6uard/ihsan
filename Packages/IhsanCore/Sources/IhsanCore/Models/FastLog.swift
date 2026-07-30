import Foundation
import SwiftData

/// One day's fast, recorded factually: which day, why (`FastKind`),
/// and whether it is an intention or was kept. One row per civil day
/// across every surface (`dedupKey`), mirroring `PrayerLog`.
///
/// Recorded, never scored: nothing here feeds a chain, a total-as-
/// achievement, or a completion figure anywhere. An unkept intention
/// on a past day is silently inert — no negative state exists in the
/// model to represent one.
@Model
public final class FastLog {
    public var id: UUID = UUID()

    /// One row per civil day: `"fast-2026-07-30"`.
    public var dedupKey: String = ""
    public var kindRaw: String = FastKind.other.rawValue
    public var stateRaw: String = FastState.kept.rawValue

    /// The civil day the fast belongs to.
    public var fastDate: Date = Date.distantPast
    public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier

    public var loggedAt: Date = Date.distantPast
    public var sourceSurfaceRaw: String = SourceSurface.app.rawValue

    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    #Index<FastLog>([\.fastDate])

    public init(
        id: UUID = UUID(),
        kind: FastKind,
        state: FastState,
        fastDate: Date,
        loggedTimeZoneIdentifier: String = TimeZone.current.identifier,
        loggedAt: Date = .now,
        sourceSurface: SourceSurface = .app,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.dedupKey = Self.makeDedupKey(fastDate: fastDate)
        self.kindRaw = kind.rawValue
        self.stateRaw = state.rawValue
        self.fastDate = fastDate
        self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
        self.loggedAt = loggedAt
        self.sourceSurfaceRaw = sourceSurface.rawValue
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    public static func makeDedupKey(fastDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return "fast-\(formatter.string(from: fastDate))"
    }
}

public extension FastLog {
    var kind: FastKind? {
        FastKind(rawValue: kindRaw)
    }

    var state: FastState? {
        FastState(rawValue: stateRaw)
    }

    var sourceSurface: SourceSurface? {
        SourceSurface(rawValue: sourceSurfaceRaw)
    }
}
