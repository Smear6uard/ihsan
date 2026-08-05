import Foundation
import Testing

/// The Dynamic Type rule, enforced against the sources.
///
/// Display serifs — a page title — may cap: a title is decoration for
/// the eye that already knows where it is. Everything else may not.
/// Dates, values, ledger numbers, settings rows, inscriptions carrying
/// information: all of it scales the whole way to accessibility5, or
/// someone who needs that size cannot use the app.
///
/// The rule is broken by adding one modifier, and nothing about it
/// fails at runtime — the text simply stops growing for the people who
/// needed it to. So the sources are read.
@Suite("The Dynamic Type rule")
struct DynamicTypeRuleTests {

    /// Symlinks resolved on BOTH sides of the prefix strip in
    /// `relative(_:)` — see the note on `HapticVocabularyTests`. In a
    /// checkout under a symlinked path the strip never anchors and the
    /// sweep fails wholesale on mangled `/privateihsan/…` paths.
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// The two places a cap is defensible, each with its reason.
    ///
    /// Both are data matrices: a grid of dots or a month of days
    /// cannot reflow per-glyph, and growing the type past a point
    /// breaks the grid rather than helping anyone read it. Both carry
    /// the same information to VoiceOver in full, and both open a
    /// breakdown that scales the whole way.
    private static let matrixExemptions: Set<String> = [
        "ihsan/Trajectory/Components/DailyPracticeGrid.swift",
        "ihsan/Today/Components/HijriMonthSheet.swift"
    ]

    private func swiftFiles(under root: String) -> [URL] {
        let base = repoRoot.appending(path: root)
        guard let walker = FileManager.default.enumerator(
            at: base, includingPropertiesForKeys: nil
        ) else { return [] }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    private func relative(_ url: URL) -> String {
        url.resolvingSymlinksInPath().path
            .replacingOccurrences(of: repoRoot.path + "/", with: "")
    }

    @Test("Nothing caps Dynamic Type except the two data matrices")
    func typeIsNotCapped() {
        for root in ["ihsan", "Packages/IhsanDesignSystem/Sources"] {
            for url in swiftFiles(under: root) {
                let path = relative(url)
                guard !Self.matrixExemptions.contains(path) else { continue }
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""

                if text.contains(".dynamicTypeSize(...") {
                    Issue.record("\(path) caps Dynamic Type; functional text must scale to accessibility5, and a cap needs a documented exemption")
                }
            }
        }
    }

    /// `minimumScaleFactor` shrinks text instead of wrapping it. Below
    /// about 0.6 the result is unreadable at the sizes it kicks in at —
    /// which is precisely the sizes someone chose accessibility5 for.
    @Test("Nothing shrinks text below the readable floor")
    func textIsNotShrunkIntoIllegibility() {
        let floor = 0.6

        for root in ["ihsan", "Packages/IhsanDesignSystem/Sources"] {
            for url in swiftFiles(under: root) {
                let path = relative(url)
                guard !Self.matrixExemptions.contains(path) else { continue }
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""

                for line in text.split(separator: "\n") {
                    guard line.contains("minimumScaleFactor(") else { continue }
                    guard
                        let open = line.range(of: "minimumScaleFactor("),
                        let close = line[open.upperBound...].firstIndex(of: ")"),
                        let value = Double(line[open.upperBound..<close])
                    else { continue }

                    if value < floor {
                        Issue.record("\(path) shrinks text to \(value); below \(floor) it stops being readable at the sizes it applies to")
                    }
                }
            }
        }
    }

    /// Fixed-pixel fonts do not respond to Dynamic Type at all.
    /// SwiftUI's `Font.system(size:)` does; a `UIFont` bridged into one
    /// does not, and is the way this rule gets broken invisibly.
    @Test("No text is drawn with a bridged UIFont")
    func nothingBridgesAFixedUIFont() {
        for root in ["ihsan", "Packages/IhsanDesignSystem/Sources"] {
            for url in swiftFiles(under: root) {
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                if text.contains("Font(UIFont") || text.contains("UIFont.systemFont(ofSize") {
                    Issue.record("\(relative(url)) bridges a fixed UIFont, which never scales")
                }
            }
        }
    }

    @Test("Every exemption still exists and still says why")
    func exemptionsAreLive() throws {
        for path in Self.matrixExemptions {
            let text = try String(
                contentsOf: repoRoot.appending(path: path), encoding: .utf8
            )
            let caps = text.contains(".dynamicTypeSize(...")
                || text.contains("minimumScaleFactor(")
            #expect(
                caps,
                "\(path) no longer caps anything — drop it from the exemptions."
            )
            let explains = text.lowercased().contains("voiceover")
                || text.lowercased().contains("accessibility")
            if !explains {
                Issue.record("\(path) caps type without saying how the information reaches someone who needed the larger size")
            }
        }
    }
}
