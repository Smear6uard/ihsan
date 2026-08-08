import Foundation
import Testing

@Suite("Pattern sharing discipline")
struct PatternShareDisciplineTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: path), encoding: .utf8)
    }

    @Test("Path has one share entry and one system handoff")
    func oneEntryPointAndOneHandoff() throws {
        let path = try source("ihsan/Trajectory/TrajectoryScreen.swift")
        let preview = try source(
            "ihsan/Trajectory/Share/PatternSharePreviewSheet.swift"
        )

        #expect(path.components(separatedBy: "SettingsGlyphView(.share").count - 1 == 1)
        #expect(path.components(separatedBy: "beginPatternShare(").count - 1 == 2)
        #expect(preview.components(separatedBy: "ShareLink(").count - 1 == 1)
        #expect(!preview.contains("subject:"))
        #expect(!preview.contains("message:"))
    }

    @Test("The renderer boundary carries no pause metadata")
    func rendererCannotReceivePauseMetadata() throws {
        let card = try source("ihsan/Trajectory/Share/PatternShareCard.swift")
        #expect(!card.contains("PauseInterval"))
        #expect(!card.contains("isPaused"))
        #expect(!card.contains("pausedDays"))
        #expect(!card.contains("TrajectoryAggregate"))
    }

    @Test("Masjid results have no contact or sharing actions")
    func masjidRowsStayDirectionsOnly() throws {
        let root = repoRoot.appending(path: "ihsan/MasjidFinder")
        let walker = try #require(
            FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        )
        let swiftFiles = walker.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
        let allSource = try swiftFiles.map {
            try String(contentsOf: $0, encoding: .utf8)
        }.joined(separator: "\n")

        for forbidden in [
            "UIActivityViewController", "ShareLink(", "shareURL",
            "phoneNumber", ".rating", ".reviews", "reviewCount",
            "@unchecked Sendable", "private let mapItem"
        ] {
            #expect(!allSource.contains(forbidden), "Masjid finder contains \(forbidden)")
        }
    }
}
