import IhsanCore
import SwiftUI

/// Medium (4×2): the day strip.
///
/// Five ornaments along the day's arc at their true proportion —
/// gilded behind you, luminous now, outlined ahead — with each
/// prayer's time inscribed beneath its mark. In summer Maghrib and
/// Isha crowd close; `ArcLayout` keeps them apart just enough to stay
/// two marks. During a fast, the suhoor/iftar inscription joins the
/// header — the day's other clock.
public struct DayStripFace: View {
    public let model: WidgetDayModel
    public let tokens: SkyPaletteTokens
    public let mode: WidgetFaceMode
    public var usesStandByInk: Bool

    /// Ornament diameter on the strip.
    public static let ornamentSize: CGFloat = 24

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

    /// Where each slot's ornament center sits, in the strip band's
    /// own coordinates. Public so the widget extension lays its one
    /// tap target with the exact geometry that draws the ornament.
    public static func ornamentCenters(
        slots: [WidgetDayModel.Slot], in size: CGSize
    ) -> [CGPoint] {
        guard
            let first = slots.first?.time,
            let last = slots.last?.time,
            last > first
        else { return [] }
        let arc = ArcGeometry(size: size, ornamentSize: ornamentSize)
        let raw = ArcLayout.fractions(times: slots.map(\.time), span: first...last)
        let separated = ArcLayout.separated(raw, minimumGap: (ornamentSize + 2) / arc.width)
        return separated.map(arc.point(at:))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
            header
            strip
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
            if let fastingLine {
                Text(fastingLine)
                    .font(IhsanFont.inscription)
                    .tracking(1.0)
                    .foregroundStyle(mode == .accented ? AnyShapeStyle(.secondary) : AnyShapeStyle(tokens.metal))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else if let city = model.cityName {
                Text(city.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.0)
                    .foregroundStyle(faceSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: IhsanSpacing.xs)

            Text(model.nextPrayer.displayNameEnglish)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(facePrimary)
                .widgetFaceAccent(mode)
            Text("in")
                .font(IhsanFont.inscription)
                .tracking(0.8)
                .foregroundStyle(faceSecondary)
            Text(timerInterval: model.countdown, countsDown: true)
                .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(facePrimary)
                .widgetFaceAccent(mode)
        }
        .lineLimit(1)
    }

    /// Which of the fast's two clocks matters now: suhoor before
    /// Fajr, iftar through the rest of the day.
    private var fastingLine: String? {
        guard let fasting = model.fasting else { return nil }
        let prefix = fasting.isRamadan ? "RAMADAN" : "FASTING"
        if model.date < fasting.suhoorEnds {
            return "\(prefix) · SUHOOR ENDS \(model.clock(fasting.suhoorEnds).uppercased())"
        }
        return "\(prefix) · IFTAR \(model.clock(fasting.iftar).uppercased())"
    }

    // MARK: - The strip

    /// Which tier each time label sits on: 0 rides just under the
    /// band, 1 drops one step. A label is wider than its ornament, so
    /// summer's crowded evening pair would collide even after the
    /// ornaments separate — the second tier lets both stay whole and
    /// horizontally true to their marks.
    static func labelTiers(centers: [CGPoint], labelWidth: CGFloat) -> [Int] {
        var tiers = [Int](repeating: 0, count: centers.count)
        for index in 1..<max(centers.count, 1) where index < centers.count {
            let gap = centers[index].x - centers[index - 1].x
            if gap < labelWidth && tiers[index - 1] == 0 {
                tiers[index] = 1
            }
        }
        return tiers
    }

    private var strip: some View {
        GeometryReader { proxy in
            let band = CGSize(width: proxy.size.width, height: proxy.size.height - 28)
            let centers = Self.ornamentCenters(slots: model.slots, in: band)
            let tiers = Self.labelTiers(centers: centers, labelWidth: 56)
            let arc = ArcGeometry(size: band, ornamentSize: Self.ornamentSize)

            ZStack(alignment: .topLeading) {
                ArcPath(arc: arc)
                    .stroke(
                        strokeStyleForArc,
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )
                    .widgetFaceAccent(mode)

                if let sunriseT = sunriseFraction {
                    let point = arc.point(at: sunriseT)
                    Path { path in
                        path.move(to: CGPoint(x: point.x, y: point.y - 3))
                        path.addLine(to: CGPoint(x: point.x, y: point.y + 3))
                    }
                    .stroke(sunriseStroke, lineWidth: 1)
                }

                ForEach(Array(model.slots.enumerated()), id: \.element.id) { index, slot in
                    if index < centers.count {
                        let center = centers[index]
                        PrayerMarkerOrnament(
                            prayer: slot.prayer,
                            size: Self.ornamentSize,
                            state: slot.state,
                            tokens: tokens
                        )
                        .widgetFaceAccent(mode)
                        .position(center)

                        Text(model.clock(slot.time))
                            .font(.system(size: 11, weight: slot.state == .current ? .semibold : .regular, design: .rounded).monospacedDigit())
                            .foregroundStyle(slot.state == .current ? facePrimary : faceSecondary)
                            .lineLimit(1)
                            .fixedSize()
                            .position(
                                x: center.x,
                                y: band.height + 8 + CGFloat(tiers[index]) * 13
                            )
                    }
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
        let raw = ArcLayout.fractions(times: [model.sunrise], span: first...last)
        return raw.first
    }

    private var strokeStyleForArc: LinearGradient {
        LinearGradient(
            colors: [
                tokens.metal.opacity(0.20),
                tokens.metal.opacity(0.55),
                tokens.metal.opacity(0.20)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var sunriseStroke: Color {
        tokens.metal.opacity(0.45)
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
        var lines = model.slots.map {
            "\($0.prayer.displayNameEnglish) at \(model.clock($0.time)), \($0.state.spokenDescription)"
        }
        if let fastingLine {
            lines.insert(fastingLine.capitalized, at: 0)
        }
        return lines.joined(separator: ", ")
    }
}
