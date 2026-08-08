import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import SwiftUI

/// The Today screen's instrument: palette-v2 atmosphere, the engraved
/// day arc, the five prayer ornaments, and the sun and moon at their
/// real positions — composed into one live scene.
///
/// This view owns no astronomy and no positioning math. Every point it
/// draws comes from `PlateGeometry`; every colour comes from the
/// resolved `SkyPaletteTokens`; the sun and moon come from
/// `SolarPosition` / `LunarPosition`. What it owns is the composition:
/// which layer sits over which, how big each ornament is, and where a
/// label hangs off its marker.
///
/// Two horizontal conventions live on the plate, deliberately:
///
/// - **Markers** are placed by time — `markerPosition(for:)` maps the
///   day's Fajr…Isha domain onto the arc's inset angular span, so the
///   arc reads as the day's engraved scale and no marker can reach the
///   frame.
/// - **Bodies** are placed by sky position — real altitude, and a
///   horizontal parameter derived from the local hour angle (see
///   `azimuthUnit(hourAngle:)`). The sun and the moon therefore share
///   one continuous scale and sit correctly relative to each other.
///
/// The view keeps no state. It is a pure function of the data handed
/// to it plus the moment, so it renders identically in the app, in a
/// preview, and in an offline snapshot harness.
struct CelestialPlateScene: View {

    /// One prayer on the plate: which ornament, when, and what
    /// lifecycle state it is in.
    ///
    /// `time` places the marker on the arc — always today's instant,
    /// so the arc's engraved scale stays the civil day. `displayTime`
    /// is what the label prints: the caller passes the same display
    /// instant the header and card show (post-Isha, Fajr's label
    /// rolls to tomorrow's Fajr), so no two surfaces can disagree
    /// about a time to the minute.
    struct Marker: Identifiable, Equatable {
        let prayer: Prayer
        let time: Date
        let displayTime: Date
        let state: PrayerMarkerState

        var id: Prayer { prayer }

        init(
            prayer: Prayer,
            time: Date,
            displayTime: Date? = nil,
            state: PrayerMarkerState
        ) {
            self.prayer = prayer
            self.time = time
            self.displayTime = displayTime ?? time
            self.state = state
        }
    }

    /// The day's five fardh markers, in chronological order.
    let markers: [Marker]
    /// The solar events that anchor the palette phase. Supplied by the
    /// caller from the day's real prayer schedule — the design system
    /// never computes prayer times.
    let solarEvents: SolarDayEvents
    let latitude: Double
    let longitude: Double
    /// Timezone the marker labels are formatted in. Prayer times are
    /// absolute instants; the plate is the UI layer that localises them.
    let timeZone: TimeZone

    /// The moment to render. The scene owns no clock — the Today
    /// screen's single timeline resolves this through NowProvider and
    /// hands the same instant to every layer.
    let now: Date

    /// Room reserved at the top of the frame for the header, and at the
    /// bottom for the focused card. The atmosphere still fills the whole
    /// frame — only the arc, the markers, and the horizon respect these.
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0

    /// Preferred horizon chord height as a fraction of the plate,
    /// handed down from `TodayCompositionMetrics` so the 65:35
    /// screen-level proportion has one source of truth.
    var horizonFraction: CGFloat = 0.72

    /// Tonight's divided night, when the caller has computed it. The plate
    /// gains its night geometry only while the moment lies inside this
    /// span — between Maghrib and the next true Fajr. `nil`, or any
    /// daytime instant, renders exactly the pre-night plate.
    var night: NightIntervals?
    /// Marker tap — the Today screen swaps the focused card to this
    /// prayer. `nil` makes the plate non-interactive.
    var onMarkerTap: ((Prayer) -> Void)?
    /// Optional render-loop instrumentation.
    var probe: FrameTimeProbe?

    /// Entrance choreography flag: 0 before the scene has entered,
    /// 1 at rest. The owner flips it 0→1 once per cold open (and per
    /// foreground after a long absence); each layer animates toward
    /// it on its own staggered clock — the arc draws in, ornaments
    /// bloom in prayer order, the celestial glow arrives last,
    /// 0.9 s in total. Under Reduce Motion every stagger collapses
    /// to one 300 ms crossfade.
    var entrance: Double = 1.0

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Entrance choreography
    //
    // The numbers live in `EntranceChoreography` so the order — arc,
    // then ornaments in prayer order, then light — is stated once and
    // can be tested, rather than spread across three literals here.

    private var crossfade: Animation { EntranceChoreography.crossfade }

    private var arcEntranceAnimation: Animation {
        EntranceChoreography.arc(reduceMotion: reduceMotion)
    }

    private func markerEntranceAnimation(index: Int) -> Animation {
        EntranceChoreography.marker(index: index, reduceMotion: reduceMotion)
    }

    private var glowEntranceAnimation: Animation {
        EntranceChoreography.glow(reduceMotion: reduceMotion)
    }

