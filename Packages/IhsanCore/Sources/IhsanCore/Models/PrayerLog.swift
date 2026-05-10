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
    public var lateBySeconds: Int?
    public var withJamaah: Bool = false
    public var jamaahLocationRaw: String?
    public var prayerVariantRaw: String = PrayerVariant.full.rawValue
    public var combinedWithPrayerLogID: UUID?
    public var combinationKindRaw: String?
    public var qadaForPrayerLogID: UUID?
    public var sourceSurface: String = SourceSurface.app.rawValue

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

public extension PrayerLog {
    var prayer: Prayer? {
        Prayer(rawValue: prayerRaw)
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
