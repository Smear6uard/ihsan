import Foundation
import SwiftData

@Model
public final class PrayerLog {
    public var id: UUID = UUID()

    public var dedupKey: String = ""
    public var prayerRaw: String = Prayer.fajr.rawValue

    public var prayerDate: Date = Date.distantPast

    public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier
    public var scheduledTime: Date = Date.distantPast
    public var prayedAt: Date?
    public var loggedAt: Date = Date.distantPast
    public var statusRaw: String = PrayerStatus.missed.rawValue
    /// How far into the window a `.late` — that is, Delayed — prayer
    /// was offered, in seconds from its scheduled start. The stored
    /// name predates the rename and stays put: renaming it would cost a
    /// migration over every historical row to buy a nicer identifier.
    /// Nil for retroactive logs, whose start time is not recoverable.
    public var lateBySeconds: Int?
    public var withJamaah: Bool = false
    public var jamaahLocationRaw: String?
    public var prayerVariantRaw: String = PrayerVariant.full.rawValue
    public var combinedWithPrayerLogID: UUID?
    public var combinationKindRaw: String?
    public var qadaForPrayerLogID: UUID?
    public var sourceSurface: String = SourceSurface.app.rawValue

    /// `PrayerLogReviewFlag.rawValue` when this row needs the user's
    /// eye, `nil` — the overwhelming majority — when it does not.
    ///
    /// Set by the cycle reattribution when moving a post-midnight
    /// entry to the evening it belongs to would land it on a cycle
    /// that already holds one for that prayer. The app does not pick a
    /// winner and delete the other: it keeps both and says so.
    public var reviewFlagRaw: String?

    @Attribute(.allowsCloudEncryption)
    public var note: String?

    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    #Index<PrayerLog>([\.prayerDate])

    public init(
        id: UUID = UUID(),
        prayer: Prayer,
        prayerDate: Date,
        loggedTimeZoneIdentifier: String,
        scheduledTime: Date,
        prayedAt: Date? = nil,
        loggedAt: Date = .now,
        status: PrayerStatus,
        lateBySeconds: Int? = nil,
        withJamaah: Bool = false,
        jamaahLocation: JamaahLocation? = nil,
        prayerVariant: PrayerVariant = .full,
        combinedWithPrayerLogID: UUID? = nil,
        combinationKind: CombinationKind? = nil,
        qadaForPrayerLogID: UUID? = nil,
        sourceSurface: SourceSurface = .app,
        reviewFlag: PrayerLogReviewFlag? = nil,
        note: String? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.dedupKey = Self.makeDedupKey(prayer: prayer, prayerDate: prayerDate)
        self.prayerRaw = prayer.rawValue
        self.prayerDate = prayerDate
        self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
        self.scheduledTime = scheduledTime
        self.prayedAt = prayedAt
        self.loggedAt = loggedAt
        self.statusRaw = status.rawValue
        self.lateBySeconds = lateBySeconds
        self.withJamaah = withJamaah
        self.jamaahLocationRaw = jamaahLocation?.rawValue
        self.prayerVariantRaw = prayerVariant.rawValue
        self.combinedWithPrayerLogID = combinedWithPrayerLogID
        self.combinationKindRaw = combinationKind?.rawValue
        self.qadaForPrayerLogID = qadaForPrayerLogID
        self.sourceSurface = sourceSurface.rawValue
        self.reviewFlagRaw = reviewFlag?.rawValue
        self.note = note
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    private static func makeDedupKey(prayer: Prayer, prayerDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(prayer.rawValue)-\(formatter.string(from: prayerDate))"
    }
}

/// Why a stored prayer log wants a person's attention. Exactly one
/// reason exists, and it is a question the app declines to answer for
/// someone: which of two entries for one prayer is the real one.
public enum PrayerLogReviewFlag: String, Sendable, CaseIterable {
    /// The cycle reattribution found this entry's rightful cycle
    /// already occupied. Both rows were kept; this is the one that
    /// moved, and Path shows it for the user to settle.
    case cycleDuplicate

    /// The line Path reads out. States the fact and asks nothing.
    public var inscription: String {
        switch self {
        case .cycleDuplicate:
            return "Two entries for this prayer"
        }
    }
}

public extension PrayerLog {
    var prayer: Prayer? {
        Prayer(rawValue: prayerRaw)
    }

    var reviewFlag: PrayerLogReviewFlag? {
        reviewFlagRaw.flatMap(PrayerLogReviewFlag.init(rawValue:))
    }

    var status: PrayerStatus? {
        PrayerStatus(rawValue: statusRaw)
    }

    var prayerVariant: PrayerVariant {
        PrayerVariant(rawValue: prayerVariantRaw) ?? .full
    }

    var jamaahLocation: JamaahLocation? {
        jamaahLocationRaw.flatMap(JamaahLocation.init(rawValue:))
    }

    var combinationKind: CombinationKind? {
        combinationKindRaw.flatMap(CombinationKind.init(rawValue:))
    }
}