    // MARK: - Composition constants
    //
    // Sizes only. Every *position* comes from PlateGeometry.

    private static let markerSize: CGFloat = 29
    /// The prayer happening now is drawn larger as well as luminous;
    /// size and light together make it the focal point at arm's length.
    private static let currentMarkerSize: CGFloat = 41
    /// Half-extent PlateGeometry reserves around every marker position.
    /// Comfortably clears the 41 pt ornament; the decorative glow halo
    /// is allowed to bleed past it.
    private static let markerClearance: CGFloat = 36
    /// Vertical room reserved below markers for their two-line
    /// name-over-time labels.
    private static let labelClearance: CGFloat = 68
    private static let sunDiameter: CGFloat = 56
    private static let moonDiameter: CGFloat = 44

    // MARK: - Body

    var body: some View {
        // The scene is a pure function of `now` — the Today screen's
        // single one-second timeline drives it, so the sun, markers,
        // and palette can never lag the card or the header. The
        // atmosphere's own decorative loop lives inside
        // `CelestialSkyView` and freezes under Reduce Motion; state
        // updates here are correctness, not motion, and never pause.
        scene(at: now)
    }

    @ViewBuilder
    private func scene(at date: Date) -> some View {
        let phase = SkyPhase.resolve(at: date, events: solarEvents)
        let tokens = PaletteState.resolved(for: phase)
        let sun = SolarPosition.compute(at: date, latitude: latitude, longitude: longitude)
        let moon = LunarPosition.compute(at: date, latitude: latitude, longitude: longitude)
        // The day's solar culmination — the plate's vertical scale is
        // normalised to it so the sun tops the arc exactly at solar
        // noon. Dhuhr is the schedule's stand-in for the transit.
        let apexAltitude = SolarPosition.compute(
            at: solarEvents.solarNoon, latitude: latitude, longitude: longitude
        ).altitude

        GeometryReader { geometry in
            let plate = plateGeometry(in: geometry.size)

            ZStack {
                CelestialSkyView(
                    phase: phase,
                    sunAltitudeDegrees: sun.altitude,
                    sunX: plate.bodyPosition(
                        altitudeDegrees: sun.altitude,
                        azimuthUnit: azimuthUnit(hourAngle: sun.hourAngle),
                        apexAltitudeDegrees: apexAltitude
                    ).x,
                    horizonY: plate.horizonY,
                    plateHeight: plate.rect.height,
                    probe: probe
                )

                atmosphere(
                    plate: plate, tokens: tokens, sun: sun, moon: moon,
                    apexAltitude: apexAltitude
                )
                .opacity(entrance)
                .animation(glowEntranceAnimation, value: entrance)

                engravedField(
                    plate: plate, tokens: tokens, date: date,
                    sun: sun, apexAltitude: apexAltitude,
                    beforeSunrise: date < solarEvents.sunrise
                )
                    .opacity(entrance)
                    .overlay {
                        sunriseMark(plate: plate, tokens: tokens)
                            .opacity(entrance)
                    }
                    .mask {
                        // The draw-in: the arc's canvas reveals left to
                        // right, so the filament traces the day's
                        // direction. Full-width (static) under Reduce
                        // Motion — the crossfade above is the entrance.
                        Rectangle()
                            .scaleEffect(
                                x: reduceMotion ? 1 : max(0.0001, entrance),
                                y: 1,
                                anchor: .leading
                            )
                    }
                    .animation(arcEntranceAnimation, value: entrance)

                Group {
                    if let night, night.contains(date) {
                        nightLayer(plate: plate, tokens: tokens, night: night, date: date)
                    }
                    bodies(
                        plate: plate, tokens: tokens, sun: sun, moon: moon,
                        apexAltitude: apexAltitude,
                        beforeSunrise: date < solarEvents.sunrise
                    )
                }
                .opacity(entrance)
                .animation(glowEntranceAnimation, value: entrance)

                markerLayer(plate: plate, tokens: tokens)
            }
        }
    }

    /// The instrument zone: full width, inset from the header above and
    /// the card below. Positions come back in the parent's coordinate
    /// space, so the atmosphere (which fills the whole frame) and the
    /// markers agree on where the horizon is.
    private func plateGeometry(in size: CGSize) -> PlateGeometry {
        let height = max(160, size.height - topInset - bottomInset)
        return PlateGeometry(
            rect: CGRect(x: 0, y: topInset, width: size.width, height: height),
            eventTimes: markers.map(\.time),
            horizonFraction: horizonFraction,
            markerClearance: Self.markerClearance,
            labelClearance: Self.labelClearance
        )
    }

    // MARK: - Atmosphere

