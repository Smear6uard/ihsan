import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import IhsanCore
import IhsanLocation

/// Coordinates the five-step first-launch flow.
///
/// The view model keeps draft selections in memory until the final
/// "Begin" tap commits them to `UserSettings`. That single commit is
/// the only persistence side effect of the flow — every interim
/// selection lives here so users who background-quit mid-flow restart
/// from step one with default state.
///
/// State diagram for the persisted `hasCompletedOnboarding` flag:
///   - false on first launch (default in UserSettings)
///   - flipped to true exactly once, in `commit(...)`, on either
///     "Enable notifications" or "Not now"
///   - never flipped back to false by the flow
@Observable
@MainActor
final class OnboardingViewModel {
    // MARK: - Path

    /// Drives the NavigationStack. Each step appends an
    /// `OnboardingStep` value; the welcome step is the root and lives
    /// outside this path.
    var path: [OnboardingStep] = []

    // MARK: - Draft selections

    /// Method shown on the calculation-method step. Initialised to a
    /// locale-derived guess and refined to a country-code-derived
    /// suggestion after a successful location grant.
    var draftMethod: CalculationMethodChoice = CalculationMethodSuggester.suggestedFromLocale()

    var draftMadhab: MadhabChoice = .standard

    /// True when the method picker sheet is presented over the
    /// calculation-method step.
    var showMethodPicker: Bool = false

    // MARK: - Permission status (display-only)

    var locationAuthorization: LocationAuthorization = .notDetermined
    var isRequestingLocation: Bool = false
    var isRequestingNotifications: Bool = false

    // MARK: - Dependencies

    private let locationProvider: LocationProviding
    private let notificationCenter: UNUserNotificationCenter

    init(
        locationProvider: LocationProviding = CoreLocationCoordinator.shared,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.locationProvider = locationProvider
        self.notificationCenter = notificationCenter
    }

    // MARK: - Navigation

    func advance(to step: OnboardingStep) {
        path.append(step)
    }

    /// Idempotent next-step jump from the given current step.
    func goNext(from step: OnboardingStep) {
        let next = step.rawValue + 1
        guard let nextStep = OnboardingStep(rawValue: next) else { return }
        advance(to: nextStep)
    }

    // MARK: - Step 2: Location

    /// Requests when-in-use location authorisation. On success, refines
    /// the method suggestion using the resolved country code.
    /// Always advances past the location step regardless of grant.
    func requestLocationAndContinue() async {
        guard !isRequestingLocation else { return }
        isRequestingLocation = true
        defer { isRequestingLocation = false }

        do {
            let auth = try await locationProvider.requestWhenInUseAuthorization()
            locationAuthorization = auth

            if auth.isAuthorized {
                if let place = try? await locationProvider.currentPlace() {
                    draftMethod = CalculationMethodSuggester.method(
                        forCountryCode: place.countryCode
                    )
                }
            }
        } catch {
            // Permission was restricted or the request failed. The
            // user-facing copy on the location step already explains
            // that this is non-blocking, so we silently continue.
            locationAuthorization = await locationProvider.currentAuthorization()
        }

        goNext(from: .location)
    }

    func skipLocationAndContinue() {
        goNext(from: .location)
    }

    // MARK: - Step 5: Notifications + commit

    /// Requests system notification authorisation, then commits
    /// onboarding regardless of the user's choice.
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

    // MARK: - Commit

    /// The single point where onboarding state is persisted. Writes
    /// only to UserSettings (no other model). The dismissal of the
    /// flow falls out of `hasCompletedOnboarding == true` once SwiftData
    /// publishes the change.
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
            // If the singleton write fails the user is stuck on the
            // last screen, which is the safest outcome — the gate in
            // IhsanApp will keep the flow up until persistence
            // succeeds on a retry.
        }
    }
}
