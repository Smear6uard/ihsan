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
    private let modelContext: ModelContext
    private var settings: UserSettings?

    @ObservationIgnored
    private nonisolated(unsafe) var significantChangesTask: Task<Void, Never>?

    init(
        locationProvider: LocationProviding = CoreLocationCoordinator.shared,
        prayerTimesProvider: PrayerTimesProviding = AdhanPrayerTimesProvider(),
        modelContext: ModelContext
    ) {
        self.locationProvider = locationProvider
        self.prayerTimesProvider = prayerTimesProvider
        self.modelContext = modelContext
    }

    /// Called by the screen on appear. Idempotent: safe to call again after
    /// returning to a permission-needed state.
    func bootstrap() async {
        do {
            let auth = try await locationProvider.requestWhenInUseAuthorization()
            guard auth.isAuthorized else {
                state = .needsLocationPermission
                return
            }

            settings = try UserSettings.fetchOrCreate(in: modelContext)
            try await refreshSnapshot()

            try await locationProvider.startMonitoringSignificantChanges()
            startObservingLocationChanges()
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
        let now = Date.now

        let dayTimes = try prayerTimesProvider.dayTimes(
            for: now,
            coordinates: place.coordinates,
            timeZone: place.timeZone,
            calculationMethod: settings.calculationMethod,
            madhab: settings.madhab,
            highLatitudeRule: settings.highLatitudeRule
        )
        let nextPrayer = try prayerTimesProvider.nextPrayer(
            from: now,
            coordinates: place.coordinates,
            timeZone: place.timeZone,
            calculationMethod: settings.calculationMethod,
            madhab: settings.madhab,
            highLatitudeRule: settings.highLatitudeRule
        )
        let activePrayer = try? prayerTimesProvider.currentPrayer(
            at: now,
            coordinates: place.coordinates,
            timeZone: place.timeZone,
            calculationMethod: settings.calculationMethod,
            madhab: settings.madhab,
            highLatitudeRule: settings.highLatitudeRule
        )?.prayer

        state = .ready(.init(
            place: place,
            dayTimes: dayTimes,
            nextPrayerTime: nextPrayer,
            isWithinFajrToSunriseWindow: isWithinFajrToSunriseWindow(now: now, dayTimes: dayTimes),
            activePrayer: activePrayer
        ))
    }

    func setStatus(_ status: PrayerStatus, for prayer: Prayer) async {
        do {
            let intent = LogPrayerWithStatusIntent(prayer: prayer, status: status)
            _ = try await intent.perform()
            Haptics.success()
        } catch {
            print("setStatus failed: \(error)")
        }
    }

    func toggleJamaah(for prayer: Prayer) async {
        do {
            let intent = ToggleJamaahIntent(prayer: prayer)
            _ = try await intent.perform()
            Haptics.soft()
        } catch {
            print("toggleJamaah failed: \(error)")
        }
    }

    private func isWithinFajrToSunriseWindow(now: Date, dayTimes: DayPrayerTimes) -> Bool {
        now >= dayTimes.fajr.scheduledTime && now < dayTimes.sunrise
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
