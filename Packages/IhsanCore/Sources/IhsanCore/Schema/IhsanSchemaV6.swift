import SwiftData

/// Current schema. Adds `adhanPlaysInSilentMode` on `UserSettings` —
/// the one sound preference that is not expressible inside the existing
/// per-prayer notification JSON, and therefore the only part of the
/// adhan pipeline that needed a column of its own.
///
/// V5 was frozen rather than extended: a build shipped at V5, so a
/// store on disk already claims that version, and changing what V5
/// means would leave those stores unmigratable ("unknown model
/// version"). Every field is defaulted and no record type changed, so
/// V5 → V6 migrates lightweight.
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
}
