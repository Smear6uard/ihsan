import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import IhsanCore
import IhsanDesignSystem
import IhsanLocation
import IhsanPrayerTimes

/// Coordinates the three-screen first launch.
///
/// Draft selections live here until the final "Begin" commits them to
/// `UserSettings` in one write, so quitting mid-flow leaves nothing
/// half-applied. The only thing that escapes that rule is the system's
/// own record of a permission grant, which is the system's to keep.
@Observable
@MainActor
final class OnboardingViewModel {

    /// A place the plate can draw, before and after the person shares
    /// their own. Coordinates are transient here exactly as everywhere
    /// else — held to compute, never written down.
    struct PlatePlace: Equatable {
        let name: String
        let latitude: Double
        let longitude: Double
        let timeZone: TimeZone
    }

    /// A day, resolved: five instants, the palette's solar events, and
    /// which window is open right now.
    struct PlateSchedule: Equatable {
        let times: [(prayer: Prayer, time: Date)]
        let solarEvents: SolarDayEvents
        let current: Prayer?

        static func == (lhs: PlateSchedule, rhs: PlateSchedule) -> Bool {
            lhs.solarEvents == rhs.solarEvents && lhs.current == rhs.current
        }
    }

    /// Makkah. Somewhere real, with real times, so the first screen is
    /// the app working rather than a mock of it.
    static let defaultPlace = PlatePlace(
        name: "Makkah",
        latitude: 21.4225,
        longitude: 39.8262,
        timeZone: TimeZone(identifier: "Asia/Riyadh") ?? .current
    )

    // MARK: - Path

    var path: [OnboardingStep] = []

    // MARK: - Draft selections

    /// Initialised from the device locale — which iOS exposes with no
    /// permission at all — and refined once a location is shared.
    var draftMethod: CalculationMethodChoice = CalculationMethodSuggester.suggestedFromLocale()
    var draftMadhab: MadhabChoice = .standard

    // MARK: - Permission state (display only)

    var locationAuthorization: LocationAuthorization = .notDetermined
    var isRequestingLocation: Bool = false
    var isRequestingNotifications: Bool = false

    /// The person's own place, once shared.
    private(set) var resolvedPlace: PlatePlace?

    var hasLocation: Bool { resolvedPlace != nil }

    /// Where the plate is drawing: their place if there is one, Makkah
    /// otherwise.
    var plateePlace: PlatePlace { resolvedPlace ?? Self.defaultPlace }

    // MARK: - Dependencies

    private let locationProvider: LocationProviding
    private let notificationCenter: UNUserNotificationCenter
    private let prayerTimesProvider: any PrayerTimesProviding

    init(
        locationProvider: LocationProviding = CoreLocationCoordinator.shared,
        notificationCenter: UNUserNotificationCenter = .current(),
        prayerTimesProvider: any PrayerTimesProviding = AdhanPrayerTimesProvider()
    ) {
        self.locationProvider = locationProvider
        self.notificationCenter = notificationCenter
        self.prayerTimesProvider = prayerTimesProvider
    }

    // MARK: - The plate

    /// The day the first screen draws, computed by the same provider
    /// and the same draft settings the app will use a minute from now.
    /// Changing the method on screen two really does move these times.
    func plateSchedule(at now: Date) -> PlateSchedule? {
        let place = plateePlace
        guard let window = try? prayerTimesProvider.scheduleWindow(
            for: now,
            coordinates: Coordinates(latitude: place.latitude, longitude: place.longitude),
            timeZone: place.timeZone,
            calculationMethod: draftMethod,
            madhab: draftMadhab,
            highLatitudeRule: .middleOfNight
        ) else { return nil }

        let resolution = PrayerStateResolver.resolve(
            prayerTimes: window.resolverSchedule, now: now
        )
        let day = window.day

        return PlateSchedule(
            times: [
                (.fajr, day.fajr.scheduledTime),
                (.dhuhr, day.dhuhr.scheduledTime),
                (.asr, day.asr.scheduledTime),
                (.maghrib, day.maghrib.scheduledTime),
                (.isha, day.isha.scheduledTime)
            ],
            solarEvents: SolarDayEvents(
                fajr: day.fajr.scheduledTime,
                sunrise: day.sunrise,
                solarNoon: day.dhuhr.scheduledTime,
                maghrib: day.maghrib.scheduledTime,
                isha: day.isha.scheduledTime
            ),
            current: resolution.currentPrayer?.prayer
        )
    }

    // MARK: - Navigation

    func advance(to step: OnboardingStep) {
        path.append(step)
    }

    func goNext(from step: OnboardingStep) {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        advance(to: next)
    }

    // MARK: - Location

    /// Asks in place, on the first screen. On a grant the plate redraws
    /// for their sky and the method suggestion follows their region.
    /// A refusal is a complete answer and the flow does not mention it
    /// again.
    func requestLocation() async {
        guard !isRequestingLocation else { return }
        isRequestingLocation = true
        defer { isRequestingLocation = false }

        do {
            let auth = try await locationProvider.requestWhenInUseAuthorization()
            locationAuthorization = auth

            if auth.isAuthorized, let place = try? await locationProvider.currentPlace() {
                resolvedPlace = PlatePlace(
                    name: place.cityName ?? "Your location",
                    latitude: place.coordinates.latitude,
                    longitude: place.coordinates.longitude,
                    timeZone: place.timeZone
                )
                draftMethod = CalculationMethodSuggester.method(forCountryCode: place.countryCode)
            } else {
                goNext(from: .plate)
            }
        } catch {
            locationAuthorization = await locationProvider.currentAuthorization()
            goNext(from: .plate)
        }
    }

    // MARK: - Notifications, then commit

    func enableNotificationsAndFinish(in context: ModelContext) async {
        guard !isRequestingNotifications else { return }
        isRequestingNotifications = true
        defer { isRequestingNotifications = false }

        let granted = (try? await notificationCenter.requestAuthorization(
            options: [.alert, .sound, .badge]
        )) ?? false

        commit(notificationsEnabled: granted, in: context)
    }

    func skipNotificationsAndFinish(in context: ModelContext) {
        commit(notificationsEnabled: false, in: context)
    }

    /// The single point where onboarding state is persisted.
    private func commit(notificationsEnabled: Bool, in context: ModelContext) {
        do {
            let settings = try UserSettings.fetchOrCreate(in: context)
            settings.calculationMethodRaw = draftMethod.rawValue
            settings.madhabRaw = draftMadhab.rawValue
            settings.notificationsEnabled = notificationsEnabled
            settings.hasCompletedOnboarding = true
            settings.modifiedAt = .now
            try context.save()
        } catch {
            // If the write fails the person stays on the last screen,
            // which is the safe outcome: the gate keeps the flow up
            // until persistence succeeds.
        }
    }
}
