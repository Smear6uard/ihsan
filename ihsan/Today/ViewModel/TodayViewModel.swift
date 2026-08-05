import Foundation
import Observation
import OSLog
import SwiftData
import IhsanCore
import IhsanDesignSystem
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
    private let nowProvider: NowProvider
    private let modelContext: ModelContext
    private var settings: UserSettings?

    @ObservationIgnored
    private nonisolated(unsafe) var significantChangesTask: Task<Void, Never>?

    init(
        locationProvider: LocationProviding = CoreLocationCoordinator.shared,
        prayerTimesProvider: PrayerTimesProviding = AdhanPrayerTimesProvider(),
        hijriCalendar: Calendar = RamadanContext.currentHijriCalendar,
        nowProvider: NowProvider = .system,
        modelContext: ModelContext
    ) {
        self.locationProvider = locationProvider
        self.prayerTimesProvider = prayerTimesProvider
        self.hijriCalendar = hijriCalendar
        self.nowProvider = nowProvider
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
        let now = nowProvider.now()
        settings.lastResolvedCityName = place.cityName
        settings.lastResolvedCountryCode = place.countryCode
        settings.modifiedAt = now

        // One bracketed three-day window; every per-tick question —
        // current prayer, next prayer, window end — is derived from it
        // by the views, so nothing here can go stale between refreshes.
        let scheduleWindow = try prayerTimesProvider.scheduleWindow(
            for: now,
            coordinates: place.coordinates,
            timeZone: place.timeZone,
            calculationMethod: settings.calculationMethod,
            madhab: settings.madhab,
            highLatitudeRule: settings.highLatitudeRule,
            tuning: settings.calculationTuning
        )

        state = .ready(.init(
            place: place,
            scheduleWindow: scheduleWindow,
            ramadanContext: RamadanContext(
                at: now,
                calendar: hijriCalendar,
                offsetDays: settings.hijriCalendarOffsetDays
            ),
            night: relevantNight(now: now, place: place, settings: settings)
        ))

        // Clock 2's boundaries, published before anything formats a
        // Hijri date: the day turns at Maghrib, and every surface reads
        // the turn from here rather than deriving one of its own.
        HijriDisplay.publish(
            eveningBoundaries: scheduleWindow.eveningBoundaries,
            timeZone: place.timeZone
        )

        // The one-shot repair of records filed under the midnight
        // rule. It runs here and nowhere else, because here is the
        // first moment a real schedule exists — and a schedule is the
        // one thing the store itself can never supply, coordinates
        // being transient by contract.
        reattributeCyclesIfNeeded(now: now, place: place, settings: settings)

        // Publish the exact resolver table for widgets/watch
        // complications. Extensions never recalculate with a second
        // timezone or settings path, and coordinates remain transient.
        //
        // Yesterday's five travel with it. Before dawn the cycle in
        // progress is yesterday's, and the surfaces that log without a
        // place — which is most of them — have only this cache to
        // resolve it from.
        var placeCalendar = Calendar(identifier: .gregorian)
        placeCalendar.timeZone = place.timeZone
        func entries(_ day: DayPrayerTimes) -> [PrayerTimesCache.Entry] {
            day.allFardh.map {
                PrayerTimesCache.Entry(
                    prayerRaw: $0.prayer.rawValue,
                    scheduledTime: $0.scheduledTime
                )
            }
        }
        PrayerTimesCacheStore.write(PrayerTimesCache(
            date: placeCalendar.startOfDay(for: scheduleWindow.day.date),
            timeZoneIdentifier: place.timeZone.identifier,
            cityName: place.cityName,
            qiblaBearingDegrees: QiblaEngine(
                latitude: place.coordinates.latitude,
                longitude: place.coordinates.longitude
            ).qiblaBearing,
            entries: entries(scheduleWindow.day),
            previousDayIsha: scheduleWindow.yesterdayIsha.scheduledTime,
            sunrise: scheduleWindow.day.sunrise,
            nextDayFajr: scheduleWindow.tomorrowFajr.scheduledTime,
            previousDayEntries: entries(scheduleWindow.yesterday),
            writtenAt: now
        ))

        // The iOS widget spine: two full days, day facts, and a
        // timeline reload — published beside the legacy one-day cache
        // (above), which the watch complications still read.
        WidgetSnapshotService.publish(
            place: place,
            provider: prayerTimesProvider,
            settings: settings,
            modelContext: modelContext,
            now: now
        )

        // Secondary pages ride the same solar transition as the plate:
        // publish the day's real events so page chrome resolves through
        // them instead of the clock-anchor approximation.
        IhsanPageChrome.publish(SolarDayEvents(
            fajr: scheduleWindow.day.fajr.scheduledTime,
            sunrise: scheduleWindow.day.sunrise,
            solarNoon: scheduleWindow.day.dhuhr.scheduledTime,
            maghrib: scheduleWindow.day.maghrib.scheduledTime,
            isha: scheduleWindow.day.isha.scheduledTime
        ))

        // Snapshot refreshes fire on foreground and on significant
        // location change — exactly the moments the wake must recompute
        // from the (possibly new) night.
        await NightWakeService.shared.refresh(using: modelContext)
    }

    /// Move records filed under the midnight rule onto the cycles they
    /// belong to, once, and say what moved.
    ///
    /// The day tables come from the same provider and the same
    /// settings the rest of this refresh uses, computed lazily per day
    /// that actually holds a record. A day the provider cannot resolve
    /// is left alone and counted in the report rather than guessed at.
    private func reattributeCyclesIfNeeded(
        now: Date,
        place: LocatedPlace,
        settings: UserSettings
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone

        func dayTimes(_ day: Date) -> DayPrayerTimes? {
            try? prayerTimesProvider.dayTimes(
                for: day,
                coordinates: place.coordinates,
                timeZone: place.timeZone,
                calculationMethod: settings.calculationMethod,
                madhab: settings.madhab,
                highLatitudeRule: settings.highLatitudeRule,
                tuning: settings.calculationTuning
            )
        }

        do {
            let report = try CycleReattributionSweep(calendar: calendar).runIfNeeded(
                now: now,
                boundaries: { day in
                    guard
                        let today = dayTimes(day),
                        let next = calendar.date(byAdding: .day, value: 1, to: day),
                        let tomorrow = dayTimes(next)
                    else { return nil }
                    return CycleDayBoundaries(
                        fajr: today.fajr.scheduledTime,
                        isha: today.isha.scheduledTime,
                        nextFajr: tomorrow.fajr.scheduledTime
                    )
                },
                in: modelContext
            )
            if let report {
                Self.logger.notice("\(report.summary, privacy: .public)")
            }
        } catch {
            // A failed sweep leaves the marker unset, so the next
            // launch tries again. Records are never half-moved: the
            // pass saves once, at its end.
            Self.logger.error("Cycle reattribution failed: \(String(describing: error))")
        }
    }

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan",
        category: "CycleReattribution"
    )

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
                highLatitudeRule: settings.highLatitudeRule,
                tuning: settings.calculationTuning
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
            Haptics.settle()
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

    /// Silences this prayer, or gives it its sound back. The
    /// notification still fires either way — only the room changes.
    /// Rebuilds the pending window immediately so the change takes
    /// effect for the next prayer rather than the next day.
    func toggleAdhanEnabled(for prayer: Prayer) async {
        guard let settings else { return }
        settings.setSound(
            settings.sound(for: prayer) == .silent ? .chime : .silent,
            for: prayer
        )
        settings.modifiedAt = nowProvider.now()
        Haptics.impact(.light)
        do {
            try await NotificationScheduler.shared.rebuildSchedule()
        } catch {
            // Best-effort — the next nightly background refresh will
            // pick up the change even if this immediate rebuild fails.
        }
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
