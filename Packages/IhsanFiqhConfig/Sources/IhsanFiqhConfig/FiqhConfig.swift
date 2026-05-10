import Foundation

public struct FiqhConfig: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let contentVersion: String
    public let locale: String
    public let prompts: [ReflectionPrompt]
    public let framing: FiqhFraming
    public let thresholds: FiqhThresholds

    public init(
        schemaVersion: Int,
        contentVersion: String,
        locale: String,
        prompts: [ReflectionPrompt],
        framing: FiqhFraming,
        thresholds: FiqhThresholds
    ) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.locale = locale
        self.prompts = prompts
        self.framing = framing
        self.thresholds = thresholds
    }

    public static let supportedSchemaVersion: Int = 1
}