    /// How far each body's light reaches into the sky.
    ///
    /// The bodies themselves are `LuminousBody`'s business — a disc and
    /// a tight halo. How much sky that light *tints* is the scene's,
    /// because it is a property of the air between the body and the
    /// observer, not of the body. So the sun gets a wide warm bloom
    /// that flattens along the horizon as it sets, and the moon gets a
    /// much tighter cool one.
    ///
    /// Both stay at low alpha deliberately — never above 0.26. The
    /// plate's film grain is painted by `CelestialSkyView` underneath
    /// this layer, so keeping the bloom faint leaves at least
    /// three-quarters of that grain's amplitude intact through it.
    /// Measured down a sky column at 2×, the composited result steps
    /// every 3.0–3.7 px on average with a 31 px worst-case flat run;
    /// whether that worst run reads as a contour is an OLED question
    /// and belongs on a device, not in a render harness.
    ///
    /// Reduce Transparency removes the whole layer, matching the sky
    /// view's own contract that gradients collapse to flat fills.
    @ViewBuilder
    private func atmosphere(
        plate: PlateGeometry,
        tokens: SkyPaletteTokens,
        sun: SolarPosition,
        moon: LunarPosition,
        apexAltitude: Double
    ) -> some View {
        if !reduceTransparency {
            let onDarkGround = tokens.groundBottomValue.relativeLuminance < 0.5
            Canvas { context, size in
                // Deliberately unclipped. An earlier revision cut the
                // bloom off just below the chord to keep light "in the
                // sky", which drew a straight edge across the plate at
                // dusk — the one thing light never does. Letting it
                // spill means the ground catches the last of the sun,
                // which is what the ground does.
                drawSolarBloom(
                    into: context, size: size, plate: plate, tokens: tokens,
                    sun: sun, apexAltitude: apexAltitude
                )
                if onDarkGround {
                    drawLunarBloom(
                        into: context, size: size, plate: plate,
                        tokens: tokens, sun: sun, moon: moon,
                        apexAltitude: apexAltitude
                    )
                }
            }
            // On a jewel ground the bloom lifts the sky the way glare
            // lifts a dark lens. On the near-white days additive light
            // would only clip to white, so it tints instead — the same
            // polarity rule LuminousBody uses for its halo.
            .blendMode(onDarkGround ? .plusLighter : .normal)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// The sun's bloom: widest and faintest overhead, tightening and
    /// intensifying as the sun drops toward the chord — which is the
    /// moment the horizon band should catch fire — then gone by the
    /// time civil twilight is over.
    private func drawSolarBloom(
        into context: GraphicsContext,
        size: CGSize,
        plate: PlateGeometry,
        tokens: SkyPaletteTokens,
        sun: SolarPosition,
        apexAltitude: Double
    ) {
        let strength = solarBloomStrength(altitudeDegrees: sun.altitude)
        guard strength > 0.005 else { return }

        let center = plate.bodyPosition(
            altitudeDegrees: sun.altitude,
            azimuthUnit: azimuthUnit(hourAngle: sun.hourAngle)
        )
        let lowness = max(0.0, min(1.0, (40.0 - sun.altitude) / 40.0))
        let radius = size.width * (0.30 + 0.15 * lowness)

        // A low sun scatters along the horizon rather than around
        // itself, so the bloom flattens as it sets.
        var local = context
        let squash = 1.0 - 0.38 * lowness
        local.translateBy(x: center.x, y: center.y)
        local.scaleBy(x: 1, y: squash)
        local.translateBy(x: -center.x, y: -center.y)

        local.fill(
            Path(ellipseIn: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            )),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: tokens.glowValue.color.opacity(strength), location: 0),
                    .init(color: tokens.glowValue.color.opacity(strength * 0.34), location: 0.44),
                    .init(color: tokens.glowValue.color.opacity(0), location: 1)
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    /// Peak bloom sits at the horizon, not at noon — the sun tints most
    /// sky when its light travels the most air.
    private func solarBloomStrength(altitudeDegrees: Double) -> Double {
        if altitudeDegrees >= 40 { return 0.10 }
        if altitudeDegrees >= 0 {
            return 0.10 + 0.16 * (1.0 - altitudeDegrees / 40.0)
        }
        return max(0.0, 0.26 * (1.0 + altitudeDegrees / 8.0))
    }

    /// The moon's bloom: cool where the sun's is warm, and half its
    /// reach. Only drawn on jewel grounds — on the near-white days the
    /// cool pole of the palette is the deep indigo ink, and a dark
    /// halo around the moon would read as a smudge, not as light.
    private func drawLunarBloom(
        into context: GraphicsContext,
        size: CGSize,
        plate: PlateGeometry,
        tokens: SkyPaletteTokens,
        sun: SolarPosition,
        moon: LunarPosition,
        apexAltitude: Double
    ) {
        let strength = 0.17
            * submergedPresence(altitudeDegrees: moon.altitude)
            * lunarDaylightPresence(sunAltitudeDegrees: sun.altitude)
            * lunarDeference(plate: plate, sun: sun, moon: moon, apexAltitude: apexAltitude)
        guard strength > 0.005 else { return }

        let center = plate.bodyPosition(
            altitudeDegrees: moon.altitude,
            azimuthUnit: azimuthUnit(hourAngle: moon.hourAngle),
            apexAltitudeDegrees: apexAltitude
        )
        let radius = size.width * 0.15

        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            )),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: tokens.inkValue.color.opacity(strength), location: 0),
                    .init(color: tokens.inkValue.color.opacity(strength * 0.30), location: 0.40),
                    .init(color: tokens.inkValue.color.opacity(0), location: 1)
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    // MARK: - The engraved field

