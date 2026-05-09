import SwiftData

public enum IhsanMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [
            IhsanSchemaV1.self
        ]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
