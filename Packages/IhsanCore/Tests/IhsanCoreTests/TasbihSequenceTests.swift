import Testing
@testable import IhsanCore

/// The tasbīḥ after each fard salah — 33 Subḥānallāh, 33
/// Alḥamdulillāh, 33 Allāhu Akbar (Muslim 597).
///
/// The instrument used to hold one phrase for the whole sitting, so
/// from mark 34 onward the label contradicted what the person was
/// actually reciting.
struct TasbihSequenceTests {

    @Test
    func aSittingBegunOnSubhanallahWalksTheThree() {
        let sequence = TasbihSequence(head: .subhanallah)
        #expect(sequence.walksTheSequence)
        #expect(sequence.phrase(atTotalCount: 1) == .subhanallah)
        #expect(sequence.phrase(atTotalCount: 33) == .subhanallah)
        #expect(sequence.phrase(atTotalCount: 34) == .alhamdulillah)
        #expect(sequence.phrase(atTotalCount: 66) == .alhamdulillah)
        #expect(sequence.phrase(atTotalCount: 67) == .allahuAkbar)
        #expect(sequence.phrase(atTotalCount: 99) == .allahuAkbar)
    }

    /// A phrase the person chose to sit on simply continues. The
    /// sequence is a property of the canonical START, not a mode
    /// anyone has to find.
    @Test(arguments: [DhikrPhrase.alhamdulillah, .allahuAkbar, .astaghfirullah, .custom])
    func aSittingBegunElsewhereStaysThere(head: DhikrPhrase) {
        let sequence = TasbihSequence(head: head)
        #expect(!sequence.walksTheSequence)
        #expect(sequence.phrase(atTotalCount: 1) == head)
        #expect(sequence.phrase(atTotalCount: 34) == head)
        #expect(sequence.phrase(atTotalCount: 200) == head)
    }

    @Test
    func theMarkHoldsAt33AtEveryBoundary() {
        let sequence = TasbihSequence(head: .subhanallah)
        #expect(sequence.markInCycle(atTotalCount: 0) == 0)
        #expect(sequence.markInCycle(atTotalCount: 1) == 1)
        #expect(sequence.markInCycle(atTotalCount: 33) == 33)
        #expect(sequence.markInCycle(atTotalCount: 34) == 1)
        #expect(sequence.markInCycle(atTotalCount: 66) == 33)
        #expect(sequence.markInCycle(atTotalCount: 99) == 33)
    }

    @Test
    func completedCyclesCountTheThirds() {
        let sequence = TasbihSequence(head: .subhanallah)
        #expect(sequence.completedCycles(atTotalCount: 32) == 0)
        #expect(sequence.completedCycles(atTotalCount: 33) == 1)
        #expect(sequence.completedCycles(atTotalCount: 66) == 2)
        #expect(sequence.completedCycles(atTotalCount: 99) == 3)
    }

    /// At 99 the three thirds are done. The hundredth that completes
    /// them is a full narrated supplication and lives in the guided
    /// adhkar set, behind the scholar-review gate — the instrument
    /// marks the arrival and does not print unreviewed text.
    @Test
    func theThreeThirdsCompleteAt99() {
        let sequence = TasbihSequence(head: .subhanallah)
        #expect(!sequence.isComplete(atTotalCount: 98))
        #expect(sequence.isComplete(atTotalCount: 99))
        #expect(sequence.isComplete(atTotalCount: 120))
        // A sitting on a single phrase never "completes" — it is not
        // walking a sequence with an end.
        #expect(!TasbihSequence(head: .astaghfirullah).isComplete(atTotalCount: 200))
    }
}
