import Foundation
import Testing
@testable import ihsan

/// The one time the app mentions the sunnah layer, and every reason it
/// stays quiet instead.
@Suite("The sunnah invitation")
struct SunnahInviteTests {

    private func offers(
        days: Int,
        enabled: Bool = false,
        dismissed: Bool = false
    ) -> Bool {
        SunnahInvite.shouldOffer(
            distinctLoggedDays: days,
            sunnahLayerEnabled: enabled,
            hasBeenDismissed: dismissed
        )
    }

    @Test("It waits for a fortnight of days")
    func itWaitsForAHabit() {
        #expect(SunnahInvite.requiredDays == 14)
        #expect(!offers(days: 0))
        #expect(!offers(days: 1))
        #expect(!offers(days: 13), "On day thirteen the app still says nothing.")
        #expect(offers(days: 14))
        #expect(offers(days: 400))
    }

    @Test("Someone who already found it is never told about it")
    func itStaysQuietWhenTheLayerIsOn() {
        #expect(!offers(days: 400, enabled: true))
    }

    @Test("Either answer retires it forever")
    func itIsAskedOnce() {
        #expect(!offers(days: 400, dismissed: true))
        // Turning the layer on and back off does not bring it back:
        // the dismissal outlives the setting.
        #expect(!offers(days: 400, enabled: false, dismissed: true))
    }
}
