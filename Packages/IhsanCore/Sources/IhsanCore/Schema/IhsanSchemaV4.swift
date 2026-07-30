import SwiftData

/// Current schema. Adds the wider-worship records — `FastLog` and
/// `DhikrSession` — and defaulted fasting-rhythm / dhikr-overlay
/// preference fields on `UserSettings`. All changes are additive, so
/// V3 → V4 migrates lightweight.
public enum IhsanSchemaV4: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(4, 0, 0)
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
}
