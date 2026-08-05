import CoreText
import Foundation
import IhsanCore
import Testing
@testable import IhsanDesignSystem

/// Arabic leading, measured rather than asserted.
///
/// The claim the design makes is that stacked tashkeel never touches
/// the line above it. That claim is a number —
/// `IhsanArabicType.tashkeelLineSpacingRatio` — and a number is worth
/// nothing unless something checks it against real glyph ink. These
/// tests shape every Arabic string the app ships through CoreText with
/// the same system Arabic face the app asks for, take the true glyph
/// path bounds, and compare them to the line box the design gives each
/// line.
///
/// Limitation, stated rather than hidden: this runs on macOS, so it
/// measures the desktop build of SF Arabic. The iOS face is the same
/// design but the tests cannot prove the shipped metrics byte for
/// byte. The device check stays on the maintainer's list — this is the
/// floor, not the ceiling.
@Suite("Arabic typography")
struct ArabicTypographyTests {

    /// The system Arabic face at a given size — what
    /// `Font.system(size:design:.default)` resolves to for Arabic text.
    private func arabicFont(size: CGFloat) -> CTFont {
        CTFontCreateUIFontForLanguage(.system, size, "ar" as CFString)
            ?? CTFontCreateWithName("Geeza Pro" as CFString, size, nil)
    }

    private func line(_ text: String, font: CTFont) -> CTLine {
        let attributed = NSAttributedString(
            string: text,
            attributes: [kCTFontAttributeName as NSAttributedString.Key: font]
        )
        return CTLineCreateWithAttributedString(attributed)
    }

    /// True glyph ink height, including every mark above and below.
    private func inkHeight(_ text: String, font: CTFont) -> CGFloat {
        let bounds = CTLineGetBoundsWithOptions(
            line(text, font: font), .useGlyphPathBounds
        )
        return bounds.height
    }

    /// The box one line of text occupies once the design's leading is
    /// added: the face's own ascent + descent + leading, plus our extra
    /// line spacing.
    private func lineBox(font: CTFont, pointSize: CGFloat) -> CGFloat {
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let leading = CTFontGetLeading(font)
        return ascent + descent + leading
            + IhsanArabicType.lineSpacing(forPointSize: pointSize)
    }

    private var items: [AdhkarItem] {
        BundledAdhkar.content?.items ?? []
    }

    @Test("There is Arabic to measure")
    func contentIsPresent() {
        #expect(!items.isEmpty)
    }

