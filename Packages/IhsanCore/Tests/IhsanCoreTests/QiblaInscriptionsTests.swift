import Foundation
import Testing
@testable import IhsanCore

@Suite("QiblaInscriptions")
struct QiblaInscriptionsTests {

    // MARK: - Distance

    @Test("distance groups thousands with a narrow no-break space")
    func distanceGrouping() {
        #expect(QiblaInscriptions.distance(km: 10306.3) == "10\u{202F}306 KM")
        #expect(QiblaInscriptions.distance(km: 4793.8) == "4\u{202F}794 KM")
        #expect(QiblaInscriptions.distance(km: 11972.0) == "11\u{202F}972 KM")
    }

    @Test("short distances carry no grouping")
    func distanceShort() {
        #expect(QiblaInscriptions.distance(km: 412.4) == "412 KM")
        #expect(QiblaInscriptions.distance(km: 0.4) == "0 KM")
    }

    // MARK: - Relative direction

    @Test("a positive delta reads to your right")
    func relativeRight() {
        #expect(QiblaInscriptions.relativeDirection(signedDelta: 48.2) == "48° TO YOUR RIGHT")
    }

    @Test("a negative delta reads to your left")
    func relativeLeft() {
        #expect(QiblaInscriptions.relativeDirection(signedDelta: -31.7) == "32° TO YOUR LEFT")
    }

    @Test("a half-turn reads behind you")
    func relativeBehind() {
        #expect(QiblaInscriptions.relativeDirection(signedDelta: 176) == "BEHIND YOU")
        #expect(QiblaInscriptions.relativeDirection(signedDelta: -176) == "BEHIND YOU")
    }

    @Test("small deltas round to whole degrees, never zero")
    func relativeRounding() {
        #expect(QiblaInscriptions.relativeDirection(signedDelta: 4.4) == "4° TO YOUR RIGHT")
        #expect(QiblaInscriptions.relativeDirection(signedDelta: -0.3) == "1° TO YOUR LEFT")
    }

    // MARK: - Static bearing card (no compass hardware)

    @Test("static bearing phrases degrees and eight-wind cardinal")
    func staticBearing() {
        #expect(QiblaInscriptions.staticBearing(qiblaBearing: 58.481)
            == "QIBLA IS 58° NE OF TRUE NORTH")
        #expect(QiblaInscriptions.staticBearing(qiblaBearing: 277.5)
            == "QIBLA IS 278° W OF TRUE NORTH")
        #expect(QiblaInscriptions.staticBearing(qiblaBearing: 350.9)
            == "QIBLA IS 351° N OF TRUE NORTH")
        #expect(QiblaInscriptions.staticBearing(qiblaBearing: 118.987)
            == "QIBLA IS 119° SE OF TRUE NORTH")
    }

    // MARK: - VoiceOver phrases

    @Test("VoiceOver phrases speak whole degrees and side")
    func voiceOverPhrases() {
        #expect(QiblaInscriptions.spokenDirection(signedDelta: 40.2)
            == "40 degrees to your right")
        #expect(QiblaInscriptions.spokenDirection(signedDelta: -15)
            == "15 degrees to your left")
        #expect(QiblaInscriptions.spokenDirection(signedDelta: 178)
            == "Behind you")
    }

    @Test("VoiceOver distance speaks plain kilometers")
    func voiceOverDistance() {
        #expect(QiblaInscriptions.spokenDistance(km: 10306.3)
            == "10,306 kilometers to Makkah")
    }
}
