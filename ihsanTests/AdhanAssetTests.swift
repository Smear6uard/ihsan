import AVFoundation
import Foundation
import IhsanCore
import IhsanNotifications
import Testing
@testable import ihsan

/// The sound pipeline, checked against the bundle the app actually
/// ships rather than against a mock.
///
/// Every failure mode here is one iOS reports silently: a `.caf` that
/// isn't in the bundle, a name that drifted from its constant, or a
/// tone longer than thirty seconds. In all three cases the notification
/// still arrives — with no sound — and nothing in the logs says why.
@Suite("Adhan assets")
struct AdhanAssetTests {

    /// Apple's hard ceiling. A longer file is not truncated; it is
    /// ignored, and the notification arrives silent.
    private static let notificationSoundLimit: TimeInterval = 30

    private func url(for fileName: String) -> URL? {
        let path = URL(fileURLWithPath: fileName)
        return Bundle(for: BundleToken.self).url(
            forResource: path.deletingPathExtension().lastPathComponent,
            withExtension: path.pathExtension
        ) ?? Bundle.main.url(
            forResource: path.deletingPathExtension().lastPathComponent,
            withExtension: path.pathExtension
        )
    }

    private func duration(of url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.fileFormat.sampleRate
    }

    @Test("Every notification tone this build offers is in the bundle")
    func offeredTonesArePresent() throws {
        let resolver = AdhanSoundFileResolver { [self] in url(for: $0) != nil }

        for prayer in Prayer.allCases {
            for option in AdhanSoundCatalog.options(for: prayer) {
                let resolved = option.resolvedFileName(using: resolver)
                if option == .silent {
                    #expect(resolved == nil, "Silent must resolve to no file.")
                    continue
                }
                guard let name = resolved else {
                    Issue.record("\(option.rawValue) for \(prayer.rawValue) resolved to nothing; the notification would arrive silent")
                    continue
                }
                #expect(
                    url(for: name) != nil,
                    "\(name) is not in the app bundle."
                )
            }
        }
    }

    @Test("No notification tone exceeds the thirty-second limit")
    func tonesFitTheNotificationLimit() throws {
        for name in [AdhanAsset.chime, AdhanAsset.chimeDawn, AdhanAsset.takbirat] {
            guard let url = url(for: name) else { continue } // not yet recorded
            let seconds = try duration(of: url)
            if seconds > Self.notificationSoundLimit {
                Issue.record("\(name) is \(seconds)s; iOS ignores a tone over 30s and the notification arrives with no sound at all")
            }
            #expect(seconds > 0.5, "\(name) is \(seconds)s — effectively silent.")
        }
    }

    @Test("The chime is present, because everything falls back to it")
    func theChimeIsAlwaysThere() throws {
        let chime = try #require(url(for: AdhanAsset.chime))
        let seconds = try duration(of: chime)
        #expect(seconds > 1)
        #expect(seconds <= Self.notificationSoundLimit)
    }

    @Test("The gentle wake plays a tone that exists")
    func theWakeToneIsPresent() {
        #expect(url(for: AdhanAsset.nightWake) != nil)
        #expect(AdhanAsset.nightWake == AdhanAsset.chime)
    }

    @Test("The full-adhan asset is readable and longer than a notification tone")
    @MainActor
    func theFullAdhanIsPlayable() throws {
        // Its whole reason to exist is being longer than iOS will play.
        let url = try #require(
            AdhanPlayer.assetURL,
            "The in-app recording is missing; Set → Adhan's Play would do nothing."
        )
        let seconds = try duration(of: url)
        // A recording shorter than the notification limit would have no
        // reason to need the in-app path at all.
        #expect(seconds > Self.notificationSoundLimit)
        #expect(AVAudioPlayer.canRead(url), "AVAudioPlayer cannot read \(url.lastPathComponent).")
    }

    @Test("The takbīrāt option describes itself honestly while unrecorded")
    func theUnrecordedOptionSaysSo() {
        let resolver = AdhanSoundFileResolver { [self] in url(for: $0) != nil }
        let recorded = url(for: AdhanAsset.takbirat) != nil

        #expect(
            AdhanSoundCatalog.takbirat.awaitsRecording(using: resolver) == !recorded,
            "The row's 'recording not in this build yet' note must track the bundle."
        )
        // Recorded or not, choosing it never yields silence.
        #expect(AdhanSoundCatalog.takbirat.resolvedFileName(using: resolver) != nil)
    }
}

private final class BundleToken {}

private extension AVAudioPlayer {
    static func canRead(_ url: URL) -> Bool {
        (try? AVAudioPlayer(contentsOf: url)) != nil
    }
}
