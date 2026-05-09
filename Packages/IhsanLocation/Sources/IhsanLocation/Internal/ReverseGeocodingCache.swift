import Foundation

internal final class ReverseGeocodingCache: @unchecked Sendable {
    struct Key: Hashable {
        let roundedLat: Double
        let roundedLon: Double

        init(latitude: Double, longitude: Double) {
            // Round to ~100m precision for aggressive geocoder caching.
            self.roundedLat = (latitude * 1000).rounded() / 1000
            self.roundedLon = (longitude * 1000).rounded() / 1000
        }
    }

    private struct Entry {
        let value: (city: String?, country: String?)
        let timestamp: Date
    }

    private var cache: [Key: Entry] = [:]
    private let lock = NSLock()
    private let maxEntries: Int
    private let maxAge: TimeInterval
    private let now: @Sendable () -> Date

    init(
        maxEntries: Int = 100,
        maxAge: TimeInterval = 86_400,
        now: @escaping @Sendable () -> Date = { Date.now }
    ) {
        self.maxEntries = maxEntries
        self.maxAge = maxAge
        self.now = now
    }

    func value(for key: Key) -> (city: String?, country: String?)? {
        lock.withLock {
            guard let entry = cache[key] else { return nil }
            if now().timeIntervalSince(entry.timestamp) > maxAge {
                cache[key] = nil
                return nil
            }
            return entry.value
        }
    }

    func store(_ value: (city: String?, country: String?), for key: Key) {
        store(value, for: key, timestamp: now())
    }

    func store(_ value: (city: String?, country: String?), for key: Key, timestamp: Date) {
        lock.withLock {
            if cache.count >= maxEntries {
                if let oldest = cache.min(by: { $0.value.timestamp < $1.value.timestamp }) {
                    cache[oldest.key] = nil
                }
            }
            cache[key] = Entry(value: value, timestamp: timestamp)
        }
    }

    func clear() {
        lock.withLock { cache.removeAll() }
    }
}
