import SwiftData

public enum IhsanMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [
            IhsanSchemaV1.self,
            IhsanSchemaV2.self
        ]
    }

    public static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: IhsanSchemaV1.self,
                toVersion: IhsanSchemaV2.self
            )
        ]
    }
}
