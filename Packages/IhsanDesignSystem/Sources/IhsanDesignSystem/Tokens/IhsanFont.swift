import SwiftUI

/// Type-safe typography tokens. Screen code must NEVER use inline
/// `Font.system(size:)` literals — every font routes through this enum so
/// Dynamic Type behavior and tabular figures stay consistent.
public enum IhsanFont {
    /// Hero countdown: thin, tabular, large. The single most important text
    /// in the app — the moment of "how long until the next prayer".
    public static let heroCountdown: Font = .system(
        size: 64, weight: .thin, design: .rounded
    ).monospacedDigit()

    /// Screen title (e.g., "Trajectory", "Reflection").
    public static let title: Font = .system(
        size: 28, weight: .semibold, design: .default
    )

    /// Subsection title within a screen.
    public static let subtitle: Font = .system(
        size: 22, weight: .semibold, design: .default
    )

    /// Body English (prayer names, reflection text, etc.).
    public static let bodyEnglish: Font = .system(
        size: 17, weight: .regular, design: .default
    )

    /// Body English bold variant (active prayer name, emphasis).
    public static let bodyEnglishBold: Font = .system(
        size: 17, weight: .semibold, design: .default
    )

    /// Body Arabic. iOS 26's system font handles Arabic gracefully; bumped
    /// 2pt to match the optical scale of Latin script at 17pt.
    public static let bodyArabic: Font = .system(
        size: 19, weight: .regular, design: .default
    )

    /// Tabular numerals for prayer times, counts, durations.
    public static let tabular: Font = .system(
        size: 17, weight: .regular, design: .rounded
    ).monospacedDigit()

    /// Small caps section label ("LOCATION", "CALCULATION", etc.).
    public static let smallCaps: Font = .system(
        size: 13, weight: .semibold, design: .default
    ).smallCaps()

    /// Citation for reflection prompts (al-Ghazali, Bukhari, etc.).
    public static let citation: Font = .system(
        size: 13, weight: .regular, design: .default
    ).italic()

    /// Tab bar label.
    public static let tabBar: Font = .system(
        size: 10, weight: .medium, design: .default
    )

    // MARK: - Manuscript serif variants
    //
    // Today screen uses the system serif (New York on iOS 26) for prayer
    // names, hero countdown labels, and major page headings — the serif
    // honors the illuminated-manuscript reference. Body text and tabular
    // numerals continue to use SF Pro / SF Rounded so legibility is not
    // compromised.

    /// Refined serif at hero scale — prayer name above the countdown.
    public static let heroPrayerName: Font = .system(
        size: 24, weight: .medium, design: .serif
    )

    /// Refined serif at body scale — prayer name in list rows.
    public static let rowPrayerName: Font = .system(
        size: 18, weight: .semibold, design: .serif
    )

    /// Small caps inscription — page header location, "UNTIL ASR", section
    /// labels in the manuscript aesthetic. Letter-spaced via `.tracking()`
    /// at the call site so each surface can tune the spacing for its scale.
    public static let inscription: Font = .system(
        size: 13, weight: .semibold, design: .default
    ).smallCaps()

    /// Larger inscriptional small caps — for the location label in the
    /// page header.
    public static let inscriptionLarge: Font = .system(
        size: 15, weight: .semibold, design: .default
    ).smallCaps()
}
