import Foundation

/// The tasbīḥ after each fard salah: 33 × Subḥānallāh, 33 ×
/// Alḥamdulillāh, 33 × Allāhu Akbar — Muslim 597. The hundredth that
/// completes it ("Lā ilāha illa'llāhu waḥdahu lā sharīka lah…") is the
/// same narration, and lives in the guided adhkar set rather than
/// here: it is a full supplication, and this repo's copy of it sits
/// behind the scholar-review gate in `adhkar-content.json`. Printing
/// it from Swift would route unreviewed text around the gate that
/// exists to stop exactly that. So the instrument marks the arrival at
/// 99 and stops.
///
/// The sequence is a property of the canonical START, not a mode
/// anyone has to find: a sitting begun on Subḥānallāh walks the three;
/// a sitting begun on any other phrase — including the custom slot —
/// stays where the person put it and counts on.
///
/// One definition, in Core, so the instrument, the intents, and any
/// future surface cannot drift into disagreeing about what the tasbīḥ
/// is.
public struct TasbihSequence: Sendable, Equatable {

    public static let cycleLength = 33
    public static let phrases: [DhikrPhrase] = [.subhanallah, .alhamdulillah, .allahuAkbar]

    /// The phrase the sitting opened on.
    public let head: DhikrPhrase

    public init(head: DhikrPhrase) {
        self.head = head
    }

    /// Whether this sitting walks the three thirds.
    public var walksTheSequence: Bool {
        head == Self.phrases[0]
    }

    /// Thirds finished at `total` taps. Uncapped — a single-phrase
    /// sitting keeps accumulating cycles, which is what the three
    /// resting dots have always shown.
    public func completedCycles(atTotalCount total: Int) -> Int {
        max(0, total) / Self.cycleLength
    }

    /// Marks gilded in the current cycle: 1…33, holding at 33 the
    /// moment a cycle completes.
    public func markInCycle(atTotalCount total: Int) -> Int {
        total <= 0 ? 0 : ((total - 1) % Self.cycleLength) + 1
    }

    /// The phrase being recited at `total` taps.
    public func phrase(atTotalCount total: Int) -> DhikrPhrase {
        guard walksTheSequence else { return head }
        let index = max(0, total - 1) / Self.cycleLength
        return Self.phrases[min(index, Self.phrases.count - 1)]
    }

    /// True once all three thirds are done.
    public func isComplete(atTotalCount total: Int) -> Bool {
        walksTheSequence && total >= Self.cycleLength * Self.phrases.count
    }
}
