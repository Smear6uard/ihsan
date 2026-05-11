import CoreLocation
import IhsanCore
import IhsanDesignSystem
import IhsanLocation
import IhsanPrayerTimes
import SwiftUI

/// The full-screen celestial reference overlay — opened from the
/// Today header's moon-phase glyph. Hosts the qibla compass and the
/// sun / moon detail panels so the user can find Mecca and read the
/// sky's current state without leaving the celestial aesthetic.
///
/// Layout, top to bottom:
///
/// 1. **Header** — page title "Celestial" in refined serif, the
///    inscription "DIRECTION & SKY" beneath, and a ✕ close affordance
///    on the right.
/// 2. **Qibla compass** — a large circular astrolabe-style dial with
///    degree marks, cardinal labels, a decorative centre ornament, and
///    a brass pointer that rotates in real time to point at Mecca.
/// 3. **Compass inscriptions** — qibla bearing in degrees from
///    true / magnetic north, plus great-circle distance to Mecca.
/// 4. **Sun and Moon panels** — two small illuminated panels side by
///    side carrying the prayer ornaments + altitude / azimuth /
///    illumination data.
///
/// Dismissal: tap ✕ or swipe down.
struct CelestialReferenceView: View {
    let latitude: Double
    let longitude: Double
    let onDismiss: () -> Void

    @State private var viewModel = CelestialReferenceViewModel()

    var body: some View {
        ZStack {
            IhsanColor.nightPage
                .ignoresSafeArea()

            // A faint star field anchors the overlay in the same
            // material vocabulary as the Today screen at night.
            StarField()
                .opacity(0.40)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, IhsanSpacing.lg)
                    .padding(.top, IhsanSpacing.md)

                Spacer(minLength: IhsanSpacing.md)

                compassBlock

                Spacer(minLength: IhsanSpacing.md)

                sunAndMoonRow
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.bottom, IhsanSpacing.xl)
            }
        }
        .task {
            await viewModel.bootstrap(latitude: latitude, longitude: longitude)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 80 {
                        Haptics.tap()
                        onDismiss()
                    }
                }
        )
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Celestial")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundStyle(IhsanColor.boneCream)
                Text("DIRECTION & SKY")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(IhsanColor.brass.opacity(0.80))
            }

            Spacer(minLength: IhsanSpacing.sm)

            Button {
                Haptics.tap()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(IhsanColor.brass)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Compass + inscriptions

    @ViewBuilder
    private var compassBlock: some View {
        VStack(spacing: IhsanSpacing.md) {
            CelestialCompassDial(
                qiblaBearing: qiblaBearingForDisplay,
                currentHeading: viewModel.currentHeadingForDisplay,
                isAligned: viewModel.isAligned
            )
            .frame(width: 280, height: 280)

            VStack(spacing: 6) {
                inscriptionLine
                    .accessibilityLabel(compassAccessibilityLabel)
                NorthReferenceToggle(useMagnetic: $viewModel.useMagneticNorth)
            }
        }
    }

    @ViewBuilder
    private var inscriptionLine: some View {
        VStack(spacing: 4) {
            if viewModel.isAligned {
                Text("FACING QIBLA")
                    .font(IhsanFont.inscription)
                    .tracking(2.4)
                    .foregroundStyle(IhsanColor.gold)
                    .transition(.opacity)
            } else {
                Text(bearingInscription)
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .foregroundStyle(IhsanColor.brass.opacity(0.85))
                    .monospacedDigit()
            }
            Text(distanceInscription)
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(IhsanColor.brass.opacity(0.70))
                .monospacedDigit()
        }
        .animation(.smooth(duration: 0.18), value: viewModel.isAligned)
    }

    private var bearingInscription: String {
        let formatted = CompassDirection.format(qiblaBearingForDisplay)
        let reference = viewModel.useMagneticNorth ? "MAGNETIC NORTH" : "TRUE NORTH"
        return "QIBLA BEARING: \(formatted) FROM \(reference)"
    }

    private var distanceInscription: String {
        "DISTANCE TO MAKKAH: \(DistanceFormatter.kilometers(viewModel.distanceToMakkahKm))"
    }

    private var compassAccessibilityLabel: String {
        let bearing = CompassDirection.format(qiblaBearingForDisplay)
        let reference = viewModel.useMagneticNorth ? "magnetic north" : "true north"
        return "Qibla bearing: \(bearing) from \(reference). "
            + "Distance to Mecca: \(DistanceFormatter.kilometers(viewModel.distanceToMakkahKm))."
    }

    /// Bearing displayed on the dial and inscription. When the user
    /// toggles to magnetic north the bearing shifts by the local
    /// magnetic declination — derived from CoreLocation's heading
    /// sample so we don't ship a world declination model.
    private var qiblaBearingForDisplay: Double {
        viewModel.qiblaBearingForDisplay
    }

    // MARK: - Sun and Moon panels

    @ViewBuilder
    private var sunAndMoonRow: some View {
        HStack(spacing: IhsanSpacing.md) {
            SunDetailPanel(solar: viewModel.solarPosition)
            MoonDetailPanel(lunar: viewModel.lunarPosition, date: viewModel.referenceDate)
        }
    }
}

