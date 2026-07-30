#if DEBUG
import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The widget faces, at their real sizes, inside the app.
///
/// A widget is drawn by WidgetKit on a home screen, which no test
/// harness can arrange reliably — so the parts that carry the design
/// (the ground, the arc, the ornament states, the register) are
/// rendered here at the exact point sizes iOS gives each family. What
/// this proves is the drawing; what it cannot prove is WidgetKit's own
/// container, which the Xcode previews in `ihsanWidgets/Previews`
/// cover.
///
/// Reached with `-IhsanDebugWidgetGallery`. DEBUG only.
struct WidgetFaceGallery: View {
    /// Point sizes for the iPhone 17 Pro's widget grid.
    private static let small = CGSize(width: 170, height: 170)
    private static let medium = CGSize(width: 364, height: 170)
    private static let large = CGSize(width: 364, height: 382)

    @State private var isNight = true

    private var moment: Date { isNight ? Self.nightMoment : Self.dawnMoment }
    private var tokens: SkyPaletteTokens {
        PaletteState.resolved(for: SkyPhase.resolve(at: moment, events: Self.events))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                Picker("Moment", selection: $isNight) {
                    Text("Night").tag(true)
                    Text("Dawn").tag(false)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("gallery-moment")

                label("Small")
                face(size: Self.small) { smallFace }

                label("Medium")
                face(size: Self.medium) { mediumFace }

                label("Large")
                face(size: Self.large) { largeFace }

                label("Nightstand (StandBy)")
                face(size: Self.small, ground: Self.standByGround) { standByFace }

                label("Lock screen")
                HStack(spacing: IhsanSpacing.md) {
                    lockFace
                    rectangularFace
                }
            }
            .padding(IhsanSpacing.md)
        }
        .ihsanManuscriptPage()
        .accessibilityIdentifier("widget-face-gallery")
    }

    // MARK: - Faces

    private var smallFace: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                PrayerMarkerOrnament(prayer: .isha, size: 22, state: .upcoming, tokens: tokens)
                Spacer(minLength: IhsanSpacing.xs)
                Text("CHICAGO")
                    .font(IhsanFont.inscription).tracking(0.8)
                    .foregroundStyle(tokens.inkSecondary)
            }
            Spacer(minLength: IhsanSpacing.xxs)
            Text("0:03")
                .font(.system(size: 28, weight: .regular, design: .rounded).monospacedDigit())
                .foregroundStyle(tokens.ink)
                .padding(.bottom, IhsanSpacing.xxs)
            Text("Isha")
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(tokens.ink)
            Text("9:43 PM")
                .font(.system(.footnote, design: .rounded).monospacedDigit())
                .foregroundStyle(tokens.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var mediumFace: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
                Text("CHICAGO")
                    .font(IhsanFont.inscription).tracking(1.0)
                    .foregroundStyle(tokens.inkSecondary)
                Spacer(minLength: IhsanSpacing.xs)
                Text("Isha").font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(tokens.ink)
                Text("in").font(IhsanFont.inscription).tracking(0.8)
                    .foregroundStyle(tokens.inkSecondary)
                Text("0:03")
                    .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tokens.ink)
            }
            CompactPlate(model: Self.model(at: moment), tokens: tokens, ornamentSize: 22)
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var largeFace: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                Text("CHICAGO")
                    .font(IhsanFont.inscription).tracking(1.2)
                    .foregroundStyle(tokens.inkSecondary)
                Text("0:03")
                    .font(.system(size: 40, weight: .thin, design: .rounded).monospacedDigit())
                    .foregroundStyle(tokens.ink)
                HStack(spacing: IhsanSpacing.xs) {
                    Text("UNTIL").font(IhsanFont.inscription).tracking(1.0)
                        .foregroundStyle(tokens.inkSecondary)
                    Text("Isha").font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(tokens.ink)
                    Text("العشاء").font(.system(size: 17))
                        .foregroundStyle(tokens.inkSecondary)
                }
            }
            CompactPlate(model: Self.model(at: moment), tokens: tokens, ornamentSize: 20)
                .frame(height: 54)
            Rectangle().fill(tokens.panelStroke.opacity(0.6)).frame(height: 0.5)
            ForEach(Self.model(at: moment).marks, id: \.prayer) { mark in
                HStack(spacing: IhsanSpacing.md) {
                    PrayerMarkerOrnament(
                        prayer: mark.prayer, size: 18, state: mark.state, tokens: tokens
                    )
                    .frame(width: 22)
                    Text(mark.prayer.displayNameEnglish)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(tokens.ink)
                    Spacer(minLength: IhsanSpacing.xs)
                    if mark.state == .logged {
                        Text("ON TIME").font(IhsanFont.inscription).tracking(1.0)
                            .foregroundStyle(tokens.leafGold)
                    }
                    Text(Self.clock(mark.time))
                        .font(.system(.subheadline, design: .rounded).monospacedDigit())
                        .foregroundStyle(tokens.inkSecondary)
                        .frame(minWidth: 62, alignment: .trailing)
                }
                .padding(.horizontal, IhsanSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var standByFace: some View {
        let ink = tokens.standByInk
        let inkSecondary = tokens.standByInkSecondary
        return VStack(alignment: .leading, spacing: 0) {
            Text("Isha")
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundStyle(ink)
            Text("9:43 PM")
                .font(.system(size: 30, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(ink)
            Text("NEXT · NOW IN MAGHRIB")
                .font(IhsanFont.inscription).tracking(1.4)
                .foregroundStyle(inkSecondary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: IhsanSpacing.xs)
            CompactPlate(
                model: Self.model(at: moment),
                tokens: PaletteState.night.tokens,
                ornamentSize: 17
            )
            .frame(height: 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var lockFace: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                LockRingSegment(index: index)
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .butt))
                    .foregroundStyle(index < 4 ? Color.white : Color.white.opacity(0.3))
            }
            OrnamentLinework(prayer: .isha, size: 17, isEmphasised: true)
        }
        .frame(width: 72, height: 72)
        .padding(6)
        .background(Circle().fill(.black.opacity(0.35)))
    }

    private var rectangularFace: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                OrnamentLinework(prayer: .isha, size: 13, isEmphasised: true)
                Text("Isha").font(.system(size: 14, weight: .semibold, design: .serif))
                Text("in").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                Text("0:03")
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
            }
            Text("9:43 PM")
                .font(.system(size: 12, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .padding(8)
        .frame(width: 160, height: 72, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.35)))
    }

    // MARK: - Chrome

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(IhsanFont.inscription)
            .tracking(1.4)
            .foregroundStyle(IhsanPageChrome.tokens(at: NowProvider.active.now()).inkSecondary)
    }

    private func face<Content: View>(
        size: CGSize,
        ground: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background {
                if let ground {
                    ground
                } else {
                    Self.homeGround(tokens: tokens)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private static func homeGround(tokens: SkyPaletteTokens) -> some View {
        LinearGradient(
            colors: [
                tokens.groundTopValue.scaled(0.90).color,
                tokens.groundBottomValue.scaled(0.84).color
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    private static var standByGround: AnyView {
        let tokens = PaletteState.night.tokens
        return AnyView(
            LinearGradient(
                colors: [
                    tokens.groundTopValue.scaled(0.55).color,
                    tokens.groundBottomValue.scaled(0.45).color
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    // MARK: - The day being drawn

    private static let zone = TimeZone(identifier: "America/Chicago")!

    private static func at(_ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(
            from: DateComponents(
                year: 2026, month: 7, day: 30, hour: hour, minute: minute
            )
        ) ?? .now
    }

    private static let nightMoment = at(21, 40)
    private static let dawnMoment = at(4, 35)

    private static let events = SolarDayEvents(
        fajr: at(4, 10), sunrise: at(5, 42), solarNoon: at(12, 58),
        maghrib: at(20, 11), isha: at(21, 43)
    )

    private static func model(at moment: Date) -> CompactPlate.Model {
        let times: [(Prayer, Date)] = [
            (.fajr, at(4, 10)), (.dhuhr, at(12, 58)), (.asr, at(16, 53)),
            (.maghrib, at(20, 11)), (.isha, at(21, 43))
        ]
        let current = times.last { $0.1 <= moment }?.0
        return CompactPlate.Model(
            marks: times.map { prayer, time in
                let state: PrayerMarkerState
                if prayer == current {
                    state = .current
                } else if time <= moment {
                    state = .logged
                } else {
                    state = .upcoming
                }
                return CompactPlate.Model.Mark(prayer: prayer, time: time, state: state)
            },
            sunrise: at(5, 42)
        )
    }

    private static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct LockRingSegment: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let span = 360.0 / 5.0
        let start = -90.0 + Double(index) * span + 1
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2 - 2,
            startAngle: .degrees(start),
            endAngle: .degrees(start + span - 2),
            clockwise: false
        )
        return path
    }
}

private extension SRGBValue {
    func scaled(_ k: Double) -> SRGBValue {
        SRGBValue(red: red * k, green: green * k, blue: blue * k)
    }
}
#endif
