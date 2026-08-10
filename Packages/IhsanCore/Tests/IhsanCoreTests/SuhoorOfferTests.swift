import Foundation
import Testing
@testable import IhsanCore

/// Offered, never assumed. The suggestion appears once, in one Ramadan,
/// and never raises itself again whatever the person decided.
@Suite("The suhoor suggestion")
struct SuhoorOfferTests {

    private static let someMoment = Date(timeIntervalSince1970: 1_780_000_000)

    @Test("It appears during Ramadan when the anchor is off and it has not been shown")
    func appearsInRamadanWhenUnset() {
        #expect(
            SuhoorOffer.shouldOffer(
                isRamadan: true, anchorEnabled: false, offeredAt: nil
            )
        )
    }

    @Test("It stays away outside Ramadan")
    func staysAwayOutsideRamadan() {
        #expect(
            SuhoorOffer.shouldOffer(
                isRamadan: false, anchorEnabled: false, offeredAt: nil
            ) == false
        )
    }

    /// Nothing is gained by offering someone a thing they already have.
    @Test("It stays away when the anchor is already on")
    func staysAwayWhenAlreadyOn() {
        #expect(
            SuhoorOffer.shouldOffer(
                isRamadan: true, anchorEnabled: true, offeredAt: nil
            ) == false
        )
    }

    @Test("Once shown it never returns, whatever was decided")
    func neverReturnsOnceShown() {
        #expect(
            SuhoorOffer.shouldOffer(
                isRamadan: true, anchorEnabled: false, offeredAt: Self.someMoment
            ) == false
        )
        // Including a later Ramadan, a year on.
        #expect(
            SuhoorOffer.shouldOffer(
                isRamadan: true,
                anchorEnabled: false,
                offeredAt: Self.someMoment.addingTimeInterval(365 * 24 * 3_600)
            ) == false
        )
    }

    /// Someone who turns it on and later turns it off has answered the
    /// question. The app does not ask again.
    @Test("Turning it back off does not bring the suggestion back")
    func turningOffDoesNotReopenTheOffer() {
        #expect(
            SuhoorOffer.shouldOffer(
                isRamadan: true, anchorEnabled: false, offeredAt: Self.someMoment
            ) == false
        )
    }
}
