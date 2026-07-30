import Foundation
import Observation
import SwiftData
import IhsanCore
import IhsanIntents
import IhsanLocation
import IhsanPrayerTimes

@MainActor
@Observable
final class TodayViewModel {
    var state: TodayState = .loading

    private let locationProvider: LocationProviding
    private let prayerTimesProvider: PrayerTimesProviding
    private let nowProvider: NowProvider
    private let modelContext: ModelContext
    private var settings: UserSettings?

    @ObservationIgnored
    private nonisolated(unsafe) var significantChangesTask: Task<Void, Never>?

    init(
        locationProvider: LocationProviding = CoreLocationCoordinator.shared,
        prayerTimesProvider: PrayerTimesProviding = AdhanPrayerTimesProvider(),
        nowProvider: NowProvider = .active,
        modelContext: ModelContext
    ) {
        self.locationProvider = locationProvider
        self.prayerTimesProvider = prayerTimesProvider
        self.nowProvider = nowProvider
        self.modelContext = modelContext
    }

    func bootstrap() async {
        do {
            let auth = try await locationProvider.requestWhenInUseAuthorization()
            guard auth.isAuthorized else {
                state = .needsLocationPermission
                return
            }

            settings = try UserSettings.fetchOrCreate(in: modelContext)
            try await refreshSnapshot()

            if settings?.automaticLocationUpdatesEnabled == true {
                try? await locationProvider.startMonitoringSignificantChanges()
                startObservingLocationChanges()
            }
        } catch let error as LocationError {
            state = .error(error.userFacingMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func refreshSnapshot() async throws {
        guard let settings else {
            state = .error("Settings unavailable")
            return
        }

        let place = try await locationProvider.currentPlace()
        let now = nowProvider.now()
        settings.lastResolvedCityName = place.cityName
        settings.lastResolvedCountryCode = place.countryCode
        settings.modifiedAt = now

        let scheduleWindow = try prayerTimesProvider.scheduleWindow(
            for: now,
            coordinates: place.coordinates,
            timeZone: place.timeZone,
            calculationMethod: settings.calculationMethod,
            madhab: settings.madhab,
            highLatitudeRule: settings.highLatitudeRule
        )
        let logs = try fetchTodaysLogs(now: now, timeZone: place.timeZone)
        let statuses = Self.statusMap(from: logs)
        let jamaah = Self.jamaahMap(from: logs)

        state = .ready(.init(
            place: place,
            scheduleWindow: scheduleWindow,
            statuses: statuses,
            jamaah: jamaah
        ))

        // Refresh the App-Group prayer-times cache every time we
        // recompute. Complications read from this rather than spinning
        // up CoreLocation on a tight 30s timeline-provider budget.
        var placeCalendar = Calendar(identifier: .gregorian)
        placeCalendar.timeZone = place.timeZone
        let cache = PrayerTimesCache(
            date: placeCalendar.startOfDay(for: now),
            timeZoneIdentifier: place.timeZone.identifier,
            cityName: place.cityName,
            qiblaBearingDegrees: QiblaEngine(
                latitude: place.coordinates.latitude,
                longitude: place.coordinates.longitude
            ).qiblaBearing,
            entries: scheduleWindow.day.allFardh.map {
                PrayerTimesCache.Entry(
                    prayerRaw: $0.prayer.rawValue,
                    scheduledTime: $0.scheduledTime
                )
            },
            previousDayIsha: scheduleWindow.yesterdayIsha.scheduledTime,
            sunrise: scheduleWindow.day.sunrise,
            nextDayFajr: scheduleWindow.tomorrowFajr.scheduledTime,
            writtenAt: now
        )
        PrayerTimesCacheStore.write(cache)

        // Nudge complications so the corner countdown picks up the
        // new schedule without waiting for its own refresh tick.
        WidgetReloader.reloadAll()
    }

    func setStatus(_ status: PrayerStatus, for prayer: Prayer) async {
        do {
            let intent = LogPrayerWithStatusIntent(prayer: prayer, status: status)
            _ = try await intent.perform()
            WatchHaptics.success()
            try? await refreshSnapshot()
        } catch {
            WatchHaptics.failure()
            print("setStatus failed on watch: \(error)")
        }
    }

    func toggleJamaah(for prayer: Prayer) async {
        do {
            let intent = ToggleJamaahIntent(prayer: prayer)
            _ = try await intent.perform()
            WatchHaptics.directionUp()
            try? await refreshSnapshot()
        } catch {
            WatchHaptics.failure()
            print("toggleJamaah failed on watch: \(error)")
        }
    }

    private func fetchTodaysLogs(now: Date, timeZone: TimeZone) throws -> [PrayerLog] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let descriptor = FetchDescriptor<PrayerLog>(
            predicate: #Predicate {
                $0.prayerDate >= startOfDay && $0.prayerDate < endOfDay
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private static func statusMap(from logs: [PrayerLog]) -> [Prayer: PrayerStatus?] {
        var map: [Prayer: PrayerStatus?] = [:]
        for prayer in Prayer.allCases {
            map[prayer] = nil
        }
        for log in logs {
            guard let prayer = log.prayer, let status = log.status else { continue }
            map[prayer] = status
        }
        return map
    }

    private static func jamaahMap(from logs: [PrayerLog]) -> [Prayer: Bool] {
        var map: [Prayer: Bool] = [:]
        for prayer in Prayer.allCases {
            map[prayer] = false
        }
        for log in logs {
            guard let prayer = log.prayer else { continue }
            map[prayer] = log.withJamaah
        }
        return map
    }

    private func startObservingLocationChanges() {
        significantChangesTask?.cancel()
        let stream = locationProvider.significantLocationChanges()
        significantChangesTask = Task { [weak self] in
            for await _ in stream {
                guard let self else { return }
                try? await self.refreshSnapshot()
            }
        }
    }

    deinit {
        significantChangesTask?.cancel()
    }
}
