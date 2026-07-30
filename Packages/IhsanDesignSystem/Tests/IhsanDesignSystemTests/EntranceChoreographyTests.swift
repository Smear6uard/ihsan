import Testing
@testable import IhsanDesignSystem

/// The entrance's order carries meaning: the day's shape appears
/// before the day's marks, and light arrives on a world already drawn.
/// These pin that order, and the budget it has to fit inside.
@Suite("Entrance choreography")
struct EntranceChoreographyTests {

    @Test("The arc is first, the ornaments follow, the light is last")
    func theOrderHolds() {
        let arcEnds = EntranceChoreography.arcDelay + EntranceChoreography.arcDuration
        let firstMarker = EntranceChoreography.markerDelay(index: 0)
        let lastMarker = EntranceChoreography.markersSettled(count: 5)

        #expect(EntranceChoreography.arcDelay == 0, "Nothing precedes the arc.")
        #expect(
            firstMarker < arcEnds,
            "The first ornament joins while the arc is still drawing — a full stop between them reads as two separate events."
        )
        #expect(
            EntranceChoreography.glowDelay > firstMarker,
            "Light must not arrive before the marks it falls on."
        )
        #expect(lastMarker <= EntranceChoreography.totalDuration)
    }

    @Test("Ornaments bloom in prayer order, evenly")
    func markersBloomInOrder() {
        let delays = (0..<5).map { EntranceChoreography.markerDelay(index: $0) }
        #expect(delays == delays.sorted(), "Fajr blooms before Isha.")
        for index in 1..<delays.count {
            let gap = delays[index] - delays[index - 1]
            #expect(
                abs(gap - EntranceChoreography.markerStagger) < 0.0001,
                "The stagger is even; an uneven one reads as a stutter."
            )
        }
    }

    @Test("The whole entrance fits its budget")
    func theEntranceIsShort() {
        let glowEnds = EntranceChoreography.glowDelay + EntranceChoreography.glowDuration
        #expect(glowEnds <= EntranceChoreography.totalDuration)
        #expect(
            EntranceChoreography.totalDuration <= 1.0,
            "An entrance a person waits through is an entrance in the way."
        )
    }

    @Test("Reduce Motion collapses every stagger to one crossfade")
    func reduceMotionRemovesTheStagger() {
        // Every animation resolves to the same value, so nothing can
        // arrive after anything else.
        let arc = EntranceChoreography.arc(reduceMotion: true)
        let glow = EntranceChoreography.glow(reduceMotion: true)
        let first = EntranceChoreography.marker(index: 0, reduceMotion: true)
        let last = EntranceChoreography.marker(index: 4, reduceMotion: true)

        #expect(arc == EntranceChoreography.crossfade)
        #expect(glow == EntranceChoreography.crossfade)
        #expect(first == EntranceChoreography.crossfade)
        #expect(last == EntranceChoreography.crossfade)
        #expect(EntranceChoreography.reducedDuration <= 0.35)
    }
}
