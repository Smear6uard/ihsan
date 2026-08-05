import IhsanCore
import SwiftUI

/// Large (4×4): the plate, miniature.
///
/// The app's celestial plate reduced to what survives at four inches:
/// the real sky as the ground, the day's arc with all five ornaments
/// at their true (gently separated) positions, the sunrise tick, the
/// sun or moon standing over the arc at this very hour, a horizon
/// filament, and beneath it the focused block — the next prayer in
/// both scripts with its time as the primary numeral. This is the
/// face that gets screenshotted; it must be the app at its most
/// itself.
public struct PlateFace: View {
    public let model: WidgetDayModel
    public let tokens: SkyPaletteTokens
    public let mode: WidgetFaceMode
    public var usesStandByInk: Bool

    public static let ornamentSize: CGFloat = 26

    public init(
        model: WidgetDayModel,
        tokens: SkyPaletteTokens,
        mode: WidgetFaceMode = .fullColor,
        usesStandByInk: Bool = false
    ) {
        self.model = model
        self.tokens = tokens
        self.mode = mode
        self.usesStandByInk = usesStandByInk
    }

    public var body: some View {
        GeometryReader { proxy in
            let bandHeight = proxy.size.height * 0.44
            VStack(spacing: 0) {
                celestialBand(size: CGSize(width: proxy.size.width, height: bandHeight))
                    .frame(height: bandHeight)

                horizonFilament

                focusedBlock
                    .padding(.top, IhsanSpacing.sm)

                Spacer(minLength: 0)

                baseRow
            }
        }
        .environment(\.celestialForceReducedMotion, true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - The celestial band

    @ViewBuilder
    private func celestialBand(size: CGSize) -> some View {
        let arc = ArcGeometry(size: size, ornamentSize: Self.ornamentSize)
        let centers = DayStripFace.ornamentCenters(
            slots: model.slots,
            in: size
        )

        ZStack(alignment: .topLeading) {
            ArcPath(arc: arc)
                .stroke(
                    LinearGradient(
                        colors: [
                            tokens.metal.opacity(0.20),
                            tokens.metal.opacity(0.55),
                            tokens.metal.opacity(0.20)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round)
                )
                .widgetFaceAccent(mode)

            if let sunriseT = sunriseFraction {
                let point = arc.point(at: sunriseT)
                Path { path in
                    path.move(to: CGPoint(x: point.x, y: point.y - 4))
                    path.addLine(to: CGPoint(x: point.x, y: point.y + 4))
                }
                .stroke(tokens.metal.opacity(0.45), lineWidth: 1)
            }

            // The luminary of the hour stands over the arc — the sun
            // through the day, the moon with its true phase at night.
            // Positions are time alone; no coordinate ever reaches a
            // widget.
            if mode == .fullColor, let luminary = luminaryPlacement(arc: arc) {
                LuminousBody(kind: luminary.kind, diameter: 18, tokens: tokens)
                    .position(luminary.point)
            }

            ForEach(Array(model.slots.enumerated()), id: \.element.id) { index, slot in
                if index < centers.count {
                    PrayerMarkerOrnament(
                        prayer: slot.prayer,
                        size: Self.ornamentSize,
                        state: slot.state,
                        tokens: tokens
                    )
                    .widgetFaceAccent(mode)
                    .position(centers[index])
                }
            }
        }
    }

    private var sunriseFraction: CGFloat? {
        guard
            let first = model.slots.first?.time,
            let last = model.slots.last?.time,
            last > first
        else { return nil }
        return ArcLayout.fractions(times: [model.sunrise], span: first...last).first
    }

    private struct LuminaryPlacement {
        let kind: LuminousBody.Kind
        let point: CGPoint
    }

    private func luminaryPlacement(arc: ArcGeometry) -> LuminaryPlacement? {
        guard let maghrib = model.slots.first(where: { $0.prayer == .maghrib })?.time else {
            return nil
        }
        if model.date >= model.sunrise, model.date < maghrib {
            let daySpan = maghrib.timeIntervalSince(model.sunrise)
            guard daySpan > 0 else { return nil }
            let t = CGFloat(model.date.timeIntervalSince(model.sunrise) / daySpan)
            let onArc = arc.point(at: min(max(t, 0), 1))
            return LuminaryPlacement(
                kind: .sun,
                point: CGPoint(x: onArc.x, y: max(12, onArc.y - Self.ornamentSize - 4))
            )
        }
        if let night = model.night, night.start <= model.date, model.date < night.end {
            let span = night.end.timeIntervalSince(night.start)
            guard span > 0 else { return nil }
            let t = CGFloat(model.date.timeIntervalSince(night.start) / span)
            let onArc = arc.point(at: min(max(t, 0), 1))
            // Phase is position-independent to the eye; computing it
            // at the null island keeps coordinates out of widgets
            // while the crescent stays true.
            let lunar = LunarPosition.compute(at: model.date, latitude: 0, longitude: 0)
            return LuminaryPlacement(
                kind: .moon(
                    illuminatedFraction: lunar.illuminatedFraction,
                    isWaxing: lunar.isWaxing
                ),
                point: CGPoint(x: onArc.x, y: max(12, onArc.y - Self.ornamentSize - 4))
            )
        }
        return nil
    }

    // MARK: - Horizon and the focused block

    private var horizonFilament: some View {
        LinearGradient(
            colors: [
                tokens.metal.opacity(0.05),
                tokens.metal.opacity(0.5),
                tokens.metal.opacity(0.05)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
        .widgetFaceAccent(mode)
    }

    private var focusedBlock: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
            Text("NEXT")
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(faceSecondary)

            HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
                Text(model.clock(model.nextTime))
                    .font(.system(size: 40, weight: .thin, design: .rounded).monospacedDigit())
                    .foregroundStyle(facePrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .widgetFaceAccent(mode)

                VStack(alignment: .leading, spacing: 0) {
                    Text(model.nextPrayer.displayNameEnglish)
                        .font(.system(size: 19, weight: .semibold, design: .serif))
                        .foregroundStyle(facePrimary)
                        .widgetFaceAccent(mode)
                    Text(model.nextPrayer.displayNameArabic)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(faceSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }

            Text("in \(Text(timerInterval: model.countdown, countsDown: true))")
                .font(.system(size: 13, weight: .regular, design: .rounded).monospacedDigit())
                .foregroundStyle(faceSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var baseRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
            if let fasting = model.fasting {
                Text(fastingLine(fasting))
                    .font(IhsanFont.inscription)
                    .tracking(1.0)
                    .foregroundStyle(mode == .accented ? AnyShapeStyle(.secondary) : AnyShapeStyle(tokens.metal))
            } else if let city = model.cityName {
                Text(city.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.0)
                    .foregroundStyle(faceSecondary)
            }

            Spacer(minLength: IhsanSpacing.xs)

            if let hijri = model.hijri {
                Text(hijri.displayLine.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.0)
                    .foregroundStyle(faceSecondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func fastingLine(_ fasting: WidgetFastingModel) -> String {
        let prefix = fasting.isRamadan ? "RAMADAN" : "FASTING"
        if model.date < fasting.suhoorEnds {
            return "\(prefix) · SUHOOR ENDS \(model.clock(fasting.suhoorEnds).uppercased())"
        }
        return "\(prefix) · IFTAR \(model.clock(fasting.iftar).uppercased())"
    }

    // MARK: - Styles and voice

    private var facePrimary: AnyShapeStyle {
        mode == .accented
            ? AnyShapeStyle(.primary)
            : AnyShapeStyle(usesStandByInk ? tokens.standByInk : tokens.ink)
    }
    private var faceSecondary: AnyShapeStyle {
        mode == .accented
            ? AnyShapeStyle(.secondary)
            : AnyShapeStyle(usesStandByInk ? tokens.standByInkSecondary : tokens.inkSecondary)
    }

    private var accessibilityText: String {
        var text = "\(model.nextPrayer.displayNameEnglish) at \(model.clock(model.nextTime)). "
        text += model.slots.map {
            "\($0.prayer.displayNameEnglish) \(model.clock($0.time)), \($0.state.spokenDescription)"
        }.joined(separator: ", ")
        if let hijri = model.hijri {
            text += ". \(hijri.monthName) \(hijri.day)"
        }
        return text
    }
}
