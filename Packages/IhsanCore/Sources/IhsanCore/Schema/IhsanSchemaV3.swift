import SwiftData

/// Current schema. Adds the voluntary-worship record (`NaflLog`) and
/// defaulted sunnah-layer / night-wake preference fields on `UserSettings`.
/// All changes are additive, so V2 → V3 migrates lightweight.
public enum IhsanSchemaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(3, 0, 0)
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
            NaflLog.self
        ]
    }
}
