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

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(IhsanSchemaV3.models)
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
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: IhsanMigrationPlan.self,
            configurations: configuration
        )
    }
}
