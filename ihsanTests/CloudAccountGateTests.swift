import CloudKit
import Foundation
import Testing
@testable import ihsan

@Suite("CloudAccountGate decision table")
struct CloudAccountGateTests {

    @Test
    func noAccountDisablesSyncAndLogsOnTransitionOnly() {
        // First discovery of the missing account: cache flips, one log.
        let transition = CloudAccountGate.decision(
            status: .noAccount, previouslyAvailable: true
        )
        #expect(transition.cacheAvailable == false)
        #expect(transition.shouldLog == true)

        // Already known missing: stay local-only, stay quiet — no
        // repeated logging, no retry.
        let steady = CloudAccountGate.decision(
            status: .noAccount, previouslyAvailable: false
        )
        #expect(steady.cacheAvailable == false)
        #expect(steady.shouldLog == false)
    }

    @Test
    func availableRestoresSyncSilently() {
        let restored = CloudAccountGate.decision(
            status: .available, previouslyAvailable: false
        )
        #expect(restored.cacheAvailable == true)
        #expect(restored.shouldLog == false)

        let steady = CloudAccountGate.decision(
            status: .available, previouslyAvailable: true
        )
        #expect(steady.cacheAvailable == true)
        #expect(steady.shouldLog == false)
    }

    /// Transient statuses never flip the cache in either direction and
    /// never log — the gate acts only on definitive answers, so there
    /// is nothing to retry.
    @Test
    func indeterminateStatusesKeepThePreviousDecision() {
        for status: CKAccountStatus in [.couldNotDetermine, .restricted, .temporarilyUnavailable] {
            for previous in [true, false] {
                let d = CloudAccountGate.decision(status: status, previouslyAvailable: previous)
                #expect(d.cacheAvailable == previous)
                #expect(d.shouldLog == false)
            }
        }
    }
}
