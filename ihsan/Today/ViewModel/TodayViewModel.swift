import Foundation
import Observation
import SwiftData
import IhsanCore
import IhsanIntents
import IhsanLocation
import IhsanNotifications
import IhsanPrayerTimes

@MainActor
@Observable
final class TodayViewModel {
    var state: TodayState = .loading

    private let locationProvider: LocationProviding
    private let prayerTimesProvider: PrayerTimesProviding
    private let hijriCalendar: Calendar
    private let modelContext: ModelContext
    private var settings: UserSettings?

    @ObservationIgnored
    private nonisolated(unsafe) var significantChangesTask: Task<Void, Never>?

    init(
        locationProvider: LocationProviding = CoreLocationCoordinator.shared,
        prayerTimesProvider: PrayerTimesProviding = AdhanPrayerTimesProvider(),
        hijriCalendar: Calendar = RamadanContext.currentHijriCalendar,
        modelContext: ModelContext
    ) {
        self.locationProvider = locationProvider
        self.prayerTimesProvider = prayerTimesProvider
        self.hijriCalendar = hijriCalendar
        self.modelContext = modelContext
    }

    /// Called by the screen on appear. Idempotent: safe to call again after
    /// returning to a permission-needed state.
    func bootstrap() async {
        do {
            let auth = try await locationProvider.requestWhenInUseAuthorization()
            guard auth.isAuthorized else {
                if auth == .denied || auth == .restricted {
                    Haptics.notification(.warning)
                }
                state = .needsLocationPermission
                return
            }

            settings = try UserSettings.fetchOrCreate(in: modelContext)
            try await refreshSnapshot()

            if settings?.automaticLocationUpdatesEnabled == true {
                try await locationProvider.startMonitoringSignificantChanges()
                startObservingLocationChanges()
            } else {
                await locationProvider.stopMonitoringSignificantChanges()
                significantChangesTask?.cancel()
            }
        } catch let error as LocationError {
            if error == .permissionDenied || error == .permissionRestricted {
                Haptics.notification(.warning)
            }
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
        settings.lastResolvedCityName = place.cityName
        settings.lastResolvedCountryCode = place.countryCode
        settings.modifiedAt = now

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
            activePrayer: activePrayer,
            ramadanContext: RamadanContext(at: now, calendar: hijriCalendar),
            night: relevantNight(now: now, place: place, settings: settings)
        ))
    }

    /// The night the plate should know about: before Fajr that is the
    /// night already in progress (yesterday's Maghrib onward); the rest
    /// of the day it is the night ahead, ready the moment Maghrib passes.
    private func relevantNight(
        now: Date,
        place: LocatedPlace,
        settings: UserSettings
    ) -> NightIntervals? {
        func night(for date: Date) -> NightIntervals? {
            try? prayerTimesProvider.nightIntervals(
                for: date,
                coordinates: place.coordinates,
                timeZone: place.timeZone,
                calculationMethod: settings.calculationMethod,
                madhab: settings.madhab,
                highLatitudeRule: settings.highLatitudeRule
            )
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           let previous = night(for: yesterday),
           previous.contains(now) {
            return previous
        }
        return night(for: now)
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

    /// Records or removes one voluntary act through the single nafl
    /// funnel. The chip's haptic fires before this runs; the @Query
    /// re-render carries the visual truth.
    func toggleNafl(kind: NaflKind, naflDate: Date, rakahCount: Int? = nil) async {
        do {
            let intent = LogNaflIntent(kind: kind, naflDate: naflDate, rakahCount: rakahCount)
            _ = try await intent.perform()
        } catch {
            print("toggleNafl failed: \(error)")
        }
    }

    func toggleJamaah(for prayer: Prayer) async {
        do {
            let intent = ToggleJamaahIntent(prayer: prayer)
            _ = try await intent.perform()
            Haptics.impact(.light)
        } catch {
            print("toggleJamaah failed: \(error)")
        }
    }

    /// Toggles whether the configured adhan recording plays for this
    /// prayer. The notification still fires; it just uses the system
    /// default tone instead. Rebuilds the pending notification window
    /// immediately so the change takes effect for the next prayer.
    func toggleAdhanEnabled(for prayer: Prayer) async {
        guard let settings else { return }
        let current = settings.adhanEnabled(for: prayer)
        settings.setAdhanEnabled(!current, for: prayer)
        settings.modifiedAt = .now
        Haptics.impact(.light)
        do {
            try await NotificationScheduler.shared.rebuildSchedule()
        } catch {
            // Best-effort — the next nightly background refresh will
            // pick up the change even if this immediate rebuild fails.
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
