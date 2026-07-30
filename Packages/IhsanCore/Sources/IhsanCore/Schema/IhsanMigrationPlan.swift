import SwiftData

public enum IhsanMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [
            IhsanSchemaV1.self,
            IhsanSchemaV2.self,
            IhsanSchemaV3.self,
            IhsanSchemaV4.self,
            IhsanSchemaV5.self,
            IhsanSchemaV6.self
        ]
    }

    public static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: IhsanSchemaV1.self,
                toVersion: IhsanSchemaV2.self
            ),
            .lightweight(
                fromVersion: IhsanSchemaV2.self,
                toVersion: IhsanSchemaV3.self
            ),
            .lightweight(
                fromVersion: IhsanSchemaV3.self,
                toVersion: IhsanSchemaV4.self
            ),
            .lightweight(
                fromVersion: IhsanSchemaV4.self,
                toVersion: IhsanSchemaV5.self
            ),
            .lightweight(
                fromVersion: IhsanSchemaV5.self,
                toVersion: IhsanSchemaV6.self
            )
        ]
    }
}
