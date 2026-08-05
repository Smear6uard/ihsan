import SwiftData

/// Current schema. Adds one field, `PrayerLog.reviewFlagRaw`, so the
/// cycle reattribution can SURFACE a collision instead of resolving
/// one silently.
///
/// The reattribution itself is not here, and cannot be. Moving a
/// post-midnight Isha to the cycle it belongs to needs that day's
/// Fajr; Fajr needs coordinates; coordinates are never persisted
/// (privacy invariant #1). A migration stage runs with the store and
/// nothing else, so any version of this that lived in a stage would be
/// guessing at a schedule. `CycleReattributionSweep` does the work
/// later, once the app has a real one in hand.
///
/// V7 was frozen into nested snapshots rather than extended, for the
/// same reason V5 and V6 were: stores on disk already claim that
/// version. The new field is defaulted and no existing record type
/// changed, so V7 → V8 migrates lightweight.
public enum IhsanSchemaV8: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(8, 0, 0)
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
