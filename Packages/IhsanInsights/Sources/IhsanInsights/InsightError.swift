import Foundation

public enum InsightError: Error, Equatable, LocalizedError, Sendable {
    case modelUnavailable
    case contextWindowExceeded(estimatedTokens: Int, maximumTokens: Int)
    case contentRejected
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            "Foundation Models is not available on this device."
        case let .contextWindowExceeded(estimatedTokens, maximumTokens):
            "Insight prompt estimated \(estimatedTokens) tokens, exceeding the \(maximumTokens)-token limit."
        case .contentRejected:
            "Generated insight contained prohibited religious or directive content."
        case let .generationFailed(message):
            "Insight generation failed: \(message)"
        }
    }
}
