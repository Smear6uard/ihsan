import Foundation

public enum FiqhConfigError: Error, Sendable, Equatable {
    case bundledConfigMissing
    case bundledConfigUnparsable(String)
    case remoteFetchFailed(String)
    case remoteConfigUnparsable(String)
    case schemaVersionUnsupported(found: Int, supported: Int)
    case cacheWriteFailed(String)
}

extension FiqhConfigError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .bundledConfigMissing:
            "The bundled fiqh config could not be located in the package resources."
        case .bundledConfigUnparsable(let detail):
            "The bundled fiqh config could not be parsed: \(detail)"
        case .remoteFetchFailed(let detail):
            "Remote fiqh config fetch failed: \(detail)"
        case .remoteConfigUnparsable(let detail):
            "Remote fiqh config could not be parsed: \(detail)"
        case .schemaVersionUnsupported(let found, let supported):
            "Fiqh config schema version \(found) is newer than supported version \(supported)."
        case .cacheWriteFailed(let detail):
            "Writing fiqh config cache failed: \(detail)"
        }
    }
}
