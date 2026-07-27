import IhsanCore
import SwiftUI

// The design-v2 verification gallery. This file is the hard gate for
// the palette rescue: the maintainer opens these previews on a
// physical OLED device, checks the morning state at 50% and 100%
// brightness, and approves or rejects before any screen work begins.
//
// Sections:
//   1. Four palette states as full-bleed ground + panel + text.
//   2. The five-ornament silhouette grid at 16 pt (acceptance test).
//   3. Every ornament in all four marker states at 24 pt and 44 pt.
//   4. Plate scenes at four fixed phases with deliberately extreme
//      high-latitude prayer times — nothing may clip.
//   5. A continuous phase scrub proving no color snapping.

// MARK: - 1. Palette specimens

struct PaletteSpecimenView: View {
    let state: PaletteState

    var body: some View {
        let tokens = state.tokens
        ZStack {
            tokens.groundGradient
            VStack(alignment: .leading, spacing: 14) {
                Text(state.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold).smallCaps())
                    .tracking(1.6)
                    .foregroundStyle(tokens.metal)

                Text("Asr in 42 minutes")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(tokens.ink)

                Text("The afternoon holds until the light turns.")
                    .font(.system(size: 14))
                    .foregroundStyle(tokens.inkSecondary)

                specimenPanel(tokens: tokens)

                Spacer(minLength: 0)

                // The horizon wash, shown as the band it is used in.
                LinearGradient(
                    colors: [
                        tokens.horizonWashValue.color.opacity(0),
                        tokens.horizonWashValue.color.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 34)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(tokens.metal.opacity(0.85))
                        .frame(height: 1)
                        .padding(.horizontal, 18)
                }
            }
            .padding(18)
        }
    }

    private func specimenPanel(tokens: SkyPaletteTokens) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dhuhr · logged in jamāʿah")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tokens.ink)
            Text("12:58 — on time")
                .font(.system(size: 13))
                .foregroundStyle(tokens.inkSecondary)
            HStack(spacing: 8) {
                statusChip("On time", color: tokens.positive)
                statusChip("Attention", color: tokens.attention)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tokens.panelFill)
                .overlay {
                    PanelTextureOverlay(tokens: tokens)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tokens.panelStroke, lineWidth: 1)
                }
        }
    }

    private func statusChip(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay {
                Capsule().stroke(color.opacity(0.45), lineWidth: 1)
            }
    }
}

/// The ≤8% parchment-fiber overlay — the ONLY form in which parchment
/// exists in v2. Static seeded speckle, clipped by the panel shape.
struct PanelTextureOverlay: View {
    let tokens: SkyPaletteTokens

    var body: some View {
        Canvas { context, size in
            var rng = SeededGenerator(state: 0x9A7C_11E0_2026_0727)
            let count = Int((size.width * size.height / 90).rounded())
            for _ in 0..<count {
                let x = rng.unit() * size.width
                let y = rng.unit() * size.height
                let w = 0.6 + rng.unit() * 1.8
                let h = 0.5 + rng.unit() * 0.7
                context.fill(
                    Path(CGRect(x: x, y: y, width: w, height: h)),
                    with: .color(tokens.panelTextureValue.color.opacity(
                        tokens.panelTextureOpacity * (0.35 + 0.65 * rng.unit())
                    ))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("1 · Palette states") {
    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
        GridRow {
            PaletteSpecimenView(state: .night)
            PaletteSpecimenView(state: .morning)
        }
        GridRow {
            PaletteSpecimenView(state: .afternoon)
            PaletteSpecimenView(state: .sunset)
        }
    }
    .ignoresSafeArea()
}

// MARK: - 2. Silhouette grid (the acceptance test, made visible)

struct SilhouetteGridView: View {
    // Near-black test ink — the palette bans pure #000000 everywhere,
    // including here.
    private let testInk = Color(red: 0.04, green: 0.04, blue: 0.05)
    private let paper = Color(red: 0.97, green: 0.97, blue: 0.96)

    var body: some View {
        VStack(spacing: 22) {
            Text("FIVE SILHOUETTES · 16 PT · SOLID INK")
                .font(.system(size: 10, weight: .semibold).smallCaps())
                .tracking(1.4)
                .foregroundStyle(testInk.opacity(0.6))

            HStack(spacing: 26) {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    PrayerOrnamentShape(prayer: prayer, mode: .filled)
                        .fill(testInk, style: FillStyle(eoFill: true))
                        .frame(width: 16, height: 16)
                }
            }

            // The same five, magnified 4× purely for inspection.
            HStack(spacing: 26) {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    VStack(spacing: 6) {
                        PrayerOrnamentShape(prayer: prayer, mode: .filled)
                            .fill(testInk, style: FillStyle(eoFill: true))
                            .frame(width: 64, height: 64)
                        Text(prayer.displayNameEnglish)
                            .font(.system(size: 10))
                            .foregroundStyle(testInk.opacity(0.7))
                    }
                }
            }
        }
        .padding(28)
        .background(paper)
    }
}

#Preview("2 · Silhouette grid 16pt") {
    SilhouetteGridView()
}

// MARK: - 3. Ornament states

struct OrnamentStateMatrixView: View {
    let paletteState: PaletteState