// MARK: - Compass dial

/// The big circular qibla compass — an astrolabe-style dial. Brass
/// outer ring with degree marks at every 30°, cardinal labels at the
/// four compass points, a thinner inner ring, a decorative 8-pointed
/// star at the centre, and a rotating brass pointer that swings to
/// indicate the bearing to Mecca relative to the device's heading.
private struct CelestialCompassDial: View {
    /// Qibla bearing in degrees from north (true or magnetic per the
    /// active reference toggle), 0-360.
    let qiblaBearing: Double
    /// Device heading in degrees from the same reference north, 0-360.
    let currentHeading: Double
    /// True when the device is pointed within ±2° of qibla.
    let isAligned: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            outerRing
            degreeMarks
            cardinalLabels
            innerRing
            centerOrnament
            qiblaPointer
        }
    }

    // MARK: - Rings

    private var outerRing: some View {
        Circle()
            .strokeBorder(IhsanColor.brass.opacity(0.70), lineWidth: 1)
    }

    private var innerRing: some View {
        Circle()
            .strokeBorder(IhsanColor.brass.opacity(0.40), lineWidth: 0.6)
            .padding(28)
    }

    // MARK: - Degree marks

    @ViewBuilder
    private var degreeMarks: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ForEach(0..<12, id: \.self) { i in
                let angleDeg = Double(i) * 30.0
                let isCardinal = i % 3 == 0
                let lineLength: CGFloat = isCardinal ? 12 : 6
                let opacity: Double = isCardinal ? 0.85 : 0.50
                let lineWidth: CGFloat = isCardinal ? 1.2 : 0.8
                Path { path in
                    let angle = (angleDeg - 90) * .pi / 180
                    let startX = center.x + CGFloat(cos(angle)) * (radius - 2)
                    let startY = center.y + CGFloat(sin(angle)) * (radius - 2)
                    let endX = center.x + CGFloat(cos(angle)) * (radius - 2 - lineLength)
                    let endY = center.y + CGFloat(sin(angle)) * (radius - 2 - lineLength)
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(IhsanColor.brass.opacity(opacity), lineWidth: lineWidth)
            }
        }
    }

    // MARK: - Cardinal labels

    @ViewBuilder
    private var cardinalLabels: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let inset: CGFloat = 24
            ForEach(["N", "E", "S", "W"], id: \.self) { label in
                let angleDeg: Double = {
                    switch label {
                    case "N": return 0
                    case "E": return 90
                    case "S": return 180
                    case "W": return 270
                    default: return 0
                    }
                }()
                let angle = (angleDeg - 90) * .pi / 180
                let x = center.x + CGFloat(cos(angle)) * (radius - inset)
                let y = center.y + CGFloat(sin(angle)) * (radius - inset)
                Text(label)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(IhsanColor.brass)
                    .position(x: x, y: y)
            }
        }
    }

    // MARK: - Centre ornament

    private var centerOrnament: some View {
        EightPointedStar()
            .stroke(IhsanColor.brass.opacity(0.30), lineWidth: 0.6)
            .frame(width: 36, height: 36)
    }

    // MARK: - Pointer

    @ViewBuilder
    private var qiblaPointer: some View {
        // Pointer rotation relative to the compass face: the compass
        // is fixed (N at top); the pointer indicates qibla bearing
        // adjusted for the device's current heading. So the pointer's
        // displayed angle = qiblaBearing - currentHeading. Smoothing
        // happens upstream in `CelestialReferenceViewModel`.
        let displayedAngle = qiblaBearing - currentHeading
        QiblaPointerShape()
            .fill(pointerFill)
            .frame(width: 18, height: 88)
            .offset(y: -22)
            .rotationEffect(.degrees(displayedAngle))
            .shadow(
                color: IhsanColor.gold.opacity(isAligned ? 0.65 : 0),
                radius: 10,
                x: 0,
                y: 0
            )
            .animation(reduceMotion ? nil : .smooth(duration: 0.10), value: displayedAngle)
            .animation(reduceMotion ? nil : .smooth(duration: 0.20), value: isAligned)
            .accessibilityElement()
            .accessibilityLabel(isAligned
                ? "Facing qibla."
                : "Qibla pointer, currently \(Int(displayedAngle.rounded())) degrees from heading.")
    }

    private var pointerFill: AnyShapeStyle {
        if isAligned {
            return AnyShapeStyle(IhsanColor.gold)
        }
        return AnyShapeStyle(IhsanIridescence.brassStroke())
    }
}

