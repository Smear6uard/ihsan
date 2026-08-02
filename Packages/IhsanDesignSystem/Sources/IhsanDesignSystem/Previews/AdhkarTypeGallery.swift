import IhsanCore
import SwiftUI

// The Arabic typography gate.
//
// This page exists to be looked at on a device, at arm's length, the
// same way every other surface in this app is judged. It shows the
// hardest cases the content file actually contains — the item with the
// most marks per letter, and the longest passage — at three Dynamic
// Type sizes, on the day ground and the night ground. If tashkeel
// clips, collides, or greys out on any of these, the tokens are wrong
// and no screen may be built on them.
//
// `ArabicTypographyTests` measures the same texts with CoreText. That
// catches collision arithmetic; it cannot catch how the page reads.
// Both gates are needed.

/// The one specimen: Arabic, transliteration, translation, source —
/// the exact stack the reading surface uses.
public struct AdhkarTypeSpecimen: View {
    private let item: AdhkarItem
    private let tokens: SkyPaletteTokens
    private let showsTransliteration: Bool

    public init(
        item: AdhkarItem,
        tokens: SkyPaletteTokens,
        showsTransliteration: Bool = true
    ) {
        self.item = item
        self.tokens = tokens
        self.showsTransliteration = showsTransliteration
    }

    public var body: some View {
        VStack(spacing: IhsanSpacing.sm) {
            ArabicScriptText(reading: item.arabic, color: tokens.ink)

            if showsTransliteration {
                TransliterationText(item.transliteration, color: tokens.inkSecondary)
            }

            TranslationText(item.translation, color: tokens.ink)

            Text(item.source.citation)
                .font(IhsanFont.citation)
                .foregroundStyle(tokens.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(IhsanSpacing.md)
        .celestialPanel(tokens: tokens, cornerRadius: IhsanSpacing.smallCardRadius)
    }
}

/// Which texts the gate looks at, and why.
///
/// Deliberately not a member of the gallery view: choosing the hard
/// cases is a fact about the content, and the tests that measure those
/// same texts must be able to ask for them without touching the main
/// actor.
public enum AdhkarTypeSpecimens {

    /// Combining marks that sit above or below a base letter.
    public static let combiningMarks = CharacterSet(charactersIn: "\u{064B}"..."\u{0652}")
        .union(CharacterSet(charactersIn: "\u{0670}"))

    /// How often two marks land on one base letter, per character. This
    /// is the quantity that decides whether ink escapes the line box:
    /// a shadda with a vowel over it, or a vowel under a superscript
    /// alif, reaches much further than either mark alone.
    public static func stackDensity(_ text: String) -> Double {
        var stacks = 0
        var run = 0
        for scalar in text.unicodeScalars {
            if combiningMarks.contains(scalar) {
                run += 1
                if run == 2 { stacks += 1 }
            } else {
                run = 0
            }
        }
        return Double(stacks) / Double(max(text.unicodeScalars.count, 1))
    }

    /// The collision case: the most stacked marks per character among
    /// items long enough to wrap. Only a text that wraps has a line
    /// above to collide with, and marks-per-character alone picks a
    /// three-word tasbīḥ, which proves nothing.
    public static var densest: AdhkarItem? {
        BundledAdhkar.content?.items
            .filter { IhsanArabicRegister.forReading($0.arabic) != .scripture }
            .max { stackDensity($0.arabic) < stackDensity($1.arabic) }
    }

    /// The reading-area case.
    public static var longest: AdhkarItem? {
        BundledAdhkar.content?.items.max { $0.arabic.count < $1.arabic.count }
    }

    /// Proof the largest register does not look stranded on three
    /// words.
    public static var shortest: AdhkarItem? {
        BundledAdhkar.content?.items.min { $0.arabic.count < $1.arabic.count }
    }

    /// The three, labelled and de-duplicated — one item can be both the
    /// longest and the densest, and showing it twice teaches nothing.
    public static var labelled: [(label: String, item: AdhkarItem)] {
        var chosen: [(label: String, item: AdhkarItem)] = []
        var seen = Set<String>()
        for (label, candidate) in [
            ("DENSEST STACKED TASHKEEL", densest),
            ("LONGEST PASSAGE", longest),
            ("SHORTEST ITEM", shortest)
        ] {
            guard let candidate, seen.insert(candidate.id).inserted else { continue }
            chosen.append((label: label, item: candidate))
        }
        return chosen
    }
}

/// The gallery page itself — the three hard cases on one ground, at
/// whatever Dynamic Type size the device is set to.
///
/// The size is AMBIENT on purpose. An earlier version overrode
/// `\.dynamicTypeSize` per section so one screenshot could show three
/// sizes at once — and the override moved `@ScaledMetric` (the leading)
/// while leaving `Font.system(size:)` at its default size, which made
/// the page a convincing picture of something that never happens. The
/// gate now shows exactly what the device is set to, and the reviewer
/// changes the size in Settings like any other person would.
public struct AdhkarTypeGallery: View {
    private let state: PaletteState

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(state: PaletteState = .morning) {
        self.state = state
    }

    private var specimens: [(label: String, item: AdhkarItem)] {
        AdhkarTypeSpecimens.labelled
    }

    public var body: some View {
        let tokens = PaletteState.resolved(for: SkyPhase.fixed(state))

        ZStack {
            tokens.groundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ARABIC TYPE · \(state.displayName.uppercased())")
                            .font(IhsanFont.inscription)
                            .tracking(2.0)
                            .foregroundStyle(tokens.inkSecondary)
                        Text("TYPE SIZE · \(sizeLabel)")
                            .font(IhsanFont.inscription)
                            .tracking(1.4)
                            .foregroundStyle(tokens.inkSecondary)
                    }

                    ForEach(specimens, id: \.label) { specimen in
                        VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                            Text(specimen.label)
                                .font(IhsanFont.inscription)
                                .tracking(1.2)
                                .foregroundStyle(tokens.inkSecondary)
                            AdhkarTypeSpecimen(item: specimen.item, tokens: tokens)
                        }
                        OrnamentalDivider(tint: tokens.metal, opacity: 0.4)
                    }
                }
                .padding(IhsanSpacing.md)
            }
        }
    }

    private var sizeLabel: String {
        switch dynamicTypeSize {
        case .xSmall: "X SMALL"
        case .small: "SMALL"
        case .medium: "MEDIUM"
        case .large: "LARGE (DEFAULT)"
        case .xLarge: "X LARGE"
        case .xxLarge: "XX LARGE"
        case .xxxLarge: "XXX LARGE"
        case .accessibility1: "ACCESSIBILITY 1"
        case .accessibility2: "ACCESSIBILITY 2"
        case .accessibility3: "ACCESSIBILITY 3"
        case .accessibility4: "ACCESSIBILITY 4"
        case .accessibility5: "ACCESSIBILITY 5"
        @unknown default: "UNKNOWN"
        }
    }
}

#Preview("Arabic type · morning ground") {
    AdhkarTypeGallery(state: .morning)
}

#Preview("Arabic type · night ground") {
    AdhkarTypeGallery(state: .night)
}

#Preview("Arabic type · dawn ground") {
    AdhkarTypeGallery(state: .dawn)
}

#Preview("Arabic type · sunset ground") {
    AdhkarTypeGallery(state: .sunset)
}
