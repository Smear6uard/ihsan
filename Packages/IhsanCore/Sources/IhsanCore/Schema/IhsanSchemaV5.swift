import SwiftData

/// Current schema. Adds the calculation-depth preferences on
/// `UserSettings` — a custom Fajr angle, a custom Isha rule (angle or
/// fixed interval after Maghrib), and per-prayer manual offsets. Every
/// field is optional or defaulted and no record type changed, so
/// V4 → V5 migrates lightweight.
public enum IhsanSchemaV5: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(5, 0, 0)
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
