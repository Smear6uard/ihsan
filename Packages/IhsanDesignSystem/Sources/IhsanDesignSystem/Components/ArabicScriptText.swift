import SwiftUI

/// Vocalised Arabic, set properly.
///
/// Four things this does that a bare `Text` does not:
///
/// 1. **Right-to-left.** The block lays out RTL inside an app that is
///    otherwise LTR, so wrapped lines break in the reading order and
///    trailing punctuation lands on the correct side.
/// 2. **Leading for tashkeel.** Extra line spacing from
///    `IhsanArabicType`, scaled with Dynamic Type, so stacked marks
///    never touch the line above.
/// 3. **Language.** The string carries `languageIdentifier = "ar"`, so
///    VoiceOver speaks it as Arabic instead of spelling it at an
///    English voice.
/// 4. **No clipping.** Never given a fixed height, and it insets itself
///    vertically by a fraction of its own point size, because tashkeel
///    puts ink outside the font's own line box.
public struct ArabicScriptText: View {
    private let text: String
    private let register: IhsanArabicRegister
    private let color: Color
    private let alignment: TextAlignment

    /// Tracks the same growth `Font.system(size:)` applies, so leading
    /// and inset stay proportional at every Dynamic Type size right up
    /// to accessibility5.
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    public init(
        _ text: String,
        register: IhsanArabicRegister,
        color: Color,
        alignment: TextAlignment = .center
    ) {
        self.text = text
        self.register = register
        self.color = color
        self.alignment = alignment
    }

    /// The register chosen from the text's own length.
    public init(
        reading text: String,
        color: Color,
        alignment: TextAlignment = .center
    ) {
        self.init(
            text,
            register: .forReading(text),
            color: color,
            alignment: alignment
        )
    }

    private var pointSize: CGFloat { register.baseSize * typeScale }

    public var body: some View {
        Text(spoken)
            .font(IhsanArabicType.font(register))
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .lineSpacing(IhsanArabicType.lineSpacing(forPointSize: pointSize))
            .padding(.vertical, IhsanArabicType.verticalInset(forPointSize: pointSize))
            .frame(maxWidth: .infinity)
            .environment(\.layoutDirection, .rightToLeft)
            .accessibilityLabel(Text(spoken))
    }

    /// The text tagged as Arabic. VoiceOver reads the tag and switches
    /// voice; without it an Arabic string at an English voice is
    /// unintelligible, which for a text someone is trying to say is
    /// the whole feature failing.
    private var spoken: AttributedString {
        var attributed = AttributedString(text)
        attributed.languageIdentifier = "ar"
        return attributed
    }
}

/// The pronunciation aid beneath the Arabic.
///
/// Hidden from VoiceOver on purpose: a screen-reader user has just
/// heard the line in Arabic, and hearing an English voice work through
/// "Subḥāna'llāhi wa bi-ḥamdih" immediately afterwards is noise, not
/// help. The information it carries is already spoken by the Arabic
/// above it.
public struct TransliterationText: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(IhsanFont.transliteration)
            .tracking(0.2)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

/// The translation, in the reader's own language and voice.
public struct TranslationText: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(IhsanFont.bodyEnglish)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .frame(maxWidth: .infinity)
    }
}
