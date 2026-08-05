import IhsanCore
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Small (2×2): one illuminated initial.
///
/// A manuscript opens a chapter with a single illuminated letter; the
/// small widget opens the day's next hour the same way — one ornament,
/// one large numeral, the name in both scripts, and a quiet relative
/// line. Nothing else earns the inch.
public struct NextPrayerFace: View {
    public let model: WidgetDayModel
    public let tokens: SkyPaletteTokens
    public let mode: WidgetFaceMode
    /// StandBy caps ink so gold does not glare in a dark bedroom.
    public var usesStandByInk: Bool

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

    private var ink: Color {
        usesStandByInk ? tokens.standByInk : tokens.ink
    }
    private var inkSecondary: Color {
        usesStandByInk ? tokens.standByInkSecondary : tokens.inkSecondary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                PrayerMarkerOrnament(
                    prayer: model.nextPrayer,
                    size: 30,
                    state: model.currentPrayer == model.nextPrayer ? .current : .upcoming,
                    tokens: tokens
                )
                .widgetFaceAccent(mode)

                Spacer(minLength: IhsanSpacing.xs)

                if let city = model.cityName {
                    Text(city.uppercased())
                        .font(IhsanFont.inscription)
                        .tracking(0.8)
                        .foregroundStyle(faceSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: IhsanSpacing.xxs)

            Text(model.clock(model.nextTime))
                .font(.system(size: 32, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(facePrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetFaceAccent(mode)

            HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.xs) {
                Text(model.nextPrayer.displayNameEnglish)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(facePrimary)
                Text(model.nextPrayer.displayNameArabic)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(faceSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .widgetFaceAccent(mode)

            Text("in \(Text(timerInterval: model.countdown, countsDown: true))")
                .font(.system(size: 12, weight: .regular, design: .rounded).monospacedDigit())
                .foregroundStyle(faceSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(model.nextPrayer.displayNameEnglish) at \(model.clock(model.nextTime))"
        )
    }

    private var facePrimary: some ShapeStyle {
        mode == .accented ? AnyShapeStyle(.primary) : AnyShapeStyle(ink)
    }
    private var faceSecondary: some ShapeStyle {
        mode == .accented ? AnyShapeStyle(.secondary) : AnyShapeStyle(inkSecondary)
    }
}

extension View {
    /// In accented (tinted/clear) rendering, this view is part of the
    /// accent group — ornaments and primary figures; grounds and
    /// secondary text stay material. In full colour it is inert.
    @ViewBuilder
    func widgetFaceAccent(_ mode: WidgetFaceMode) -> some View {
        #if canImport(WidgetKit)
        self.widgetAccentable(mode == .accented)
        #else
        self
        #endif
    }
}
