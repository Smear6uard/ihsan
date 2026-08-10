import SwiftData

/// Current schema. Adds the four wake anchors to `UserSettings`, plus the
/// stamp for the one-time Ramadan suhoor suggestion.
///
/// Like every current schema, this lists the LIVE model classes from
/// `Models/` — it must, because this is the schema the app's container is
/// built from. Only historical versions hold nested snapshot copies. A
/// current schema that listed its own nested types would hand the whole
/// app frozen classes and fail to cast the moment anything fetched a live
/// one.
///
/// The V9 → V10 stage is CUSTOM, and has to be: a lightweight stage would
/// let this model's all-off default land on someone who had configured the
/// gentle wake and silently retire it. The stage copies their stored
/// `nightWakeEnabled` and `nightWakeOffsetMinutes` into the `.lastThird`
/// anchor explicitly. The two old columns stay as documented vestigial
/// fields.
///
/// V9 was frozen into nested snapshots rather than extended, for the same
/// reason V5 through V8 were: stores on disk already claim that version.
public enum IhsanSchemaV10: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(10, 0, 0)
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