    /// Almucantar heights for the engraved field. Two only — the
    /// field should feel worked, not patterned.
    private static let almucantarRises: [CGFloat] = [0.36, 0.68]
    /// The knockout rule: linework terminates this far short of every
    /// ornament's and label's bounding form (spec: 6–8 pt).
    private static let filamentClearance: CGFloat = 7
    /// Peak opacity of the sun's engraved ray collar. Set by the
    /// discipline gate rather than by taste: at 0.34 the collar
    /// competed with the five ornaments at a glance, which is
    /// disqualifying however well it read up close.
    private static let sunRayOpacity: Double = 0.20

    /// The bounding forms belonging to prayer markers: each ornament
    /// and its two-line label block. Sunrise uses this same collection
    /// for its own bounded label placement and tick segmentation.
    private func markerKnockoutRects(plate: PlateGeometry) -> [CGRect] {
        markers.flatMap { marker -> [CGRect] in
            let position = plate.markerPosition(for: marker.time)
            let size = marker.state == .current ? Self.currentMarkerSize : Self.markerSize
            let ornament = CGRect(
                x: position.x - size / 2, y: position.y - size / 2,
                width: size, height: size
            )
            let labelCenterY = position.y + labelOffset(forMarkerSize: size)
            let label = CGRect(
                x: position.x - 28, y: labelCenterY - 13,
                width: 56, height: 26
            )
            return [ornament, label]
        }
    }

    /// Every engraved field filament also clears the sunrise
    /// inscription registered by PlateGeometry's layout contract.
    private func knockoutRects(plate: PlateGeometry) -> [CGRect] {
        markerKnockoutRects(plate: plate) + [sunriseLayout(plate: plate).labelFrame]
    }

    // MARK: - The sunrise mark

    /// The displayed solar schedule can belong to the coming civil day
    /// while the visible prayer cycle is still yesterday's (after
    /// midnight, before Fajr). PlateGeometry maps the real
    /// Fajr→sunrise→Dhuhr ratio onto the visible Fajr→Dhuhr arc segment,
    /// so next sunrise stays on the morning side in every SkyPhase.
    private func sunriseLayout(plate: PlateGeometry) -> PlateGeometry.SunriseMarkLayout {
        let markerFajr = markers.first { $0.prayer == .fajr }?.time ?? solarEvents.fajr
        let markerDhuhr = markers.first { $0.prayer == .dhuhr }?.time ?? solarEvents.solarNoon
        return plate.sunriseMarkLayout(
            sunrise: solarEvents.sunrise,
            fajr: solarEvents.fajr,
            dhuhr: solarEvents.solarNoon,
            markerFajr: markerFajr,
            markerDhuhr: markerDhuhr,
            avoiding: markerKnockoutRects(plate: plate),
            ornamentClearance: Self.filamentClearance
        )
    }