    /// The load-bearing measurement. For every shipped text, at the
    /// register it will actually be read in, the tallest ink must fit
    /// inside the line box — otherwise the marks of one line reach into
    /// the line above and a reader following the ḥarakāt loses which
    /// mark belongs to which letter.
    @Test("Stacked tashkeel clears the line above at every reading register")
    func stackedTashkeelClearsTheLineAbove() {
        for item in items {
            let register = IhsanArabicRegister.forReading(item.arabic)
            let size = register.baseSize
            let font = arabicFont(size: size)
            let ink = inkHeight(item.arabic, font: font)
            let box = lineBox(font: font, pointSize: size)

            #expect(
                ink <= box,
                "\(item.id): ink \(ink) exceeds the \(box) line box at \(register)"
            )
        }
    }

    /// The same check at the accessibility sizes the rule requires the
    /// text to reach. Dynamic Type scales the point size, and both the
    /// ink and the line box scale with it — this pins that the
    /// relationship is linear and does not degrade, so nothing new
    /// appears at accessibility5 that was fine at default.
    @Test("The clearance holds all the way to accessibility5 scale")
    func clearanceHoldsAtAccessibilitySizes() {
        // Approximate multipliers for xSmall … accessibility5 relative
        // to the default body size.
        let scales: [CGFloat] = [0.82, 1.0, 1.35, 1.8, 2.35, 3.1, 3.6]

        for item in items {
            let register = IhsanArabicRegister.forReading(item.arabic)
            for scale in scales {
                let size = register.baseSize * scale
                let font = arabicFont(size: size)
                #expect(
                    inkHeight(item.arabic, font: font) <= lineBox(font: font, pointSize: size),
                    "\(item.id) at scale \(scale)"
                )
            }
        }
    }

    /// Real margin, not a hairline pass: if the densest item only just
    /// fits, the next one transcribed will not. Measured on the exact
    /// specimen the gallery shows the maintainer, so the arithmetic
    /// gate and the eye gate look at the same text.
    @Test("The densest item keeps headroom inside its line box")
    func densestItemKeepsHeadroom() throws {
        let densest = try #require(AdhkarTypeSpecimens.densest)
        let register = IhsanArabicRegister.forReading(densest.arabic)
        let size = register.baseSize
        let font = arabicFont(size: size)
        let ratio = inkHeight(densest.arabic, font: font) / lineBox(font: font, pointSize: size)

        #expect(ratio <= 0.92, "densest item \(densest.id) fills \(ratio) of its line box")
    }

    /// The gallery's specimens are the hard cases, not three arbitrary
    /// items: the densest one wraps (so it has a line above to collide
    /// with), and the three are distinct.
    @Test("The gallery shows the cases worth looking at")
    func gallerySpecimensAreTheHardCases() throws {
        let densest = try #require(AdhkarTypeSpecimens.densest)
        let longest = try #require(AdhkarTypeSpecimens.longest)
        let shortest = try #require(AdhkarTypeSpecimens.shortest)

        #expect(
            IhsanArabicRegister.forReading(densest.arabic) != .scripture,
            "the densest specimen \(densest.id) fits on one line and can collide with nothing"
        )
        #expect(AdhkarTypeSpecimens.stackDensity(densest.arabic) > 0)
        #expect(longest.arabic.count > shortest.arabic.count)
    }

    // MARK: - Registers

    @Test("Each length band lands in its own reading register")
    func registersFollowLength() throws {
        let content = try #require(BundledAdhkar.content)

        func register(_ id: String) throws -> IhsanArabicRegister {
            let item = try #require(content.items.first { $0.id == id })
            return .forReading(item.arabic)
        }

        // A three-word tasbīḥ reads at the largest scale.
        #expect(try register("postPrayer.subhanallah") == .scripture)
        // A medium duʿāʾ steps down once.
        #expect(try register("evening.sayyid-al-istighfar") == .passage)
        // The long passages step down twice.
        #expect(try register("morning.ayat-al-kursi") == .recitation)
        #expect(try register("sleep.khawatim-al-baqarah") == .recitation)
    }

    // MARK: - Fit

    /// A phone's reading column, and the height the reader surface can
    /// give the text before the ring is pushed off the screen — the
    /// smallest current iPhone width, minus the surface's horizontal
    /// padding.
    private static let readingWidth: CGFloat = 354
    private static let readingHeightBudget: CGFloat = 480

    /// Typeset every shipped item at its own register, with the
    /// design's leading, into a phone-width column, and measure what
    /// comes out. This is the property the three registers exist for:
    /// the longest passage has to fit the reading area at default
    /// Dynamic Type, and the shortest duʿāʾ has to still be set large.
    @Test("Every item fits the reading column at its register")
    func everyItemFitsTheReadingArea() {
        for item in items {
            let register = IhsanArabicRegister.forReading(item.arabic)
            let height = typesetHeight(item.arabic, register: register)
            #expect(
                height <= Self.readingHeightBudget,
                "\(item.id) typesets to \(height)pt at \(register) — past the \(Self.readingHeightBudget)pt reading area"
            )
        }
    }

    /// Nothing drops to caption scale. The smallest reading register
    /// still sits above the app's own Arabic body size, so the longest
    /// passage is never set smaller than a prayer name in a row.
    @Test("No reading register falls below the app's inline Arabic size")
    func readingRegistersStayLarge() {
        for register in [IhsanArabicRegister.scripture, .passage, .recitation] {
            #expect(register.baseSize > IhsanArabicType.inlineSize)
        }
    }

    private func typesetHeight(_ text: String, register: IhsanArabicRegister) -> CGFloat {
        let size = register.baseSize
        // CoreText's own paragraph style rather than AppKit's, so the
        // measurement is the same code on every platform the package
        // builds for.
        var lineSpacing = IhsanArabicType.lineSpacing(forPointSize: size)
        var alignment = CTTextAlignment.center
        var direction = CTWritingDirection.rightToLeft
        let paragraph = withUnsafeBytes(of: &lineSpacing) { spacingBuffer in
            withUnsafeBytes(of: &alignment) { alignmentBuffer in
                withUnsafeBytes(of: &direction) { directionBuffer in
                    let settings = [
                        CTParagraphStyleSetting(
                            spec: .lineSpacingAdjustment,
                            valueSize: MemoryLayout<CGFloat>.size,
                            value: spacingBuffer.baseAddress!
                        ),
                        CTParagraphStyleSetting(
                            spec: .alignment,
                            valueSize: MemoryLayout<CTTextAlignment>.size,
                            value: alignmentBuffer.baseAddress!
                        ),
                        CTParagraphStyleSetting(
                            spec: .baseWritingDirection,
                            valueSize: MemoryLayout<CTWritingDirection>.size,
                            value: directionBuffer.baseAddress!
                        )
                    ]
                    return CTParagraphStyleCreate(settings, settings.count)
                }
            }
        }

        let attributed = NSAttributedString(
            string: text,
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key: arabicFont(size: size),
                kCTParagraphStyleAttributeName as NSAttributedString.Key: paragraph
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: Self.readingWidth, height: .greatestFiniteMagnitude),
            nil
        )
        // The block also insets itself top and bottom.
        return suggested.height + 2 * IhsanArabicType.verticalInset(forPointSize: size)
    }

    @Test("Leading and inset grow with the point size")
    func metricsAreProportional() {
        #expect(
            IhsanArabicType.lineSpacing(forPointSize: 60)
                == 2 * IhsanArabicType.lineSpacing(forPointSize: 30)
        )
        #expect(IhsanArabicType.verticalInset(forPointSize: 30) > 0)
        #expect(IhsanArabicType.scriptureSize > IhsanArabicType.passageSize)
        #expect(IhsanArabicType.passageSize > IhsanArabicType.recitationSize)
        #expect(IhsanArabicType.recitationSize > IhsanArabicType.inlineSize)
    }
}

