import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import IhsanDesignSystem

/// Verification-artifact rendering, not assertions: when
/// `IHSAN_SNAPSHOT_DIR` is set in the environment, these tests write
/// PNGs of acceptance views (the 16 pt silhouette grid) to that
/// directory for the corrective's device-review report. Without the
/// variable they are no-ops, so normal `swift test` runs stay pure.
@MainActor
struct SnapshotArtifactTests {

    @Test
    func writeSilhouetteGridArtifact() throws {
        guard let dir = ProcessInfo.processInfo.environment["IHSAN_SNAPSHOT_DIR"] else {
            return
        }
        let renderer = ImageRenderer(content: SilhouetteGridView())
        renderer.scale = 4
        let image = try #require(renderer.cgImage, "silhouette grid failed to render")

        let url = URL(fileURLWithPath: dir).appendingPathComponent("silhouette-grid.png")
        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination), "failed to write \(url.path)")
    }
}
