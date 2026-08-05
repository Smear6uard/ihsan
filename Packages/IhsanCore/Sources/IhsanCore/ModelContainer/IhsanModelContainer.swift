import Foundation
import SwiftData

public enum IhsanModelContainerError: Error, Sendable {
    case appGroupContainerUnavailable
}

public enum IhsanModelContainerFactory {
    public static let appGroupIdentifier = "group.com.sameerstudios.ihsan"
    public static let cloudKitContainerIdentifier = "iCloud.com.sameerstudios.ihsan"
    public static let storeFileName = "Ihsan.sqlite"

    public static var storeURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(storeFileName)
    }

    /// - Parameter cloudSync: When `false` the store opens without
    ///   CloudKit mirroring — the local-only mode used when the device
    ///   has no iCloud account, so SwiftData never spins on a sync it
    ///   can't perform. The same on-disk store is used either way;
    ///   sync resumes on a later launch once an account exists.
    public static func makeContainer(
        inMemory: Bool = false,
        cloudSync: Bool = true
    ) throws -> ModelContainer {
        let schema = Schema(IhsanSchemaV8.models)
        let configuration: ModelConfiguration

        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else {
            guard let storeURL else {
                throw IhsanModelContainerError.appGroupContainerUnavailable
            }

            configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: cloudSync
                    ? .private(cloudKitContainerIdentifier)
                    : .none
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: IhsanMigrationPlan.self,
            configurations: configuration
        )
    }
}
