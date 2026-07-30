import IhsanCore
import IhsanDesignSystem
import IhsanLocation
import IhsanPrayerTimes
import SwiftUI

/// The first screen is the app.
///
/// A real plate, drawing a real day, computed by the same provider
/// every other surface uses — for Makkah until there is somewhere
/// better to draw, and for wherever the person is the moment they say
/// so. The location question sits on it in a small panel rather than
/// occupying a screen of its own, because the answer changes what is
/// already on screen and that is the clearest way to ask.
///
/// Declining is a complete answer. Makkah's times are real times; the
/// app works, and Set can change it later.
struct OnboardingPlateStep: View {
    @Bindable var viewModel: OnboardingViewModel

    @Environment(\.nowProvider) private var nowProvider
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var entrance: Double = 0

    var body: some View {
        let now = nowProvider.now()
        let place = viewModel.plateePlace
        let schedule = viewModel.plateSchedule(at: now)

        ZStack(alignment: .bottom) {
            if let schedule {
                CelestialPlateScene(
                    markers: markers(from: schedule, now: now),
                    solarEvents: schedule.solarEvents,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    timeZone: place.timeZone,
                    now: now,
                    bottomInset: 260,
                    entrance: entrance
                )
                .ignoresSafeArea()
            } else {
                Color.clear.ihsanManuscriptPage().ignoresSafeArea()
            }

            panel(placeName: place.name)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(
                reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.9)
            ) {
                entrance = 1
            }
        }
    }

    private func panel(placeName: String) -> some View {
        let tokens = IhsanPageChrome.tokens(at: nowProvider.now())

        return VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            Text("Ihsan")
                .font(.system(size: 34, weight: .light, design: .serif))
                .kerning(1.5)
                .foregroundStyle(tokens.ink)

            Text(placeName.uppercased())
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(tokens.leafGold)

            Text(viewModel.hasLocation
                ? "These are your times."
                : "These are Makkah's times. Yours will take their place.")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: IhsanSpacing.sm) {
                if viewModel.hasLocation {
                    OnboardingPrimaryButton("Continue") {
                        viewModel.goNext(from: .plate)
                    }
                } else {
                    OnboardingPrimaryButton(
                        viewModel.isRequestingLocation ? "Asking…" : "Use my location"
                    ) {
                        Task { await viewModel.requestLocation() }
                    }
                    .disabled(viewModel.isRequestingLocation)

                    OnboardingGhostButton("Not now") {
                        viewModel.goNext(from: .plate)
                    }
                }
            }
            .padding(.top, IhsanSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(IhsanSpacing.md)
        .ihsanIlluminatedPanel(intensity: .regular)
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.bottom, IhsanSpacing.lg)
        .accessibilityElement(children: .contain)
    }

    /// Every marker is `.upcoming` except the one whose window is open.
    /// Nothing here is logged, because nothing has been.
    private func markers(
        from schedule: OnboardingViewModel.PlateSchedule,
        now: Date
    ) -> [CelestialPlateScene.Marker] {
        schedule.times.map { prayer, time in
            CelestialPlateScene.Marker(
                prayer: prayer,
                time: time,
                displayTime: time,
                state: schedule.current == prayer ? .current : .upcoming
            )
        }
    }
}
