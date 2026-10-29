import Foundation
import Testing

/// Every presentation pins its own dark scheme, enforced against the
/// sources.
///
/// The window's color scheme follows the sky so the status bar's ink
/// can be dark on the day pages (`StatusBarInk` in `IhsanApp.swift`).
/// Content stays dark because the root hands `.dark` down through the
/// environment — but UIKit presentations take the WINDOW's traits,
/// not the environment. An unpinned sheet looks right at night and in
/// every dark-hour screenshot, then goes light-glass by day; the log
/// sheet's off "In Jamāʿah" switch went white-on-white that way.
///
/// Nothing about a missing pin fails at runtime or shows at night, so
/// the sources are the only place to catch it.
@Suite("Presentation color scheme")
struct PresentationColorSchemeTests {

    /// Symlinks resolved on both sides of the prefix strip, for the
    /// reason `HapticVocabularyTests.repoRoot` gives.
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("Every sheet, cover and popover pins .preferredColorScheme(.dark) on its content")
    func everyPresentationPinsDark() throws {
        let manager = FileManager.default
        var presentations = 0

        for root in ["ihsan", "Packages"] {
            guard let walker = manager.enumerator(
                at: repoRoot.appending(path: root),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                Issue.record("Could not walk \(root)")
                continue
            }

            for case let url as URL in walker where url.pathExtension == "swift" {
                let relative = url.resolvingSymlinksInPath().path
                    .replacingOccurrences(of: repoRoot.path + "/", with: "")
                // Package tests never present anything to a person.
                guard !relative.contains("/Tests/") else { continue }

                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let sweep = PresentationSweep(source: text)
                presentations += sweep.sites.count
                for site in sweep.sites where !site.isPinned {
                    Issue.record("\(relative):\(site.line) presents without pinning `.preferredColorScheme(.dark)` on its content. The window goes light by day for the status bar, and an unpinned presentation goes with it. Pin it on the closure's outermost view (wrap an `if let` in a `Group`), with a trailing closure.")
                }
            }
        }

        // A scanner that has lost its footing finds nothing and passes.
        #expect(presentations >= 30, "The sweep found only \(presentations) presentations; the app has 32.")
    }

    @Test("The sweep tells a pinned presentation from an unpinned one")
    func sweepReadsTheShapes() {
        let source = """
        .sheet(isPresented: $a) {
            Pinned()
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(item: Binding(
            get: { model?.event },
            set: { model?.event = $0 }
        )) { event in
            Moment(event: event) // a ) in a comment
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $b) {
            Unpinned(title: "a { in prose \\(count(of: ")"))")
        }
        .sheet(isPresented: $c) {
            if let model {
                OnlyWhenPresent(model: model)
                    .preferredColorScheme(.dark)
            }
        }
        .popover(isPresented: $d, content: Elsewhere.init)
        .sheet(item: $e) { item in
            Group {
                if let item {
                    Present(item)
                }
            }
            .preferredColorScheme(.dark)
        }
        """
        let sweep = PresentationSweep(source: source)

        #expect(sweep.sites.map(\.line) == [1, 5, 12, 15, 21, 22])
        #expect(sweep.sites.filter { !$0.isPinned }.map(\.line) == [12, 15, 21])
    }
}

/// Finds `.sheet(`, `.fullScreenCover(` and `.popover(` in one source
/// file and reads whether each trailing content closure applies
/// `.preferredColorScheme(.dark)` at its own top level.
///
/// Top level, not anywhere inside: a pin inside an `if let` branch
/// covers the branch but not the closure, and a pin inside a nested
/// builder is one refactor away from covering nothing.
private struct PresentationSweep {
    struct Site {
        let line: Int
        let isPinned: Bool
    }

    private static let presenters = [".sheet(", ".fullScreenCover(", ".popover("]
    private static let pin = Array(".preferredColorScheme(.dark)")

    let sites: [Site]

