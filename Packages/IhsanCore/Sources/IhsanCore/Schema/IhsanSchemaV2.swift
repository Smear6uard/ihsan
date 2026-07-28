import SwiftData

/// Current schema. Adds the makeup-worship ledger (`QadaLedger`, `QadaEntry`)
/// and defaulted fields on `UserSettings` (qada preferences) and
/// `PauseInterval` (`expectedEndDate`). All changes are additive, so V1 → V2
/// migrates lightweight.
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
}
