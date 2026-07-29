import Foundation
import SwiftData

/// Frozen snapshot of the schema as it stood when the makeup (qada) layer
/// shipped: V1 plus `QadaLedger`/`QadaEntry`, qada preference fields on
/// `UserSettings`, and `expectedEndDate` on `PauseInterval`. These nested
/// copies must never change — they exist so the migration plan can describe
/// a V2 store exactly. The live model classes are top-level in `Models/` and
/// are listed by the latest `IhsanSchemaV*`.
public enum IhsanSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            PrayerLog.self,
            Reflection.self,
            DayRecord.self,
            PauseInterval.self,
            TravelInterval.self,
            PeriodSummary.self,
            UserSettings.self,
            QadaLedger.self,
            QadaEntry.self
        ]
    }

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
            note: String? = nil
        ) {
            self.id = id
            self.dedupKey = "\(prayer.rawValue)-\(prayerDate.timeIntervalSinceReferenceDate)"
            self.prayerRaw = prayer.rawValue
            self.prayerDate = prayerDate
            self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
            self.scheduledTime = scheduledTime
            self.prayedAt = prayedAt
            self.loggedAt = loggedAt
            self.statusRaw = status.rawValue
            self.lateBySeconds = lateBySeconds
            self.withJamaah = withJamaah
            self.createdAt = .now
            self.modifiedAt = .now
            self.note = note
        }
    }

    @Model
    public final class Reflection {
        public var id: UUID = UUID()

        public var kindRaw: String = ReflectionKind.daily.rawValue
        public var forDate: Date = Date.distantPast
        public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier

        @Attribute(.allowsCloudEncryption)
        public var promptText: String?

        @Attribute(.allowsCloudEncryption)
        public var promptCitation: String?

        @Attribute(.allowsCloudEncryption)
        public var typedText: String?

        @Attribute(.allowsCloudEncryption)
        public var transcript: String?

        public var voiceMemoID: UUID?

        @Attribute(.allowsCloudEncryption)
        public var aiSummaryTitle: String?

        @Attribute(.allowsCloudEncryption)
        public var aiTagsJSON: String?

        public var aiGeneratedAt: Date?
        public var aiModelVersion: String?
        public var linkedPrayerLogID: UUID?
        public var wordCount: Int?
        public var createdAt: Date = Date.distantPast
        public var modifiedAt: Date = Date.distantPast

        public init(
            kind: ReflectionKind,
            forDate: Date,
            loggedTimeZoneIdentifier: String,
            typedText: String? = nil
        ) {
            self.kindRaw = kind.rawValue
            self.forDate = forDate
            self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
            self.typedText = typedText
            self.createdAt = .now
            self.modifiedAt = .now
        }
    }

    @Model
    public final class DayRecord {
        public var id: UUID = UUID()

        public var forDate: Date = Date.distantPast
        public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier

        @Attribute(.allowsCloudEncryption)
        public var musharataNote: String?

        public var calculationMethodSnapshot: String = CalculationMethodChoice.isna.rawValue
        public var madhabSnapshot: String = MadhabChoice.standard.rawValue
        public var highLatitudeRuleSnapshot: String?

        @Attribute(.allowsCloudEncryption)
        public var locationLabel: String?

        public var isPaused: Bool = false
        public var isTraveling: Bool = false
        public var createdAt: Date = Date.distantPast
        public var modifiedAt: Date = Date.distantPast

        public init(
            forDate: Date,
            loggedTimeZoneIdentifier: String,
            isPaused: Bool = false,
            isTraveling: Bool = false
        ) {
            self.forDate = forDate
            self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
            self.isPaused = isPaused
            self.isTraveling = isTraveling
            self.createdAt = .now
            self.modifiedAt = .now
        }
    }

    @Model
    public final class PauseInterval {
        public var id: UUID = UUID()

        public var startDate: Date = Date.distantPast
        public var endDate: Date?
        public var expectedEndDate: Date?
        public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier

        @Attribute(.allowsCloudEncryption)
        public var note: String?

        public var createdAt: Date = Date.distantPast
        public var modifiedAt: Date = Date.distantPast

        public init(
            id: UUID = UUID(),
            startDate: Date,
            endDate: Date? = nil,
            expectedEndDate: Date? = nil,
            loggedTimeZoneIdentifier: String,
            note: String? = nil
        ) {
            self.id = id
            self.startDate = startDate
            self.endDate = endDate
            self.expectedEndDate = expectedEndDate
            self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
            self.note = note
            self.createdAt = .now
            self.modifiedAt = .now
        }
    }

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
            startDate: Date,
            endDate: Date? = nil,
            loggedTimeZoneIdentifier: String,
            toLocationLabel: String? = nil
        ) {
            self.startDate = startDate
            self.endDate = endDate
            self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
            self.toLocationLabel = toLocationLabel
            self.createdAt = .now
            self.modifiedAt = .now
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
            periodKind: PeriodKind,
            periodStart: Date,
            periodEnd: Date,
            loggedTimeZoneIdentifier: String,
            expectedPrayerCount: Int = 0,
            loggedPrayerCount: Int = 0
        ) {
            self.periodKindRaw = periodKind.rawValue
            self.periodStart = periodStart
            self.periodEnd = periodEnd
            self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
            self.expectedPrayerCount = expectedPrayerCount
            self.loggedPrayerCount = loggedPrayerCount
            self.lastRecomputedAt = .now
            self.createdAt = .now
            self.modifiedAt = .now
        }
    }

    @Model
    public final class UserSettings {
        public static let singletonID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        public var id: UUID = IhsanSchemaV2.UserSettings.singletonID

        public var calculationMethodRaw: String = CalculationMethodChoice.isna.rawValue
        public var madhabRaw: String = MadhabChoice.standard.rawValue
        public var highLatitudeRuleRaw: String = HighLatitudeRule.middleOfNight.rawValue
        public var automaticLocationUpdatesEnabled: Bool = true
        @Attribute(.allowsCloudEncryption)
        public var lastResolvedCityName: String?
        public var lastResolvedCountryCode: String?
        public var notificationsEnabled: Bool = true
        public var hasCompletedOnboarding: Bool = false
        public var prayerNotificationsConfigJSON: String = ""
        public var adhanEnabledFajr: Bool = true
        public var adhanEnabledDhuhr: Bool = true
        public var adhanEnabledAsr: Bool = true
        public var adhanEnabledMaghrib: Bool = true
        public var adhanEnabledIsha: Bool = true
        public var themeRaw: String = ThemePreference.dark.rawValue
        public var hijriCalendarOffsetDays: Int = 0
        public var arabicNumeralsEnabled: Bool = false
        public var weekStartsOnSaturday: Bool = true
        public var showStreaksUI: Bool = false
        public var aiInsightsEnabled: Bool = true
        public var autoSyncAudioMemos: Bool = false
        public var qadaTrackingEnabled: Bool = false
        public var qadaTracksWitr: Bool = false
        public var qadaMissedFlowEnabled: Bool = false
        public var qadaPathCardDismissed: Bool = false
        public var qadaDailyIntentionEnabled: Bool = false
        public var qadaSetupCompletedAt: Date?
        public var lastDataExportAt: Date?
        public var lastDataDeletionRequestAt: Date?
        public var schemaVersion: Int = 1
        public var createdAt: Date = Date.distantPast
        public var modifiedAt: Date = Date.distantPast

        public init() {
            self.createdAt = .now
            self.modifiedAt = .now
        }
    }

    @Model
    public final class QadaLedger {
        public var id: UUID = UUID()

        public var categoryRaw: String = QadaCategory.fajr.rawValue
        public var remainingCount: Int = 0
        public var madeUpCount: Int = 0

        public var createdAt: Date = Date.distantPast
        public var modifiedAt: Date = Date.distantPast

        public init(
            id: UUID = UUID(),
            category: QadaCategory,
            remainingCount: Int = 0,
            madeUpCount: Int = 0
        ) {
            self.id = id
            self.categoryRaw = category.rawValue
            self.remainingCount = remainingCount
            self.madeUpCount = madeUpCount
            self.createdAt = .now
            self.modifiedAt = .now
        }
    }

    @Model
    public final class QadaEntry {
        public var id: UUID = UUID()

        public var categoryRaw: String = QadaCategory.fajr.rawValue
        public var kindRaw: String = QadaEntryKind.estimated.rawValue

        public var amount: Int = 0
        public var forDate: Date?

        @Attribute(.allowsCloudEncryption)
        public var reason: String?

        public var sourceSurfaceRaw: String = SourceSurface.app.rawValue

        public var createdAt: Date = Date.distantPast
        public var modifiedAt: Date = Date.distantPast

        #Index<QadaEntry>([\.createdAt])

        public init(
            id: UUID = UUID(),
            category: QadaCategory,
            kind: QadaEntryKind,
            amount: Int,
            forDate: Date? = nil,
            reason: String? = nil
        ) {
            self.id = id
            self.categoryRaw = category.rawValue
            self.kindRaw = kind.rawValue
            self.amount = amount
            self.forDate = forDate
            self.reason = reason
            self.createdAt = .now
            self.modifiedAt = .now
        }
    }
}