    init(source: String) {
        let code = Self.blankingCommentsAndStrings(Array(source))
        var sites: [Site] = []
        for presenter in Self.presenters.map(Array.init) {
            var index = 0
            while let start = Self.find(presenter, in: code, from: index) {
                index = start + presenter.count
                let line = code[..<start].filter { $0 == "\n" }.count + 1
                sites.append(Site(
                    line: line,
                    isPinned: Self.closureIsPinned(code, openParen: start + presenter.count - 1)
                ))
            }
        }
        self.sites = sites.sorted { $0.line < $1.line }
    }

    private static func closureIsPinned(_ code: [Character], openParen: Int) -> Bool {
        guard let closeParen = matching(code, from: openParen, open: "(", close: ")") else {
            return false
        }
        var brace = closeParen + 1
        while brace < code.count, code[brace].isWhitespace { brace += 1 }
        guard brace < code.count, code[brace] == "{",
              let end = matching(code, from: brace, open: "{", close: "}")
        else { return false }

        var depth = 0
        var index = brace + 1
        while index < end {
            if depth == 0, code[index] == ".", Array(code[index..<min(index + pin.count, end)]) == pin {
                return true
            }
            switch code[index] {
            case "(", "{", "[": depth += 1
            case ")", "}", "]": depth -= 1
            default: break
            }
            index += 1
        }
        return false
    }

    private static func matching(
        _ code: [Character], from start: Int, open: Character, close: Character
    ) -> Int? {
        var depth = 0
        for index in start..<code.count {
            if code[index] == open { depth += 1 }
            if code[index] == close {
                depth -= 1
                if depth == 0 { return index }
            }
        }
        return nil
    }

    private static func find(_ needle: [Character], in haystack: [Character], from start: Int) -> Int? {
        guard needle.count <= haystack.count else { return nil }
        var index = start
        while index + needle.count <= haystack.count {
            if haystack[index] == needle[0], Array(haystack[index..<index + needle.count]) == needle {
                return index
            }
            index += 1
        }
        return nil
    }

    /// The source with comments and string literals blanked, so a
    /// bracket in prose cannot unbalance the scan. Newlines survive,
    /// so line numbers do too.
    private static func blankingCommentsAndStrings(_ source: [Character]) -> [Character] {
        var code = source
        func blank(_ range: Range<Int>) {
            for index in range where code[index] != "\n" { code[index] = " " }
        }
        var index = 0
        while index < source.count {
            let next = index + 1 < source.count ? source[index + 1] : nil
            if source[index] == "/", next == "/" {
                let end = source[index...].firstIndex(of: "\n") ?? source.count
                blank(index..<end)
                index = end
            } else if source[index] == "/", next == "*" {
                var end = index + 2
                while end + 1 < source.count, !(source[end] == "*" && source[end + 1] == "/") { end += 1 }
                end = min(end + 2, source.count)
                blank(index..<end)
                index = end
            } else if source[index] == "\"" {
                let end = endOfString(source, from: index)
                blank(index..<end)
                index = end
            } else {
                index += 1
            }
        }
        return code
    }

    /// One past the closing quote of the literal opening at `start`,
    /// walking through interpolations (which may hold strings of their
    /// own) rather than stopping at the first quote inside one.
    private static func endOfString(_ source: [Character], from start: Int) -> Int {
        let isMultiline = start + 2 < source.count && source[start + 1] == "\"" && source[start + 2] == "\""
        var index = start + (isMultiline ? 3 : 1)
        while index < source.count {
            switch source[index] {
            case "\\":
                if index + 1 < source.count, source[index + 1] == "(" {
                    index = endOfInterpolation(source, from: index + 2)
                } else {
                    index += 2
                }
            case "\"":
                if !isMultiline { return index + 1 }
                if index + 2 < source.count, source[index + 1] == "\"", source[index + 2] == "\"" {
                    return index + 3
                }
                index += 1
            default:
                index += 1
            }
        }
        return source.count
    }

    private static func endOfInterpolation(_ source: [Character], from start: Int) -> Int {
        var depth = 1
        var index = start
        while index < source.count {
            switch source[index] {
            case "\"":
                index = endOfString(source, from: index)
                continue
            case "(":
                depth += 1
            case ")":
                depth -= 1
                if depth == 0 { return index + 1 }
            default:
                break
            }
            index += 1
        }
        return source.count
    }
}
