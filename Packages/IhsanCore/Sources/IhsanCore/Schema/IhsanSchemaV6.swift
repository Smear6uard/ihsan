import Foundation
import SwiftData

/// Frozen snapshot of the schema as it stood when the ship pass went
/// out: V5 plus `adhanPlaysInSilentMode` on `UserSettings`. These
/// nested copies must never change — they describe a V6 store exactly,
/// including the stores the 1.0.0 build already created.
///
/// V6 was frozen rather than extended for the same reason V5 was: a
/// store on disk already claims this version, and changing what it
/// means leaves those stores unmigratable ("unknown model version").
/// The live model classes are top-level in `Models/` and are listed by
/// the latest `IhsanSchemaV*`.
public enum IhsanSchemaV6: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(6, 0, 0)
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
            QadaEntry.self,
            NaflLog.self,
            FastLog.self,
            DhikrSession.self
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

        public init() {}
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

        public init() {}
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

        public init() {}
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

        public init() {}
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

        public init() {}
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

        public init() {}
    }

    @Model
    public final class UserSettings {
        public var id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        public var calculationMethodRaw: String = CalculationMethodChoice.isna.rawValue
        public var madhabRaw: String = MadhabChoice.standard.rawValue
        public var highLatitudeRuleRaw: String = HighLatitudeRule.middleOfNight.rawValue
        public var customFajrAngle: Double?
        public var customIshaAngle: Double?
        public var customIshaIntervalMinutes: Int?
        public var prayerOffsetFajrMinutes: Int = 0
        public var prayerOffsetDhuhrMinutes: Int = 0
        public var prayerOffsetAsrMinutes: Int = 0
        public var prayerOffsetMaghribMinutes: Int = 0
        public var prayerOffsetIshaMinutes: Int = 0
        public var automaticLocationUpdatesEnabled: Bool = true
        @Attribute(.allowsCloudEncryption)
        public var lastResolvedCityName: String?
        public var lastResolvedCountryCode: String?
        public var notificationsEnabled: Bool = true
        public var hasCompletedOnboarding: Bool = false
        public var prayerNotificationsConfigJSON: String = IhsanCore.UserSettings.defaultPrayerNotificationsConfigJSON
        public var adhanEnabledFajr: Bool = true
        public var adhanEnabledDhuhr: Bool = true
        public var adhanEnabledAsr: Bool = true
        public var adhanEnabledMaghrib: Bool = true
        public var adhanEnabledIsha: Bool = true
        public var adhanPlaysInSilentMode: Bool = false
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
        public var sunnahLayerEnabled: Bool = false
        public var sunnahRawatibEnabled: Bool = false
        public var sunnahDuhaEnabled: Bool = false
        public var sunnahNightEnabled: Bool = false
        public var sunnahRakahCountsEnabled: Bool = false
        public var rawatibConfigJSON: String = IhsanCore.UserSettings.defaultRawatibConfigJSON
        public var duhaSunriseOffsetMinutes: Int = 20
        public var duhaDhuhrMarginMinutes: Int = 15
        public var pathNaflOverlayEnabled: Bool = false
        public var fastingMonThuOfferEnabled: Bool = false
        public var fastingWhiteDaysOfferEnabled: Bool = false
        public var pathDhikrOverlayEnabled: Bool = false
        public var nightWakeEnabled: Bool = false
        public var nightWakeOffsetMinutes: Int = 0
        public var lastDataExportAt: Date?
        public var lastDataDeletionRequestAt: Date?
        public var schemaVersion: Int = 1
        public var createdAt: Date = Date.distantPast
        public var modifiedAt: Date = Date.distantPast

        public init() {}
    }

    @Model
    public final class QadaLedger {
        public var id: UUID = UUID()

        public var categoryRaw: String = QadaCategory.fajr.rawValue
        public var remainingCount: Int = 0
        public var madeUpCount: Int = 0

        public var createdAt: Date = Date.distantPast
        public var modifiedAt: Date = Date.distantPast

        public init() {}
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

        public init() {}
    }

    @Model
    public final class NaflLog {
        public var id: UUID = UUID()

        public var dedupKey: String = ""
        public var kindRaw: String = NaflKind.duha.storageKey

        public var naflDate: Date = Date.distantPast
        public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier

        public var rakahCount: Int?

        public var loggedAt: Date = Date.distantPast
        public var sourceSurfaceRaw: String = SourceSurface.app.rawValue

        public var createdAt: Date = Date.distantPast
        public var modifiedAt: Date = Date.distantPast

        #Index<NaflLog>([\.naflDate])

        public init() {}
    }

    @Model
    public final class FastLog {
        public var id: UUID = UUID()

        public var dedupKey: String = ""
        public var kindRaw: String = FastKind.other.rawValue
        public var stateRaw: String = FastState.kept.rawValue

        public var fastDate: Date = Date.distantPast
        public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier

        public var loggedAt: Date = Date.distantPast
        public var sourceSurfaceRaw: String = SourceSurface.app.rawValue

        public var createdAt: Date = Date.distantPast
        public var modifiedAt: Date = Date.distantPast

        #Index<FastLog>([\.fastDate])

        public init() {}
    }

    @Model
    public final class DhikrSession {
        public var id: UUID = UUID()

        public var sessionDate: Date = Date.distantPast
        public var count: Int = 0
        public var phraseRaw: String = DhikrPhrase.subhanallah.rawValue

        @Attribute(.allowsCloudEncryption)
        public var customPhrase: String?

        public var startedAt: Date = Date.distantPast
        public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier
        public var sourceSurfaceRaw: String = SourceSurface.app.rawValue

        public var createdAt: Date = Date.distantPast
        public var modifiedAt: Date = Date.distantPast

        #Index<DhikrSession>([\.sessionDate])

        public init() {}
    }
}
