import SwiftData

/// Current schema. Adds one entity, `MyMasjid`, holding the iqamah times a
/// person entered by hand.
///
/// V8 was frozen into nested snapshots rather than extended, for the same
/// reason V5 through V7 were: stores on disk already claim that version. A
/// new entity with no change to any existing record type migrates
/// lightweight.
public enum IhsanSchemaV9: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(9, 0, 0)
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
            AdhkarSession.self,
            MyMasjid.self
        ]
    }
}
