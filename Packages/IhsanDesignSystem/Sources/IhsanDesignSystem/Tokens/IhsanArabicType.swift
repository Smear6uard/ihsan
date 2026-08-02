import CoreGraphics
import SwiftUI

/// Arabic typography — the register substantial vocalised Arabic is set
/// in.
///
/// **The face.** The system Arabic face (SF Arabic), reached through
/// `Font.system`. It was evaluated against what iOS 26 actually ships:
/// SF Arabic and Geeza Pro are always present; Mishafi, Damascus, Al
/// Nile and Farah are optional app fonts. SF Arabic wins on the only
/// thing that matters here — mark positioning. Stacked tashkeel
/// (shadda over a vowel, tanwīn over a preceding kasra) is placed by
/// the face's own GPOS mark-attachment rules, and SF Arabic's are the
/// most carefully drawn of the set. It also scales with Dynamic Type
/// for free, which a bundled face would not. Nothing is bundled.
///
/// `design: .default` is stated explicitly rather than inherited: the
/// app's manuscript register uses `.serif` (New York) for English
/// display type, and New York carries no Arabic. Asking for `.serif`
/// on Arabic would silently fall back to SF Arabic anyway — better to
/// say what is meant.
///
/// **The leading.** Full tashkeel puts ink far above the ascender and
/// far below the baseline. At default leading the marks of one line
/// touch the descenders of the line above, which for a vocalised text
/// is not an aesthetic problem — it is a legibility problem, because
/// a reader following the ḥarakāt loses which mark belongs to which
/// letter. `tashkeelLineSpacingRatio` is the extra leading that keeps
/// them apart, and `ArabicTypographyTests` measures real glyph ink
/// against it rather than trusting the number.
public enum IhsanArabicType {

    // MARK: - Sizes
    //
    // Three reading scales, not one, because the shipped texts run
    // from fourteen scalars (بِسْمِ اللَّهِ) to six hundred and sixty-three
    // (the closing verses of al-Baqarah) — a forty-seven-fold range
    // that no single size serves. The thresholds below were set from
    // the actual distribution in the content file, and
    // `ArabicTypographyTests` typesets every item to prove each one
    // still fits a phone's reading area at its chosen scale.

    /// A short duʿāʾ, held as a single line of speech. The largest
    /// scale: this is the text the person is saying, not a caption on
    /// something else.
    public static let scriptureSize: CGFloat = 32

    /// A medium duʿāʾ — Sayyid al-Istighfār, the fiṭrah remembrance.
    public static let passageSize: CGFloat = 25

    /// A long passage — Āyat al-Kursī, the closing verses of
    /// al-Baqarah, the long post-prayer formula. Still well above the
    /// app's body size; nothing here drops to caption scale.
    public static let recitationSize: CGFloat = 21

    /// A word or short phrase inside a row of other content.
    public static let inlineSize: CGFloat = 19

    /// Upper bound, in Arabic scalars, for the scripture scale.
    public static let passageThreshold = 150

    /// Upper bound, in Arabic scalars, for the passage scale.
    public static let recitationThreshold = 340

    // MARK: - Leading

    /// Extra leading as a multiple of the point size. 0.62 puts the
    /// effective line height at roughly 1.8× — measured, not guessed:
    /// see `ArabicTypographyTests.stackedTashkeelClearsTheLineAbove`.
    public static let tashkeelLineSpacingRatio: CGFloat = 0.62

    /// Vertical breathing room a vocalised Arabic block owes its
    /// container, so the topmost mark of the first line and the lowest
    /// of the last are never flush against an edge or a keyline.
    public static let verticalInsetRatio: CGFloat = 0.28

    public static func lineSpacing(forPointSize size: CGFloat) -> CGFloat {
        size * tashkeelLineSpacingRatio
    }

    public static func verticalInset(forPointSize size: CGFloat) -> CGFloat {
        size * verticalInsetRatio
    }

    // MARK: - Fonts

    public static func font(_ register: IhsanArabicRegister) -> Font {
        .system(size: register.baseSize, weight: .regular, design: .default)
    }
}

/// The scale an Arabic block is set at.
public enum IhsanArabicRegister: Sendable, Equatable, Hashable, CaseIterable {
    case scripture
    case passage
    case recitation
    case inline

    public var baseSize: CGFloat {
        switch self {
        case .scripture: IhsanArabicType.scriptureSize
        case .passage: IhsanArabicType.passageSize
        case .recitation: IhsanArabicType.recitationSize
        case .inline: IhsanArabicType.inlineSize
        }
    }

    /// Pick the reading register for a text by its length. A pure
    /// function of the content, so the same item always reads at the
    /// same scale on every surface it appears on.
    public static func forReading(_ text: String) -> IhsanArabicRegister {
        switch text.unicodeScalars.count {
        case ...IhsanArabicType.passageThreshold: .scripture
        case ...IhsanArabicType.recitationThreshold: .passage
        default: .recitation
        }
    }
}