    /// Sunrise on the plate: a fine engraved tick crossing the arc at
    /// the sunrise position, with a quiet small-caps inscription. NO
    /// ornament — sunrise is not a prayer; it is subordinate to the
    /// five by construction. Always present; during dawn it is the
    /// visible endpoint of Fajr's window.
    @ViewBuilder
    private func sunriseMark(plate: PlateGeometry, tokens: SkyPaletteTokens) -> some View {
        let markerKnockouts = markerKnockoutRects(plate: plate)
        let layout = sunriseLayout(plate: plate)
        let tickSegments = plate.sunriseTickFilamentSegments(
            at: layout.point,
            avoiding: markerKnockouts,
            ornamentClearance: Self.filamentClearance
        )

        Canvas { context, _ in
            for segment in tickSegments {
                context.fill(Path(segment), with: .color(tokens.metal.opacity(0.65)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)

        Text("SUNRISE · \(Self.timeString(solarEvents.sunrise, in: timeZone).uppercased())")
            .font(Self.labelFont)
            .tracking(1.2)
            .foregroundStyle(tokens.inkSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .allowsTightening(true)
            .inkKeyline(tokens)
            // Outside the keyline: the modifier draws its content twice,
            // so a translucent foreground would composite with itself and
            // take a near-black wash from the upper copy's ring. Here the
            // inscription and its rings fade together.
            .opacity(0.9)
            .frame(
                width: layout.labelFrame.width,
                height: layout.labelFrame.height,
                alignment: .leading
            )
            .position(x: layout.labelFrame.midX, y: layout.labelFrame.midY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The day's scale and its field, engraved with knockout
    /// discipline: the arc and both almucantars terminate short of
    /// every ornament and label (each kept run is its own tapered
    /// ribbon, dissolving to a point at every termination), and the
    /// portion of the day already traveled is gilded — metalHighlight
    /// over the base metal, the transition fading across the moment's
    /// position on the arc. Driven by the scene's `now`; it advances
    /// continuously with the screen's one-second timeline.
    private func engravedField(
        plate: PlateGeometry,
        tokens: SkyPaletteTokens,
        date: Date,
        sun: SolarPosition,
        apexAltitude: Double,
        beforeSunrise: Bool
    ) -> some View {
        let knockouts = knockoutRects(plate: plate)
        let arcSegments = plate.arcFilamentSegments(
            avoiding: knockouts, clearance: Self.filamentClearance
        )
        // The gilded passage carries its own, heavier ribbon set: the
        // traversed line differs in WEIGHT as well as warmth, so even
        // the short runs between the crowded evening markers read
        // gilded at arm's length instead of pinching to hairlines.
        let gildSegments = plate.arcFilamentSegments(
            avoiding: knockouts, clearance: Self.filamentClearance,
            maxThickness: 2.6
        )
        let almucantarSegments = Self.almucantarRises.flatMap {
            plate.almucantarFilamentSegments(
                riseFraction: $0, avoiding: knockouts,
                clearance: Self.filamentClearance
            )
        }
        // Traversal is anchored on time-of-day progression through the
        // prayer sequence — the same mapping that places the markers —
        // never on the sun's position, which stops being a clock the
        // moment it sets. Past Isha the fraction clamps to 1 and the
        // whole arc reads traversed.
        let gildEdgeX: CGFloat? = markers.first.flatMap { first in
            date >= first.time ? plate.markerPosition(for: date).x : nil
        }

        // The almucantars used to sit at a flat 0.10 in every state,
        // which reads on the jewel grounds (metal clears 6:1 there)
        // and vanishes on the near-white days (~2.6:1). Corrective H
        // item 3 buys the day states back their structure: the
        // engraved field is what makes the sky read as an instrument
        // plate, and it was only doing that after dark. Ramped on
        // `daylightPresence` so nothing switches at the crossings, and
        // still less than a third of the arc's own weight at half its
        // ribbon thickness — the day arc stays the dominant line.
        let almucantarOpacity = 0.10 + 0.12 * tokens.daylightPresence

        // The sun's engraved ray collar (corrective H item 2) — the
        // Shamsa's twelve-fold construction around the real sun, cut
        // by the same knockouts as every other line on the plate. It
        // belongs to daylight and to the disc: it fades out with the
        // day field, and with the sun's own presence as it sets, so
        // the collar can never outlive the body it belongs to.
        let raySegments = plate.sunRayFilamentSegments(
            around: plate.bodyPosition(
                altitudeDegrees: sun.altitude,
                azimuthUnit: azimuthUnit(hourAngle: sun.hourAngle),
                apexAltitudeDegrees: apexAltitude
            ),
            bodyDiameter: Self.sunDiameter,
            avoiding: knockouts,
            clearance: Self.filamentClearance
        )
        let rayOpacity = Self.sunRayOpacity
            * tokens.daylightPresence
            * sunPresence(altitudeDegrees: sun.altitude, beforeSunrise: beforeSunrise)

        return Canvas { context, size in
            for segment in almucantarSegments {
                context.fill(Path(segment), with: .color(tokens.metal.opacity(almucantarOpacity)))
            }
            if rayOpacity > 0.01 {
                for segment in raySegments {
                    context.fill(Path(segment), with: .color(tokens.metal.opacity(rayOpacity)))
                }
            }
            for segment in arcSegments {
                context.fill(Path(segment), with: .color(tokens.metal.opacity(0.34)))
            }

            // The gilded passage: the same run, heavier and warmer,
            // masked to the traversed side of `now`.
            if let gildEdgeX, size.width > 0 {
                var clip = Path()
                for segment in gildSegments { clip.addPath(Path(segment)) }
                var gilded = context
                gilded.clip(to: clip)

                let fade = size.width * 0.10
                let solidUntil = max(0.0, (gildEdgeX - fade) / size.width)
                // The burning tip: the line is brightest exactly where
                // the day currently is — a true metalHighlight pole at
                // the leading edge of the gild (the value-range work of
                // the illumination pass), dissolving ahead of it.
                let tip = min(1.0, max(solidUntil, (gildEdgeX - fade * 0.15) / size.width))
                let fadedBy = min(1.0, max(tip, (gildEdgeX + fade) / size.width))
                gilded.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: tokens.metalHighlight.opacity(0.62), location: 0),
                            .init(color: tokens.metalHighlight.opacity(0.62), location: solidUntil),
                            .init(color: tokens.metalHighlight.opacity(0.95), location: tip),
                            .init(color: tokens.metalHighlight.opacity(0), location: fadedBy)
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    )
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - The divided night

    /// The night's geometry, drawn only between Maghrib and the next true
    /// Fajr: a mirrored arc beneath the chord, a fine metal filament at
    /// nisf al-layl, a soft luminance lift over the last third — the same
    /// ground material, one step brighter, never a colored overlay — and a
    /// quiet cursor for the present moment.
    ///
    /// Everything here is static per evaluation; the scene's own timeline
    /// (or its Reduce Motion snapshot) is the only clock. Reduce
    /// Transparency drops the cursor's glow to a flat disc; the region
    /// lift is already a flat fill.
    @ViewBuilder
    private func nightLayer(
        plate: PlateGeometry,
        tokens: SkyPaletteTokens,
        night: NightIntervals,
        date: Date
    ) -> some View {
        let geometry = plate.nightGeometry(
            nightStart: night.start,
            nisfAlLayl: night.nisfAlLayl,
            lastThirdStart: night.lastThirdStart,
            nightEnd: night.end
        )
        let inLastThird = date >= night.lastThirdStart
        let isDarkGround = tokens.groundBottomValue.relativeLuminance < 0.5
        let lift = tokens.groundBottomValue
            .scalingLightness(by: isDarkGround ? 0.82 : 0.90)
        // With the 65:35 ground plane the bowl is a miniature under
        // the chord. Below this depth the last-third region fill
        // compresses into a wedge that reads as an artifact, so the
        // compact bowl keeps only its linework: arc, midnight mark,
        // cursor. The labels have their own depth gate below.
        let compactBowl = plate.nightDepth < 40

        Canvas { context, _ in
            // The last third: a barely-brighter region within the ground.
            if !compactBowl {
                context.fill(
                    Path(plate.lastThirdRegionPath(
                        nightStart: night.start,
                        lastThirdStart: night.lastThirdStart,
                        nightEnd: night.end
                    )),
                    with: .color(lift.color)
                )
            }

            // The night's engraved scale — the same tapered filament
            // as the day's, quieter. No dashes.
            context.fill(
                Path(plate.nightArcFilamentPath()),
                with: .color(tokens.metal.opacity(0.22))
            )

            // The traversed night: the day arc's gilded passage
            // continues below the horizon, from nightfall to the
            // present moment. Time-anchored like the day's gilding —
            // the ribbon's taper dissolves exactly at the cursor, so
            // the line burns up to "now" and no further.
            context.fill(
                Path(plate.nightTraversedFilamentPath(
                    nightStart: night.start,
                    nightEnd: night.end,
                    now: date
                )),
                with: .color(tokens.metalHighlight.opacity(0.60))
            )

            // Nisf al-layl: a fine metal filament crossing the arc.
            context.fill(
                Path(plate.midnightFilamentPath(at: geometry.midnightPoint)),
                with: .color(tokens.metal.opacity(0.60))
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)

        if plate.nightDepth >= 60 {
            nightInscription("Midnight", tokens: tokens)
                .position(geometry.midnightLabelAnchor)
            nightInscription("Last third", tokens: tokens)
                .position(geometry.lastThirdLabelAnchor)
        }

        nightCursor(tokens: tokens, luminous: inLastThird)
            .position(
                plate.nightPosition(for: date, nightStart: night.start, nightEnd: night.end)
            )

        // One summary element carries the divided night for VoiceOver; the
        // engraved labels above are decorative duplicates at fixed size.
        Color.clear
            .frame(width: 1, height: 1)
            .position(geometry.midnightPoint)
            .accessibilityElement()
            .accessibilityLabel(nightAccessibilitySummary(night: night, inLastThird: inLastThird))

    }

    private func nightInscription(_ text: String, tokens: SkyPaletteTokens) -> some View {
        Text(text)
            .font(Self.labelFont)
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(tokens.inkSecondary)
            .inkKeyline(tokens)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The present moment on the night arc. Through the first two thirds
    /// it is a faint engraving; inside the last third it takes the quiet
    /// luminous treatment — a fixed halo, not an animation, so Reduce
    /// Motion needs no branch here.
    @ViewBuilder
    private func nightCursor(tokens: SkyPaletteTokens, luminous: Bool) -> some View {
        if luminous {
            Circle()
                .fill(tokens.metalHighlight)
                .frame(width: 5, height: 5)
                .background {
                    if !reduceTransparency {
                        RadialGradient(
                            colors: [tokens.glow.opacity(0.38), tokens.glow.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 16
                        )
                        .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .fill(tokens.glow.opacity(0.20))
                            .frame(width: 14, height: 14)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            Circle()
                .fill(tokens.metal.opacity(0.45))
                .frame(width: 4, height: 4)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func nightAccessibilitySummary(night: NightIntervals, inLastThird: Bool) -> String {
        let midnight = Self.timeString(night.nisfAlLayl, in: timeZone)
        let lastThird = Self.timeString(night.lastThirdStart, in: timeZone)
        if inLastThird {
            return "The last third of the night, since \(lastThird). Islamic midnight was \(midnight)."
        }
        return "Night. Islamic midnight \(midnight); the last third begins \(lastThird)."
    }

    // MARK: - Sun and moon

    @ViewBuilder
    private func bodies(
        plate: PlateGeometry,
        tokens: SkyPaletteTokens,
        sun: SolarPosition,
        moon: LunarPosition,
        apexAltitude: Double,
        beforeSunrise: Bool
    ) -> some View {
        // The moon is drawn first so the sun's halo passes over it
        // during the daytime conjunctions rather than under it.
        LuminousBody(
            kind: .moon(
                illuminatedFraction: moon.illuminatedFraction,
                isWaxing: moon.isWaxing
            ),
            diameter: Self.moonDiameter,
            tokens: tokens
        )
        .opacity(
            submergedPresence(altitudeDegrees: moon.altitude)
                * lunarDaylightPresence(sunAltitudeDegrees: sun.altitude)
                * lunarDeference(plate: plate, sun: sun, moon: moon, apexAltitude: apexAltitude)
        )
        .position(
            plate.bodyPosition(
                altitudeDegrees: moon.altitude,
                azimuthUnit: azimuthUnit(hourAngle: moon.hourAngle),
                apexAltitudeDegrees: apexAltitude
            )
        )

        LuminousBody(kind: .sun, diameter: Self.sunDiameter, tokens: tokens)
            .opacity(sunPresence(altitudeDegrees: sun.altitude, beforeSunrise: beforeSunrise))
            .position(
                plate.bodyPosition(
                    altitudeDegrees: sun.altitude,
                    azimuthUnit: azimuthUnit(hourAngle: sun.hourAngle),
                    apexAltitudeDegrees: apexAltitude
                )
            )
    }

    /// Before sunrise the sun renders NO disc — dawn is its glow at
    /// the horizon, nothing else. The disc fades in only across the
    /// last two degrees below the chord, so the crest at sunrise is
    /// continuous rather than a pop. After sunset the engraved
    /// below-horizon trace remains — that is maghrib's drama, and the
    /// evening side is untouched.
    private func sunPresence(altitudeDegrees: Double, beforeSunrise: Bool) -> Double {
        guard beforeSunrise, altitudeDegrees < 0 else {
            return submergedPresence(altitudeDegrees: altitudeDegrees)
        }
        let crest = max(0.0, 1.0 + altitudeDegrees / 2.0)
        return crest * crest * submergedPresence(altitudeDegrees: altitudeDegrees)
    }

    /// The plate's horizontal parameter for a body, from its local hour
    /// angle: −180° (lower transit) at the left edge, 0° (upper
    /// transit) at the centre, +180° at the right edge.
    ///
    /// One scale for both bodies means the moon sits correctly relative
    /// to the sun, and neither ever clamps against the plate's edge —
    /// the whole 24-hour circuit fits.
    private func azimuthUnit(hourAngle: Double) -> Double {
        0.5 + hourAngle / 360.0
    }

    /// A body below the chord is engraved into the ground plane rather
    /// than hidden — its presence falls away with depth and reaches its
    /// floor at astronomical twilight, which is exactly where
    /// `PlateGeometry` bottoms out its below-horizon mapping.
    ///
    /// The curve is deliberately steep. A body a degree or two under
    /// the chord still belongs to the scene — that is the whole drama
    /// of maghrib — but by deep night the sun should be a trace in the
    /// ground, not a dimmed disc floating in it.
    private func submergedPresence(altitudeDegrees: Double) -> Double {
        guard altitudeDegrees < 0 else { return 1 }
        let depth = min(18.0, -altitudeDegrees) / 18.0
        return 0.08 + 0.92 * pow(1.0 - depth, 2.5)
    }

    /// The moon is a quieter light than the sun: barely there against a
    /// high daytime sky, full strength once the sun is well down.
    /// Floor lowered 0.28 → 0.12 in corrective I — at 0.28 a daylight
    /// moon was still present enough to pull the eye off the five
    /// ornaments, which the discipline gate does not allow.
    private func lunarDaylightPresence(sunAltitudeDegrees: Double) -> Double {
        let t = max(0.0, min(1.0, (6.0 - sunAltitudeDegrees) / 24.0))
        return 0.12 + 0.88 * t
    }

    /// One voice leads the sky: when the moon stands inside the sun's
    /// horizon bloom (the sun near the chord, the moon within the
    /// bloom's ~35%-width radius), the moon's presence yields — down
    /// to ~35% at a dead-center conjunction — so the sunset belongs
    /// to the sun. Away from the bloom, or with the sun high or long
    /// set, the factor is exactly 1.
    private func lunarDeference(
        plate: PlateGeometry,
        sun: SolarPosition,
        moon: LunarPosition,
        apexAltitude: Double
    ) -> Double {
        let sunNearHorizon = exp(-pow(sun.altitude / 9.0, 2))
        guard sunNearHorizon > 0.02 else { return 1 }
        let sunPosition = plate.bodyPosition(
            altitudeDegrees: sun.altitude,
            azimuthUnit: azimuthUnit(hourAngle: sun.hourAngle),
            apexAltitudeDegrees: apexAltitude
        )
        let moonPosition = plate.bodyPosition(
            altitudeDegrees: moon.altitude,
            azimuthUnit: azimuthUnit(hourAngle: moon.hourAngle),
            apexAltitudeDegrees: apexAltitude
        )
        let bloomRadius = plate.rect.width * 0.35
        let separation = hypot(
            moonPosition.x - sunPosition.x, moonPosition.y - sunPosition.y
        )
        guard separation < bloomRadius else { return 1 }
        let closeness = 1 - separation / bloomRadius
        return 1 - 0.65 * closeness * sunNearHorizon
    }

    // MARK: - Markers

    @ViewBuilder
    private func markerLayer(plate: PlateGeometry, tokens: SkyPaletteTokens) -> some View {
        ForEach(Array(markers.enumerated()), id: \.element.id) { index, marker in
            let position = plate.markerPosition(for: marker.time)
            let size = marker.state == .current ? Self.currentMarkerSize : Self.markerSize
            let bloom = markerEntranceAnimation(index: index)

            ornamentButton(marker: marker, size: size, tokens: tokens)
                .scaleEffect(reduceMotion ? 1 : 0.85 + 0.15 * entrance)
                .opacity(entrance)
                .animation(bloom, value: entrance)
                .position(position)

            markerLabel(marker: marker, tokens: tokens)
                .opacity(entrance)
                .animation(bloom, value: entrance)
                .position(x: position.x, y: position.y + labelOffset(forMarkerSize: size))
        }
    }

    @ViewBuilder
    private func ornamentButton(
        marker: Marker,
        size: CGFloat,
        tokens: SkyPaletteTokens
    ) -> some View {
        let ornament = PrayerMarkerOrnament(
            prayer: marker.prayer,
            size: size,
            state: marker.state,
            tokens: tokens,
            ambientGlowBreathing: true
        )
        .frame(width: 48, height: 48)
        .contentShape(Rectangle())

        if let onMarkerTap {
            Button {
                Haptics.impact(.light)
                onMarkerTap(marker.prayer)
            } label: {
                ornament
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(for: marker))
            .accessibilityHint("Shows this prayer in the card below.")
        } else {
            ornament
                .accessibilityLabel(accessibilityLabel(for: marker))
        }
    }

    /// The engraved inscription under each marker: the prayer's name
    /// in small caps above its time — name primary in ink, time
    /// secondary in inkSecondary — per the corrective spec.
    private func markerLabel(marker: Marker, tokens: SkyPaletteTokens) -> some View {
        VStack(spacing: 2) {
            Text(marker.prayer.displayNameEnglish)
                .font(Self.labelFont)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(tokens.ink)
            Text(Self.timeString(marker.displayTime, in: timeZone))
                .font(Self.labelFont)
                .tracking(0.9)
                .foregroundStyle(tokens.inkSecondary)
        }
        .inkKeyline(tokens)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The label block hangs off the bottom of the ornament's box with
    /// a constant optical gap, inside the `labelClearance` the plate
    /// reserves below every marker position. The offset positions the
    /// block's center: half the ornament, the gap, half the block.
    private func labelOffset(forMarkerSize size: CGFloat) -> CGFloat {
        size / 2 + 8 + 13
    }

    private func accessibilityLabel(for marker: Marker) -> String {
        let time = Self.timeString(marker.displayTime, in: timeZone)
        let state: String
        switch marker.state {
        case .current: state = "happening now"
        case .logged: state = "logged"
        case .upcoming: state = "upcoming"
        case .passedUnlogged: state = "passed, not logged"
        }
        return "\(marker.prayer.displayNameEnglish) at \(time), \(state)"
    }

    // MARK: - Label typography
    //
    // `IhsanFont` bottoms out at 13 pt (`.inscription`), which is too
    // large for five labels on a phone-width arc. These match the sizes
    // the design-v2 gallery uses for the same job; a `plateLabel` token
    // belongs in IhsanFont, but adding it is out of scope for this
    // prompt (see the phase report).

    private static let labelFont: Font = .system(
        size: 10, weight: .semibold
    ).smallCaps().monospacedDigit()

    /// All marker times go through the shared Today formatter — the
    /// same one the header's "NEXT:" inscription uses — so the two can
    /// never disagree to the minute.
    private static func timeString(_ date: Date, in timeZone: TimeZone) -> String {
        PlateTimeFormat.time(date, in: timeZone)
    }
}