    var body: some View {
        let tokens = paletteState.tokens
        VStack(spacing: 18) {
            Text("\(paletteState.displayName.uppercased()) · 24 PT AND 44 PT")
                .font(.system(size: 10, weight: .semibold).smallCaps())
                .tracking(1.4)
                .foregroundStyle(tokens.inkSecondary)

            ForEach([CGFloat(24), CGFloat(44)], id: \.self) { size in
                VStack(spacing: 12) {
                    ForEach(PrayerMarkerState.allCases, id: \.self) { markerState in
                        HStack(spacing: size == 44 ? 26 : 20) {
                            ForEach(Prayer.allCases, id: \.self) { prayer in
                                PrayerMarkerOrnament(
                                    prayer: prayer,
                                    size: size,
                                    state: markerState,
                                    tokens: tokens
                                )
                            }
                            Text(markerState.rawValue)
                                .font(.system(size: 10))
                                .foregroundStyle(tokens.inkSecondary)
                                .frame(width: 86, alignment: .leading)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(tokens.groundGradient)
    }
}

#Preview("3 · Ornament states") {
    ScrollView {
        VStack(spacing: 0) {
            ForEach(PaletteState.allCases, id: \.self) { state in
                OrnamentStateMatrixView(paletteState: state)
            }
        }
    }
    .ignoresSafeArea(edges: .horizontal)
}

// MARK: - 4. Plate scenes at four fixed phases

/// A mock celestial scene: sky + luminous body + the five markers
/// placed by `PlateGeometry`, with deliberately extreme high-latitude
/// summer prayer times (Fajr 01:12, Isha 23:58) so the gallery proves
/// on sight that nothing ever clips.
struct GalleryPlateScene: View {
    let title: String
    let phase: SkyPhase
    let sunAltitude: Double
    let sunAzimuthUnit: Double
    let moonPhase: (fraction: Double, waxing: Bool)?
    let markerStates: [PrayerMarkerState]
    let probe: FrameTimeProbe

    /// High-latitude summer schedule, fixed instants.
    static let extremeEvents: [Date] = {
        let dayStart = Date(timeIntervalSinceReferenceDate: 806_000_000)
        return [
            dayStart.addingTimeInterval(1.2 * 3600),    // Fajr 01:12
            dayStart.addingTimeInterval(13.1 * 3600),   // Dhuhr
            dayStart.addingTimeInterval(18.4 * 3600),   // Asr
            dayStart.addingTimeInterval(23.2 * 3600),   // Maghrib
            dayStart.addingTimeInterval(23.96 * 3600)   // Isha 23:58
        ]
    }()

    static let extremeLabels = ["01:12", "13:06", "18:24", "23:12", "23:58"]

    var body: some View {
        let tokens = PaletteState.resolved(for: phase)
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let plate = PlateGeometry(rect: rect, eventTimes: Self.extremeEvents)

            ZStack {
                CelestialSkyView(
                    phase: phase,
                    sunAltitudeDegrees: sunAltitude,
                    horizonY: plate.horizonY,
                    probe: probe
                )

                // The day arc as a faint drafting guide.
                Path(plate.arcPath())
                    .stroke(tokens.metal.opacity(0.22), style: StrokeStyle(lineWidth: 0.8, dash: [1, 5]))

                // The luminous body.
                if let moonPhase {
                    LuminousBody(
                        kind: .moon(illuminatedFraction: moonPhase.fraction, isWaxing: moonPhase.waxing),
                        diameter: 44,
                        tokens: tokens
                    )
                    .position(plate.bodyPosition(altitudeDegrees: max(sunAltitude, 6) + 24, azimuthUnit: 1 - sunAzimuthUnit))
                }
                LuminousBody(kind: .sun, diameter: 48, tokens: tokens)
                    .position(plate.bodyPosition(altitudeDegrees: sunAltitude, azimuthUnit: sunAzimuthUnit))

                // The five markers with their labels.
                ForEach(Array(Prayer.allCases.enumerated()), id: \.offset) { index, prayer in
                    let position = plate.markerPosition(for: Self.extremeEvents[index])
                    PrayerMarkerOrnament(
                        prayer: prayer,
                        size: 24,
                        state: markerStates[index],
                        tokens: tokens
                    )
                    .position(position)
                    Text(Self.extremeLabels[index])
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(markerStates[index] == .current ? tokens.ink : tokens.inkSecondary)
                        .shadow(color: tokens.inkHalo, radius: 2)
                        .position(x: position.x, y: position.y + 24)
                }

                // Scene title + live frame-time readout.
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .semibold).smallCaps())
                        .tracking(1.2)
                        .foregroundStyle(tokens.inkSecondary)
                    FrameTimeReadout(probe: probe, tokens: tokens)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(height: 300)
        .clipped()
    }
}

/// Live render-loop numbers from the probe, refreshed twice a second.
struct FrameTimeReadout: View {
    let probe: FrameTimeProbe
    let tokens: SkyPaletteTokens

    var body: some View {
        TimelineView(.periodic(from: .distantPast, by: 0.5)) { _ in
            Text(String(
                format: "draw %.2f ms avg · %.2f ms max · %d frames",
                probe.averageMilliseconds,
                probe.maximumMilliseconds,
                probe.sampleCount
            ))
            .font(.system(size: 9).monospacedDigit())
            .foregroundStyle(tokens.inkSecondary.opacity(0.8))
        }
    }
}

struct PlateScenesView: View {
    private let probes = (0..<4).map { _ in FrameTimeProbe() }

    var body: some View {
        ScrollView {
            VStack(spacing: 1) {
                GalleryPlateScene(
                    title: "Pre-dawn · Fajr current",
                    phase: SkyPhase(unit: 0.06),
                    sunAltitude: -13,
                    sunAzimuthUnit: 0.10,
                    moonPhase: (fraction: 0.68, waxing: false),
                    markerStates: [.current, .upcoming, .upcoming, .upcoming, .upcoming],
                    probe: probes[0]
                )
                GalleryPlateScene(
                    title: "Mid-morning",
                    phase: .fixed(.morning),
                    sunAltitude: 30,
                    sunAzimuthUnit: 0.32,
                    moonPhase: nil,
                    markerStates: [.logged, .upcoming, .upcoming, .upcoming, .upcoming],
                    probe: probes[1]
                )
                GalleryPlateScene(
                    title: "Golden afternoon · Asr current",
                    phase: SkyPhase(unit: 0.58),
                    sunAltitude: 17,
                    sunAzimuthUnit: 0.74,
                    moonPhase: nil,
                    markerStates: [.logged, .passedUnlogged, .current, .upcoming, .upcoming],
                    probe: probes[2]
                )
                GalleryPlateScene(
                    title: "Dusk · Maghrib current",
                    phase: SkyPhase(unit: 0.70),
                    sunAltitude: -3,
                    sunAzimuthUnit: 0.92,
                    moonPhase: (fraction: 0.24, waxing: true),
                    markerStates: [.logged, .passedUnlogged, .logged, .current, .upcoming],
                    probe: probes[3]
                )
            }
        }
        .ignoresSafeArea(edges: .horizontal)
    }
}

#Preview("4 · Plate scenes (extreme times)") {
    PlateScenesView()
}

// MARK: - 5. Phase scrub — continuous interpolation proof

struct PhaseScrubView: View {
    @State private var unit: Double = 0.25
    private let probe = FrameTimeProbe()

    /// A plausible sun-altitude curve over the palette day, purely
    /// for the scrub demo: 0° at sunrise/maghrib anchors, peaking
    /// midday, deep below at night.
    private var sunAltitude: Double {
        55 * sin(2 * .pi * (unit - 0.125))
    }

    var body: some View {
        let phase = SkyPhase(unit: unit)
        let tokens = PaletteState.resolved(for: phase)
        VStack(spacing: 0) {
            ZStack {
                CelestialSkyView(
                    phase: phase,
                    sunAltitudeDegrees: sunAltitude,
                    probe: probe
                )
                VStack(spacing: 6) {
                    Text("No snapping, anywhere")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(tokens.ink)
                        .shadow(color: tokens.inkHalo, radius: 3)
                    Text("phase \(unit, format: .number.precision(.fractionLength(3))) · \(phase.dominantState.displayName)")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(tokens.inkSecondary)
                        .shadow(color: tokens.inkHalo, radius: 3)
                    if phase.inkHaloStrength > 0.01 {
                        Text("ink halo \(Int(phase.inkHaloStrength * 100))%")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(tokens.metal)
                    }
                }
            }
            .frame(height: 300)

            VStack(spacing: 8) {
                Slider(value: $unit, in: 0...1)
                HStack {
                    ForEach(["midnight", "sunrise", "noon", "maghrib", "isha"], id: \.self) { label in
                        Text(label)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        if label != "isha" { Spacer() }
                    }
                }
            }
            .padding(16)
        }
    }
}

#Preview("5 · Phase scrub") {
    PhaseScrubView()
}

// MARK: - Accessibility variants

#Preview("A11y · Reduce Transparency") {
    PlateScenesView()
        .environment(\.celestialForceReducedTransparency, true)
}

#Preview("A11y · Reduce Motion") {
    PlateScenesView()
        .environment(\.celestialForceReducedMotion, true)
}
