import Foundation
import IhsanCore
import IhsanDesignSystem

/// Where a person is inside a remembrance set.
///
/// A value type with no view, no clock, and no store: counting is the
/// heart of this surface and it should be possible to prove it correct
/// without rendering anything.
struct AdhkarSetState: Equatable {
    let items: [AdhkarItem]

    /// Counts kept so far, one per item, parallel to `items`.
    private(set) var counts: [Int]

    /// The item on screen.
    private(set) var index: Int

    init(items: [AdhkarItem]) {
        self.items = items
        self.counts = Array(repeating: 0, count: items.count)
        self.index = 0
    }

    var isEmpty: Bool { items.isEmpty }

    var currentItem: AdhkarItem? {
        items.indices.contains(index) ? items[index] : nil
    }

    var currentCount: Int {
        counts.indices.contains(index) ? counts[index] : 0
    }

    var currentTarget: Int {
        currentItem?.repetitions ?? 1
    }

    func isComplete(at index: Int) -> Bool {
        guard items.indices.contains(index) else { return false }
        return counts[index] >= items[index].repetitions
    }

    var isCurrentComplete: Bool { isComplete(at: index) }

    /// Items counted to their transmitted number. The one figure a
    /// session records.
    var completedItemCount: Int {
        items.indices.filter { isComplete(at: $0) }.count
    }

    var isSetComplete: Bool {
        !items.isEmpty && completedItemCount == items.count
    }

    var markStates: [SequenceMarkState] {
        items.indices.map { position in
            if isComplete(at: position) { return .complete }
            return position == index ? .current : .pending
        }
    }

    /// What a tap did, so the surface knows which haptic to make and
    /// whether to move on.
    enum CountOutcome: Equatable {
        /// One more of this item's count.
        case counted
        /// This item reached its transmitted number.
        case itemCompleted
        /// …and it was the last one outstanding.
        case setCompleted
        /// The tap landed on an item already counted through, and there
        /// is nothing left to count.
        case nothingToCount
    }

    mutating func count() -> CountOutcome {
        guard items.indices.contains(index) else { return .nothingToCount }
        guard !isCurrentComplete else { return .nothingToCount }

        counts[index] += 1
        guard isCurrentComplete else { return .counted }
        return isSetComplete ? .setCompleted : .itemCompleted
    }

    mutating func move(to newIndex: Int) {
        guard items.indices.contains(newIndex) else { return }
        index = newIndex
    }

    mutating func moveToNext() {
        move(to: index + 1)
    }

    mutating func moveToPrevious() {
        move(to: index - 1)
    }

    /// The next item still outstanding, searching forward from the
    /// current one and wrapping — so a person who skipped ahead is
    /// returned to what they left rather than dropped at the end.
    var nextOutstandingIndex: Int? {
        guard !isSetComplete else { return nil }
        for step in 1...max(items.count, 1) {
            let candidate = (index + step) % max(items.count, 1)
            if !isComplete(at: candidate) { return candidate }
        }
        return nil
    }

    mutating func advanceToNextOutstanding() {
        guard let next = nextOutstandingIndex else { return }
        move(to: next)
    }
}
