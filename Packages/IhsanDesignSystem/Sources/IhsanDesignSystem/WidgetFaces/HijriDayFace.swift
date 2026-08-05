import IhsanCore
import SwiftUI

/// Small (2×2): the Hijri day as an inscription plate.
///
/// A date carved the way a manuscript colophon carves one: the day
/// numeral is the illumination, the month and year stand over it in
/// the inscription register, and a significant day (a white day,
/// Ramadan) gets its line at the base. No Gregorian date appears —
/// the phone already says that everywhere else.
public struct HijriDayFace: View {
    public let hijri: WidgetHijriModel
    public let tokens: SkyPaletteTokens
    public let mode: WidgetFaceMode
    public var usesStandByInk: Bool

    public init(
        hijri: WidgetHijriModel,
        tokens: SkyPaletteTokens,
        mode: WidgetFaceMode = .fullColor,
        usesStandByInk: Bool = false
    ) {
        self.hijri = hijri
        self.tokens = tokens
        self.mode = mode
        self.usesStandByInk = usesStandByInk
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(hijri.monthName) · \(yearText) AH".uppercased())
                .font(IhsanFont.inscription)
                .tracking(1.2)
                .foregroundStyle(faceSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Spacer(minLength: 0)

            Text("\(hijri.day)")
                .font(.system(size: 64, weight: .regular, design: .serif))
                .foregroundStyle(facePrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetFaceAccent(mode)

            Spacer(minLength: 0)

            if let line = hijri.significantLine {
                Text(line.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(0.8)
                    .foregroundStyle(mode == .accented ? AnyShapeStyle(.secondary) : AnyShapeStyle(tokens.metal))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text(hijri.monthName)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(faceSecondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// Years are figures, not quantities — "1448", never "1,448".
    private var yearText: String {
        String(hijri.year)
    }

    private var accessibilityText: String {
        var text = "\(hijri.monthName) \(hijri.day), \(yearText) hijri"
        if let line = hijri.significantLine {
            text += ". \(line)"
        }
        return text
    }

    private var facePrimary: some ShapeStyle {
        mode == .accented
            ? AnyShapeStyle(.primary)
            : AnyShapeStyle(usesStandByInk ? tokens.standByInk : tokens.ink)
    }
    private var faceSecondary: some ShapeStyle {
        mode == .accented
            ? AnyShapeStyle(.secondary)
            : AnyShapeStyle(usesStandByInk ? tokens.standByInkSecondary : tokens.inkSecondary)
    }
}
