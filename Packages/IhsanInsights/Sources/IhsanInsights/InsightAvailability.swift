import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public enum InsightAvailability {
    public static var isAvailable: Bool {
        provider.isAvailable()
    }

    private static let provider = AvailabilityProviderStore()

    internal static func setAvailabilityProviderForTesting(_ isAvailable: @escaping @Sendable () -> Bool) {
        provider.set(isAvailable)
    }

    internal static func resetAvailabilityProviderForTesting() {
        provider.reset()
    }
}

private final class AvailabilityProviderStore: @unchecked Sendable {
    private let lock = NSLock()
    private var override: (@Sendable () -> Bool)?

    func isAvailable() -> Bool {
        lock.withLock {
            if let override {
                return override()
            }
            return Self.defaultAvailability()
        }
    }

    func set(_ override: @escaping @Sendable () -> Bool) {
        lock.withLock {
            self.override = override
        }
    }

    func reset() {
        lock.withLock {
            override = nil
        }
    }

    private static func defaultAvailability() -> Bool {
        #if canImport(FoundationModels) && !targetEnvironment(simulator)
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        default:
            return false
        }
        #else
        return false
        #endif
    }
}
