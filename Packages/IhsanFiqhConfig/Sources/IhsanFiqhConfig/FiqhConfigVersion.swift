import Foundation

public struct FiqhConfigVersion: Sendable, Equatable, Hashable {
    public let schemaVersion: Int
    public let contentVersion: String

    public init(schemaVersion: Int, contentVersion: String) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
    }
}

extension FiqhConfig {
    public var version: FiqhConfigVersion {
        FiqhConfigVersion(schemaVersion: schemaVersion, contentVersion: contentVersion)
    }
}