/// The brass qibla pointer — a tapered diamond / kite anchored at the
/// inner end (toward the centre) and extending outward toward the
/// outer ring. Rotates as a single unit so the wide tail stays near
/// the centre and the sharp tip lands at the bearing.
private struct QiblaPointerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midX
        path.move(to: CGPoint(x: mid, y: rect.minY))                // tip
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY * 0.55)) // right shoulder
        path.addLine(to: CGPoint(x: mid, y: rect.maxY))              // tail
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY * 0.55)) // left shoulder
        path.closeSubpath()
        return path
    }
}

// MARK: - North reference toggle

/// Small inscriptional toggle: TRUE NORTH · MAGNETIC NORTH. Defaults
/// to true north; switching to magnetic shifts the displayed qibla
/// bearing by the local magnetic declination (derived from the most
/// recent heading sample so we don't ship a world declination model).
private struct NorthReferenceToggle: View {
    @Binding var useMagnetic: Bool

    var body: some View {
        HStack(spacing: 8) {
            option("TRUE", selected: !useMagnetic) { useMagnetic = false }
            Text("·")
                .font(IhsanFont.inscription)
                .foregroundStyle(IhsanColor.brass.opacity(0.50))
            option("MAGNETIC", selected: useMagnetic) { useMagnetic = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(useMagnetic
            ? "North reference: magnetic. Double-tap to switch to true north."
            : "North reference: true. Double-tap to switch to magnetic north.")
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            Haptics.tap()
            useMagnetic.toggle()
        }
    }

    private func option(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(label)
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(selected ? IhsanColor.brass : IhsanColor.brass.opacity(0.45))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sun + Moon detail panels

private struct SunDetailPanel: View {
    let solar: SolarPosition?

    var body: some View {
        VStack(spacing: IhsanSpacing.sm) {
            EightPointedStar()
                .fill(IhsanIridescence.brassStroke())
                .frame(width: 32, height: 32)
                .shadow(color: IhsanColor.gold.opacity(0.40), radius: 4)

            Text("SUN")
                .font(IhsanFont.inscription)
                .tracking(1.8)
                .foregroundStyle(IhsanColor.brass.opacity(0.85))

            VStack(spacing: 2) {
                detailRow(label: "ALTITUDE", value: altitudeText)
                detailRow(label: "AZIMUTH",  value: azimuthText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(IhsanSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(IhsanColor.panelNight.opacity(0.85))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(IhsanIridescence.brassStroke(opacity: 0.45), lineWidth: 0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var altitudeText: String {
        guard let solar else { return "—" }
        return "\(Int(solar.altitude.rounded()))°"
    }

    private var azimuthText: String {
        guard let solar else { return "—" }
        let cardinal = CompassDirection.cardinalAbbreviation(solar.azimuth)
        return "\(Int(solar.azimuth.rounded()))° \(cardinal)"
    }

    private var accessibilityLabel: String {
        guard let solar else { return "Sun position unavailable." }
        let alt = Int(solar.altitude.rounded())
        let az = Int(solar.azimuth.rounded())
        let cardinal = CompassDirection.cardinalAbbreviation(solar.azimuth)
        if solar.altitude < 0 {
            return "Sun, currently below horizon at \(alt) degrees, azimuth \(az) \(cardinal)."
        }
        return "Sun, currently at \(alt) degrees altitude, \(az) degrees azimuth, \(cardinal)."
    }
}

private struct MoonDetailPanel: View {
    let lunar: LunarPosition?
    let date: Date

    var body: some View {
        VStack(spacing: IhsanSpacing.sm) {
            Image(systemName: MoonPhase.bucket(at: date).symbolName)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(IhsanColor.brassPale)

            Text("MOON · \(MoonPhase.bucket(at: date).spokenLabel.uppercased())")
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(IhsanColor.brass.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VStack(spacing: 2) {
                detailRow(label: "ALTITUDE",     value: altitudeText)
                detailRow(label: "ILLUMINATION", value: illuminationText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(IhsanSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(IhsanColor.panelNight.opacity(0.85))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(IhsanIridescence.brassStroke(opacity: 0.45), lineWidth: 0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var altitudeText: String {
        guard let lunar else { return "—" }
        return "\(Int(lunar.altitude.rounded()))°"
    }

    private var illuminationText: String {
        guard let lunar else { return "—" }
        return "\(Int((lunar.illuminatedFraction * 100).rounded()))%"
    }

    private var accessibilityLabel: String {
        let phase = MoonPhase.bucket(at: date).spokenLabel
        guard let lunar else {
            return "Moon, \(phase)."
        }
        let illum = Int((lunar.illuminatedFraction * 100).rounded())
        let alt = Int(lunar.altitude.rounded())
        if lunar.altitude < 0 {
            return "Moon, \(phase), \(illum) percent illuminated, currently below horizon."
        }
        return "Moon, \(phase), \(illum) percent illuminated, currently \(alt) degrees above horizon."
    }
}

private func detailRow(label: String, value: String) -> some View {
    HStack {
        Text(label)
            .font(IhsanFont.inscription)
            .tracking(1.2)
            .foregroundStyle(IhsanColor.brass.opacity(0.70))
        Spacer()
        Text(value)
            .font(.system(size: 13, weight: .semibold).smallCaps())
            .tracking(1.0)
            .monospacedDigit()
            .foregroundStyle(IhsanColor.boneCream)
    }
}

// MARK: - View model

@Observable
@MainActor
final class CelestialReferenceViewModel {
    /// Most recent qibla bearing in degrees from true north (0-360).
    /// Initialized to `nil` until the user's coordinates resolve.
    private(set) var qiblaBearingTrueNorth: Double = 0
    /// Great-circle distance to the Kaaba in kilometers.
    private(set) var distanceToMakkahKm: Double = 0
    /// Latest smoothed device heading in degrees from true north.
    private(set) var trueHeading: Double = 0
    /// Latest local magnetic declination in degrees (`trueHeading -
    /// magneticHeading`). Updates with each heading sample.
    private(set) var magneticDeclination: Double = 0
    /// True when the device is pointed within ±2° of qibla.
    private(set) var isAligned: Bool = false
    /// Current solar position for the user's location.
    private(set) var solarPosition: SolarPosition?
    /// Current lunar position for the user's location.
    private(set) var lunarPosition: LunarPosition?
    /// Reference moment used by the sun / moon position math and the
    /// moon-phase glyph. Refreshed on a coarse interval so the view's
    /// displayed numbers stay current without per-frame work.
    private(set) var referenceDate: Date = .now

    /// User toggle — TRUE NORTH vs MAGNETIC NORTH on the bearing
    /// inscription. Drives the displayed bearing and dial offset.
    var useMagneticNorth: Bool = false

    private let locationProvider: LocationProviding
    private let smoother = HeadingSmoother(alpha: 0.18)
    @ObservationIgnored private nonisolated(unsafe) var headingTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var skyRefreshTask: Task<Void, Never>?

    init(locationProvider: LocationProviding = CoreLocationCoordinator.shared) {
        self.locationProvider = locationProvider
    }

    deinit {
        headingTask?.cancel()
        skyRefreshTask?.cancel()
    }

    func bootstrap(latitude: Double, longitude: Double) async {
        let coords = Coordinates(latitude: latitude, longitude: longitude)
        qiblaBearingTrueNorth = coords.qiblaBearing
        distanceToMakkahKm = coords.distanceToKaaba

        refreshSky(latitude: latitude, longitude: longitude)

        // Per-minute refresh for sun / moon position so the displayed
        // altitude and azimuth stay current while the overlay is open.
        skyRefreshTask?.cancel()
        skyRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                if Task.isCancelled { return }
                self?.refreshSky(latitude: latitude, longitude: longitude)
            }
        }

        if CLLocationManager.headingAvailable() {
            startHeadingUpdates()
        }
    }

    /// Qibla bearing in the user's chosen reference frame.
    var qiblaBearingForDisplay: Double {
        if useMagneticNorth {
            return (qiblaBearingTrueNorth - magneticDeclination + 360).truncatingRemainder(dividingBy: 360)
        }
        return qiblaBearingTrueNorth
    }

    /// Device heading in the user's chosen reference frame. Used to
    /// rotate the pointer relative to the (fixed) compass face.
    var currentHeadingForDisplay: Double {
        if useMagneticNorth {
            return (trueHeading - magneticDeclination + 360).truncatingRemainder(dividingBy: 360)
        }
        return trueHeading
    }

    private func startHeadingUpdates() {
        headingTask?.cancel()
        headingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let stream = try await self.locationProvider.headingUpdates()
                for await sample in stream {
                    // Smooth the true heading with the same low-pass
                    // used by the legacy qibla screen.
                    let true_ = sample.trueHeading >= 0 ? sample.trueHeading : sample.magneticHeading
                    self.trueHeading = self.smoother.smooth(true_)

                    // Derive the local magnetic declination from the
                    // sample. trueHeading - magneticHeading converges
                    // to the local declination over a few samples.
                    if sample.trueHeading >= 0, sample.magneticHeading >= 0 {
                        let raw = sample.trueHeading - sample.magneticHeading
                        var d = raw.truncatingRemainder(dividingBy: 360)
                        if d > 180 { d -= 360 }
                        if d < -180 { d += 360 }
                        self.magneticDeclination = d
                    }

                    self.updateAlignment()
                }
            } catch {
                // Heading unavailable — pointer stays static.
            }
        }
    }

    private func updateAlignment() {
        let delta = Self.angleDelta(currentHeadingForDisplay, qiblaBearingForDisplay)
        let alignedNow = abs(delta) <= 2
        if alignedNow && !isAligned {
            Haptics.success()
        }
        isAligned = alignedNow
    }

    private func refreshSky(latitude: Double, longitude: Double) {
        let now = Date.now
        referenceDate = now
        solarPosition = SolarPosition.compute(at: now, latitude: latitude, longitude: longitude)
        lunarPosition = LunarPosition.compute(at: now, latitude: latitude, longitude: longitude)
    }

    /// Signed shortest angular difference between two compass bearings,
    /// in (-180, 180].
    static func angleDelta(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }
}
