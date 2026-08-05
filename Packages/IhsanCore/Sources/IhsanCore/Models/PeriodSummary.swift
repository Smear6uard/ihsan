import Foundation
import SwiftData

public struct ByPrayerStat: Codable, Sendable {
    public var prayer: Prayer
    public var expected: Int
    public var logged: Int
    public var onTime: Int
    public var late: Int
    public var missed: Int
    public var jamaah: Int
    public var avgLateBySeconds: Double?

    public init(
        prayer: Prayer,
        expected: Int = 0,
        logged: Int = 0,
        onTime: Int = 0,
        late: Int = 0,
        missed: Int = 0,
        jamaah: Int = 0,
        avgLateBySeconds: Double? = nil
    ) {
        self.prayer = prayer
        self.expected = expected
        self.logged = logged
        self.onTime = onTime
        self.late = late
        self.missed = missed
        self.jamaah = jamaah
        self.avgLateBySeconds = avgLateBySeconds
    }
}

@Model
public final class PeriodSummary {
    public var id: UUID = UUID()

    public var periodKindRaw: String = PeriodKind.week.rawValue
    public var periodStart: Date = Date.distantPast
    public var periodEnd: Date = Date.distantPast
    public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier
    public var expectedPrayerCount: Int = 0
    public var loggedPrayerCount: Int = 0
    public var onTimeCount: Int = 0
    public var lateCount: Int = 0
    public var missedCount: Int = 0
    public var qadaLoggedCount: Int = 0
    public var jamaahCount: Int = 0
    public var pausedDayCount: Int = 0
    public var traveledDayCount: Int = 0

    @Attribute(.allowsCloudEncryption)
    public var byPrayerJSON: String = "[]"

    public var reflectionCount: Int = 0
    public var dhikrSessionCount: Int = 0
    public var quranTotalMinutes: Double = 0
    public var fastDayCount: Int = 0
    public var masjidVisitCount: Int = 0

    @Attribute(.allowsCloudEncryption)
    public var aiInsightText: String?

    public var aiInsightGeneratedAt: Date?
    public var aiInsightModelVersion: String?
    public var lastRecomputedAt: Date = Date.distantPast
    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    public init(
        id: UUID = UUID(),
        periodKind: PeriodKind,
        periodStart: Date,
        periodEnd: Date,
        loggedTimeZoneIdentifier: String,
        expectedPrayerCount: Int = 0,
        loggedPrayerCount: Int = 0,
        onTimeCount: Int = 0,
        lateCount: Int = 0,
        missedCount: Int = 0,
        qadaLoggedCount: Int = 0,
        jamaahCount: Int = 0,
        pausedDayCount: Int = 0,
        traveledDayCount: Int = 0,
        byPrayer: [ByPrayerStat] = [],
        reflectionCount: Int = 0,
        dhikrSessionCount: Int = 0,
        quranTotalMinutes: Double = 0,
        fastDayCount: Int = 0,
        masjidVisitCount: Int = 0,
        aiInsightText: String? = nil,
        aiInsightGeneratedAt: Date? = nil,
        aiInsightModelVersion: String? = nil,
        lastRecomputedAt: Date = .now,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.periodKindRaw = periodKind.rawValue
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
        self.expectedPrayerCount = expectedPrayerCount
        self.loggedPrayerCount = loggedPrayerCount
        self.onTimeCount = onTimeCount
        self.lateCount = lateCount
        self.missedCount = missedCount
        self.qadaLoggedCount = qadaLoggedCount
        self.jamaahCount = jamaahCount
        self.pausedDayCount = pausedDayCount
        self.traveledDayCount = traveledDayCount
        self.byPrayerJSON = Self.encodeByPrayer(byPrayer)
        self.reflectionCount = reflectionCount
        self.dhikrSessionCount = dhikrSessionCount
        self.quranTotalMinutes = quranTotalMinutes
        self.fastDayCount = fastDayCount
        self.masjidVisitCount = masjidVisitCount
        self.aiInsightText = aiInsightText
        self.aiInsightGeneratedAt = aiInsightGeneratedAt
        self.aiInsightModelVersion = aiInsightModelVersion
        self.lastRecomputedAt = lastRecomputedAt
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    private static func encodeByPrayer(_ byPrayer: [ByPrayerStat]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(byPrayer),
              let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }

        return json
    }
}

public extension PeriodSummary {
    var periodKind: PeriodKind? {
        PeriodKind(rawValue: periodKindRaw)
    }

    var byPrayer: [ByPrayerStat] {
        guard let data = byPrayerJSON.data(using: .utf8),
              let stats = try? JSONDecoder().decode([ByPrayerStat].self, from: data)
        else {
            return []
        }

        return stats
    }
}
