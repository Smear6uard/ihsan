import SwiftData

/// Current schema. Adds `AdhkarSession` — one sitting with a
/// remembrance set, recorded as a quiet fact — and the Adhkar group's
/// preferences on `UserSettings`.
///
/// V6 was frozen into nested snapshots rather than extended: the 1.0.0
/// build shipped at V6, so stores on disk already claim that version,
/// and changing what V6 means would leave them unmigratable ("unknown
/// model version"). Every new field is defaulted and no existing
/// record type changed, so V6 → V7 migrates lightweight.
public enum IhsanSchemaV7: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(7, 0, 0)
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
            DhikrSession.self,
            AdhkarSession.self
        ]
    }
}
