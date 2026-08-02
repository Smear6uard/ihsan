import Foundation
import IhsanCore
import IhsanDesignSystem
import Testing
@testable import ihsan

/// Counting is the heart of this surface, so it is proved without
/// rendering anything.
@Suite("Adhkar set counting")
struct AdhkarSetStateTests {

    private func item(_ id: String, repetitions: Int) -> AdhkarItem {
        AdhkarItem(
            id: id,
            category: .morning,
            order: 1,
            arabic: "سُبْحَانَ اللَّهِ",
            transliteration: "Subḥāna'llāh.",
            translation: "Glory is to Allah.",
            source: AdhkarSource(collection: "Muslim", reference: "2691"),
            repetitions: repetitions
        )
    }

    private var threeItems: [AdhkarItem] {
        [item("a", repetitions: 1), item("b", repetitions: 3), item("c", repetitions: 33)]
    }

    @Test("A fresh set starts at the first item with nothing counted")
    func startsClean() {
        let state = AdhkarSetState(items: threeItems)
        #expect(state.index == 0)
        #expect(state.currentCount == 0)
        #expect(state.completedItemCount == 0)
        #expect(!state.isSetComplete)
        #expect(state.markStates == [.current, .pending, .pending])
    }

    /// The transmitted count is honoured exactly — an item of three is
    /// kept at the third, not the second and not the fourth.
    @Test("Each item completes at its own transmitted count")
    func eachItemHonoursItsCount() {
        var state = AdhkarSetState(items: threeItems)

        // One.
        #expect(state.count() == .itemCompleted)
        #expect(state.isComplete(at: 0))

        state.move(to: 1)
        // Three.
        #expect(state.count() == .counted)
        #expect(state.count() == .counted)
        #expect(state.count() == .itemCompleted)
        #expect(state.currentCount == 3)

        state.move(to: 2)
        // Thirty-three.
        for step in 1..<33 {
            #expect(state.count() == .counted, "step \(step)")
        }
        #expect(state.count() == .setCompleted)
        #expect(state.isSetComplete)
        #expect(state.completedItemCount == 3)
    }

    /// A count already kept cannot be overrun into a wrong number.
    @Test("Counting past an item's number does nothing")
    func countingPastCompletionDoesNothing() {
        var state = AdhkarSetState(items: [item("a", repetitions: 3), item("b", repetitions: 1)])
        _ = state.count()
        _ = state.count()
        #expect(state.count() == .itemCompleted)
        #expect(state.count() == .nothingToCount)
        #expect(state.count() == .nothingToCount)
        #expect(state.currentCount == 3)
    }

    @Test("The last outstanding item reports the set complete, not merely the item")
    func lastItemCompletesTheSet() {
        var state = AdhkarSetState(items: [item("a", repetitions: 1), item("b", repetitions: 1)])
        #expect(state.count() == .itemCompleted)
        state.move(to: 1)
        #expect(state.count() == .setCompleted)
    }

    // MARK: - Moving

    @Test("The band reflects where the reader is and what is kept")
    func markStatesFollowProgress() {
        var state = AdhkarSetState(items: threeItems)
        _ = state.count()
        state.move(to: 2)
        #expect(state.markStates == [.complete, .pending, .current])
    }

    @Test("Moving out of range is refused rather than trapping")
    func movingOutOfRangeIsRefused() {
        var state = AdhkarSetState(items: threeItems)
        state.moveToPrevious()
        #expect(state.index == 0)
        state.move(to: 99)
        #expect(state.index == 0)
        state.move(to: -1)
        #expect(state.index == 0)
    }

    /// Someone who skipped ahead is returned to what they left, rather
    /// than dropped at the end of the set.
    @Test("Advancing wraps back to what was skipped")
    func advanceWrapsToOutstandingWork() {
        var state = AdhkarSetState(items: threeItems)
        state.move(to: 2)
        for _ in 1...33 { _ = state.count() }
        state.advanceToNextOutstanding()
        #expect(state.index == 0)
    }

    @Test("A complete set has nothing left to advance to")
    func completeSetHasNoNextItem() {
        var state = AdhkarSetState(items: [item("a", repetitions: 1)])
        _ = state.count()
        #expect(state.nextOutstandingIndex == nil)
        state.advanceToNextOutstanding()
        #expect(state.index == 0)
    }

    // MARK: - Degenerate input

    /// The reader is built from the content file; if the file were ever
    /// empty for a category the surface must be inert rather than
    /// crash.
    @Test("An empty set is inert")
    func emptySetIsInert() {
        var state = AdhkarSetState(items: [])
        #expect(state.isEmpty)
        #expect(state.currentItem == nil)
        #expect(!state.isSetComplete)
        #expect(state.count() == .nothingToCount)
        #expect(state.markStates.isEmpty)
    }

    // MARK: - The real sets

    /// The counting state runs over the shipped content, at the real
    /// transmitted counts, without anything going out of range.
    @Test("Every shipped set can be counted from end to end")
    func everyShippedSetCompletes() throws {
        let content = try #require(BundledAdhkar.content)
        for category in AdhkarCategory.allCases {
            let items = content.items(in: category)
            guard !items.isEmpty else { continue }

            var state = AdhkarSetState(items: items)
            var taps = 0
            while !state.isSetComplete {
                if state.isCurrentComplete {
                    state.advanceToNextOutstanding()
                    continue
                }
                _ = state.count()
                taps += 1
                #expect(taps < 5_000, "\(category.rawValue) did not converge")
            }
            #expect(state.completedItemCount == items.count)
            #expect(taps == items.reduce(0) { $0 + $1.repetitions })
        }
    }
}