/// The colour registers the remembrance surfaces read in, checked
/// against every SkyPhase.
///
/// This suite exists because of a real near-miss: `metal` is the
/// obvious choice for a quiet secondary line — it is the app's
/// inscription colour — and it measures 3.20:1 on the morning panel
/// and 2.84:1 on the afternoon one. Beautiful, and unreadable to
/// anyone who needs contrast. `inkSecondary` is the only secondary
/// token that holds AA on all six grounds, so it carries every
/// quiet line here and `metal` carries none of them.
@Suite("Adhkar reading registers · contrast")
struct AdhkarRegisterContrastTests {

    /// Every surface a remembrance line can be set on.
    private func surfaces(_ tokens: SkyPaletteTokens) -> [(String, SRGBValue)] {
        [
            ("panelFill", tokens.panelFillValue),
            ("groundTop", tokens.groundTopValue),
            ("groundBottom", tokens.groundBottomValue)
        ]
    }

    /// Arabic and translation are body reading — the app's 7:1 bar,
    /// not the 4.5:1 floor.
    @Test("Arabic and translation hold body contrast everywhere")
    func primaryTextHoldsBodyContrast() {
        for state in PaletteState.allCases {
            let tokens = state.tokens
            for (name, surface) in surfaces(tokens) {
                let ratio = tokens.inkValue.contrastRatio(against: surface)
                #expect(ratio >= 7.0, "\(state) ink on \(name) is \(ratio)")
            }
        }
    }

    /// Transliteration and citation are secondary — AA.
    @Test("Transliteration and citation hold AA everywhere")
    func secondaryTextHoldsAA() {
        for state in PaletteState.allCases {
            let tokens = state.tokens
            for (name, surface) in surfaces(tokens) {
                let ratio = tokens.inkSecondaryValue.contrastRatio(against: surface)
                #expect(ratio >= 4.5, "\(state) inkSecondary on \(name) is \(ratio)")
            }
        }
    }

    /// The near-miss, pinned. If `metal` ever becomes readable on the
    /// day grounds this test fails and someone gets to reconsider —
    /// until then it is a mark colour, never a text colour.
    @Test("Metal is not a text colour on the day grounds")
    func metalIsAMarkColourOnly() {
        let day = [PaletteState.firstLight, .morning, .afternoon]
        for state in day {
            let tokens = state.tokens
            let ratio = tokens.metalValue.contrastRatio(against: tokens.panelFillValue)
            #expect(
                ratio < 4.5,
                "metal now measures \(ratio) on the \(state) panel — reconsider the register assignment deliberately"
            )
        }
    }
}
