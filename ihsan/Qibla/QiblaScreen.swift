import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The qibla instrument — opened from the Today header's moon-phase
/// glyph as a full sheet. A brass degree ring on the living SkyPhase
/// ground: the card rotates with the smoothed heading (dial turns,
/// world stays fixed), the gilded lancet rides the card at the qibla
/// bearing, and a fixed index marks the direction the user faces.
/// Beneath the ring, exactly two inscriptions: distance and the live
/// relative direction. Above the ring: nothing.
struct QiblaScreen: View {
    let latitude: Double
    let longitude: Double
    let solarEvents: SolarDayEvents

    @Environment(\.nowProvider) private var nowProvider
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = QiblaViewModel()

    var body: some View {
        // The sky needs only coarse time; the instrument's motion is
        // driven by heading samples through the view model.
        TimelineView(.periodic(from: .distantPast, by: 60)) { context in
            let now = nowProvider.resolve(context.date)
            let phase = SkyPhase.resolve(at: now, events: solarEvents)
            let tokens = PaletteState.resolved(for: phase)
            let solar = SolarPosition.compute(
                at: now, latitude: latitude, longitude: longitude
            )

            ZStack {
                CelestialSkyView(
                    phase: phase,
                    sunAltitudeDegrees: solar.altitude,
                    horizonFraction: 0.65
                )
                .ignoresSafeArea()

                content(tokens: tokens)
            }
        }
        .task {
            await viewModel.bootstrap(latitude: latitude, longitude: longitude)
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    // MARK: - Availability switch

    @ViewBuilder
    private func content(tokens: SkyPaletteTokens) -> some View {
        GeometryReader { proxy in
            let ringSide = min(proxy.size.width * 0.86, proxy.size.height * 0.52)

            VStack(spacing: 0) {
                Spacer(minLength: proxy.size.height * 0.08)

                switch viewModel.availability {
                case .ready, nil:
                    instrument(tokens: tokens, ringSide: ringSide)

                    QiblaInscriptionsBlock(
                        tokens: tokens,
                        distanceKm: viewModel.distanceKm,
                        signedDelta: viewModel.reading?.signedDelta,
                        isAligned: viewModel.reading?.isAligned ?? false
                    )
                    .padding(.top, IhsanSpacing.lg)
                    // Holding alignment eases the inscriptions to
                    // their quietest register — just the instrument
                    // and the light. Reversal restores them.
                    .opacity(viewModel.isSettled ? 0.42 : 1)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.2),
                        value: viewModel.isSettled
                    )

                case .noCompassHardware:
                    QiblaStaticBearingView(
                        tokens: tokens,
                        qiblaBearing: viewModel.qiblaBearing,
                        distanceKm: viewModel.distanceKm,
                        ringSide: ringSide
                    )

                case .locationDenied:
                    QiblaLocationDeniedView(tokens: tokens)
                }

                Spacer()

                makersMark(tokens: tokens)
                    .padding(.bottom, IhsanSpacing.md)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - The live instrument

    @ViewBuilder
    private func instrument(tokens: SkyPaletteTokens, ringSide: CGFloat) -> some View {
        let ringRadius = ringSide / 2
        let isAligned = viewModel.reading?.isAligned ?? false
        // Under Reduce Motion the same choreography renders as one
        // discrete state per band — rotation still tracks (that's
        // function, not decoration), every glow ramp holds still.
        let approach = reduceMotion
            ? QiblaApproach(
                absDelta: abs(viewModel.reading?.signedDelta ?? 180),
                isAligned: isAligned,
                discrete: true
            )
            : viewModel.approach

        ZStack {
            // One calm breath across the ring at the moment of
            // arrival — keyed to the entry counter, so it can never
            // repeat while alignment holds.
            if !reduceMotion {
                QiblaBloomView(tokens: tokens, trigger: viewModel.bloomCount)
            }

            // The rotating card: ring engravings and the lancet turn
            // together; the card's angle is the negative heading, so
            // north on the card tracks true north in the world.
            ZStack {
                QiblaDialRing(tokens: tokens)
                QiblaLancetMark(
                    tokens: tokens,
                    ringRadius: ringRadius,
                    glowStrength: approach.lancetGlow
                )
                .rotationEffect(.degrees(viewModel.qiblaBearing))
            }
            .rotationEffect(.degrees(-viewModel.dialRotation))
            .animation(.linear(duration: 0.08), value: viewModel.dialRotation)

            // The approach light: ring warmth and the luminance
            // bridge, in fixed screen coordinates.
            if let reading = viewModel.reading {
                QiblaApproachOverlay(
                    tokens: tokens,
                    signedDelta: reading.signedDelta,
                    approach: approach,
                    isAligned: isAligned
                )
            }

            // Index and lancet fused into one luminous form. Fades in
            // on alignment; breaking alignment reverses gracefully.
            QiblaFusionGlow(tokens: tokens, ringRadius: ringRadius)
                .opacity(isAligned ? 1 : 0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.45),
                    value: isAligned
                )

            // The fixed marks: the user's own facing never rotates.
            QiblaIndexMark(
                tokens: tokens,
                ringRadius: ringRadius,
                warmth: approach.indexWarmth
            )
            QiblaHubMark(tokens: tokens, ringRadius: ringRadius)
        }
        .frame(width: ringSide, height: ringSide)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(instrumentAccessibilityLabel)
    }

    private var instrumentAccessibilityLabel: String {
        var parts = [
            "Qibla compass.",
            QiblaInscriptions.spokenDistance(km: viewModel.distanceKm) + ".",
        ]
        if let reading = viewModel.reading {
            parts.append(
                reading.isAligned
                    ? "Facing qibla."
                    : QiblaInscriptions.spokenDirection(signedDelta: reading.signedDelta) + "."
            )
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Maker's mark

    /// The resolved north reference, whispered at the page foot — the
    /// automatic answer to the question the instrument never asks.
    @ViewBuilder
    private func makersMark(tokens: SkyPaletteTokens) -> some View {
        Text(makersMarkText)
            .font(IhsanFont.inscription)
            .tracking(2.2)
            .foregroundStyle(tokens.inkSecondary.opacity(0.65))
            .accessibilityHidden(true)
    }

    private var makersMarkText: String {
        switch viewModel.reading?.northReference {
        case .magneticNorth: "MAGNETIC NORTH"
        case .trueNorth, nil: "TRUE NORTH"
        }
    }
}
