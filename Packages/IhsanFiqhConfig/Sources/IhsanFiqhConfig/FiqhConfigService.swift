import Foundation
import IhsanCore

public actor FiqhConfigService {
    public static let shared = FiqhConfigService()

    public static let remoteConfigURL = URL(
        string: "https://raw.githubusercontent.com/sameerstudios/ihsan-fiqh-config/main/v1/fiqh-config.json"
    )!

    private static let cacheFilename = "fiqh-config-cached.json"

    private var loadedConfig: FiqhConfig?
    private var lastRefreshAttempt: Date?
    private var didStartBackgroundRefresh = false

    public init() {}

    init(initialConfig: FiqhConfig) {
        self.loadedConfig = initialConfig
    }

    public func currentConfig() throws -> FiqhConfig {
        if let loaded = loadedConfig {
            return loaded
        }

        let config = try loadInitialConfig()
        loadedConfig = config

        if !didStartBackgroundRefresh {
            didStartBackgroundRefresh = true
            Task.detached(priority: .background) { [weak self] in
                await self?.refreshFromRemote()
            }
        }

        return config
    }

    public func forceRefresh() async throws -> FiqhConfig {
        let fetched = try await fetchFromRemote()
        try writeCacheConfig(fetched)
        return fetched
    }

    public func loadedConfigSnapshot() -> FiqhConfig? {
        loadedConfig
    }

    // MARK: - Loading priority chain

    private func loadInitialConfig() throws -> FiqhConfig {
        if let cached = try? readCacheConfig() {
            return cached
        }
        return try readBundledConfig()
    }

    private func readBundledConfig() throws -> FiqhConfig {
        guard let url = Bundle.module.url(
            forResource: "default-fiqh-config",
            withExtension: "json"
        ) else {
            throw FiqhConfigError.bundledConfigMissing
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw FiqhConfigError.bundledConfigUnparsable(error.localizedDescription)
        }
        do {
            return try parseConfig(from: data, source: .bundled)
        } catch let error as FiqhConfigError {
            switch error {
            case .remoteConfigUnparsable(let detail), .bundledConfigUnparsable(let detail):
                throw FiqhConfigError.bundledConfigUnparsable(detail)
            default:
                throw error
            }
        }
    }

    private func readCacheConfig() throws -> FiqhConfig {
        let url = try cacheConfigURL()
        let data = try Data(contentsOf: url)
        return try parseConfig(from: data, source: .cache)
    }

    private func writeCacheConfig(_ config: FiqhConfig) throws {
        let url = try cacheConfigURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(config)
        } catch {
            throw FiqhConfigError.cacheWriteFailed(error.localizedDescription)
        }
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            throw FiqhConfigError.cacheWriteFailed(error.localizedDescription)
        }
    }

    private func cacheConfigURL() throws -> URL {
        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return caches.appendingPathComponent(Self.cacheFilename)
    }

    // MARK: - Remote fetch

    private func refreshFromRemote() async {
        lastRefreshAttempt = .now
        do {
            let fetched = try await fetchFromRemote()
            try writeCacheConfig(fetched)
        } catch {
            // Silent failure — bundled or cached config continues to serve.
            // Logged for diagnostics; never surfaced to the user.
            print("[FiqhConfigService] Background refresh failed: \(error)")
        }
    }

    private func fetchFromRemote() async throws -> FiqhConfig {
        var request = URLRequest(url: Self.remoteConfigURL)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FiqhConfigError.remoteFetchFailed(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FiqhConfigError.remoteFetchFailed("Non-HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            throw FiqhConfigError.remoteFetchFailed("HTTP status \(http.statusCode)")
        }

        return try parseConfig(from: data, source: .remote)
    }

    // MARK: - Parsing

    private enum ConfigSource {
        case bundled
        case cache
        case remote
    }

    private func parseConfig(from data: Data, source: ConfigSource) throws -> FiqhConfig {
        let decoder = JSONDecoder()
        let config: FiqhConfig
        do {
            config = try decoder.decode(FiqhConfig.self, from: data)
        } catch {
            switch source {
            case .bundled:
                throw FiqhConfigError.bundledConfigUnparsable(error.localizedDescription)
            case .cache, .remote:
                throw FiqhConfigError.remoteConfigUnparsable(error.localizedDescription)
            }
        }
        guard config.schemaVersion <= FiqhConfig.supportedSchemaVersion else {
            throw FiqhConfigError.schemaVersionUnsupported(
                found: config.schemaVersion,
                supported: FiqhConfig.supportedSchemaVersion
            )
        }
        return config
    }

    // MARK: - Prompt selection

    public func prompt(
        for date: Date,
        timeOfDay: PromptTimeOfDay? = nil,
        hijriCalendar: Calendar = RamadanContext.currentHijriCalendar
    ) throws -> ReflectionPrompt {
        let config = try currentConfig()
        let isRamadan = RamadanContext.isCurrentlyRamadan(
            at: date,
            calendar: hijriCalendar
        )
        let activePrompts = config.prompts.filter { prompt in
            prompt.isActive && (isRamadan || !prompt.ramadanOnly)
        }

        let candidates: [ReflectionPrompt]
        if let requested = timeOfDay {
            let timeMatched = activePrompts.filter { prompt in
                guard let promptTime = prompt.timeOfDay else { return true }
                return promptTime == requested
            }
            candidates = timeMatched.isEmpty ? activePrompts : timeMatched
        } else {
            candidates = activePrompts
        }

        guard !candidates.isEmpty else {
            throw FiqhConfigError.bundledConfigUnparsable("No active prompts")
        }

        let seed = Self.seed(for: date, timeOfDay: timeOfDay)
        let totalWeight = candidates.reduce(0.0) { $0 + max(0, $1.weight) }
        guard totalWeight > 0 else {
            return candidates[Int(seed % UInt64(candidates.count))]
        }

        var rand = SeededRandom(seed: seed)
        let pick = rand.nextDouble() * totalWeight
        var cumulative = 0.0
        for prompt in candidates {
            cumulative += max(0, prompt.weight)
            if pick <= cumulative {
                return prompt
            }
        }
        return candidates[candidates.count - 1]
    }

    private static func seed(for date: Date, timeOfDay: PromptTimeOfDay?) -> UInt64 {
        // Bucket by the user's local calendar day so the prompt stays stable
        // within a single day in their timezone, not in UTC.
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = UInt64(comps.year ?? 2026)
        let m = UInt64(comps.month ?? 1)
        let d = UInt64(comps.day ?? 1)
        let timeBucket: UInt64
        switch timeOfDay {
        case .none: timeBucket = 0
        case .morning: timeBucket = 1
        case .midday: timeBucket = 2
        case .afternoon: timeBucket = 3
        case .evening: timeBucket = 4
        case .night: timeBucket = 5
        case .lastThird: timeBucket = 6
        }
        return y &* 1_000_000 &+ m &* 10_000 &+ d &* 10 &+ timeBucket
    }
}

private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEAD_BEEF_CAFE_BABE : seed
    }

    mutating func nextDouble() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000.0
    }
}
