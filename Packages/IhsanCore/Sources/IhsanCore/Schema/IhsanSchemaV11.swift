import SwiftData

/// Adds numeric Khatam plans and their entry ledger. Existing entities are
/// unchanged, making the V10 → V11 stage a lightweight additive migration.
public enum IhsanSchemaV11: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(11, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        IhsanSchemaV10.models + [KhatamPlan.self, KhatamEntry.self]
    }
}
