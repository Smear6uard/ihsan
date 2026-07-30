import Foundation

/// The app's one romanization of recurring Arabic terms.
///
/// Every user-facing surface — card chip, sheet toggle, Path stats,
/// watch controls, Siri phrases — reads these constants instead of
/// spelling the word locally, so the transliteration can never drift
/// between surfaces again. The canonical form uses the macron ā
/// (U+0101) and the ʿayn half-ring ʿ (U+02BF): "jamāʿah".
public enum IhsanVocabulary {
    /// Lowercase, mid-sentence: "prayed in jamāʿah".
    public static let jamaah = "jamāʿah"
    /// Title case, labels and toggles: "Jamāʿah".
    public static let jamaahTitle = "Jamāʿah"
    /// Small-caps inscription register: "JAMĀʿAH". (ʿ has no
    /// uppercase form; the half-ring rides the capitals unchanged.)
    public static let jamaahInscription = "JAMĀʿAH"
    /// The sheet toggle's title: "In Jamāʿah".
    public static let inJamaahTitle = "In Jamāʿah"
}
