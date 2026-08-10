import SwiftData

public enum IhsanMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [
            IhsanSchemaV1.self,
            IhsanSchemaV2.self,
            IhsanSchemaV3.self,
            IhsanSchemaV4.self,
            IhsanSchemaV5.self,
            IhsanSchemaV6.self,
            IhsanSchemaV7.self,
            IhsanSchemaV8.self,
            IhsanSchemaV9.self,
            IhsanSchemaV10.self,
            IhsanSchemaV11.self
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
            ),
            .custom(
                fromVersion: IhsanSchemaV6.self,
                toVersion: IhsanSchemaV7.self,
                willMigrate: nil,
                didMigrate: { context in
                    // V7 introduced the adhkar surface as opt-in for
                    // existing installs. Persist those migration defaults
                    // explicitly so the later V8 model's new-install
                    // defaults cannot silently opt an upgrader in.
                    let settings = try context.fetch(
                        FetchDescriptor<IhsanSchemaV7.UserSettings>()
                    )
                    for setting in settings {
                        setting.adhkarLayerEnabled = false
                        setting.adhkarMorningEnabled = false
                        setting.adhkarEveningEnabled = false
                        setting.adhkarPostPrayerEnabled = false
                        setting.adhkarSleepEnabled = false
                    }
                    try context.save()
                }
            ),
            .lightweight(
                fromVersion: IhsanSchemaV7.self,
                toVersion: IhsanSchemaV8.self
            ),
            // V9 adds the `MyMasjid` entity and changes no existing record
            // type, so there is nothing for a custom stage to do.
            .lightweight(
                fromVersion: IhsanSchemaV8.self,
                toVersion: IhsanSchemaV9.self
            ),
            .custom(
                fromVersion: IhsanSchemaV9.self,
                toVersion: IhsanSchemaV10.self,
                willMigrate: nil,
                didMigrate: { context in
                    // The last-third wake keeps the configuration its
                    // owner set. Written EXPLICITLY, for the reason
                    // V6 -> V7 was: a lightweight stage would let the new
                    // model's all-off default land on an upgrader and
                    // silently retire a wake they rely on.
                    //
                    // The other three arrive off. Nobody is opted into an
                    // alarm by an upgrade.
                    // The LIVE `UserSettings`, because V10 is the current
                    // schema and its models are the live classes. Naming a
                    // nested type here would be naming a class this store
                    // is not using.
                    let settings = try context.fetch(FetchDescriptor<UserSettings>())
                    for setting in settings {
                        setting.wakeAnchorsConfigJSON = WakeAnchorConfig.encode([
                            WakeAnchorConfig(
                                anchor: .lastThird,
                                isEnabled: setting.nightWakeEnabled,
                                offsetMinutes: setting.nightWakeOffsetMinutes
                            ),
                            WakeAnchorConfig(anchor: .fajrStart),
                            WakeAnchorConfig(anchor: .sunrise),
                            WakeAnchorConfig(anchor: .maghrib),
                        ])
                    }
                    try context.save()
                }
            ),
            .lightweight(
                fromVersion: IhsanSchemaV10.self,
                toVersion: IhsanSchemaV11.self
            )
        ]
    }
}
