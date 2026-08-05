import Foundation
import IhsanCore
import Testing
@testable import ihsan

/// Every widget's tap lands somewhere real, and nothing a URL can
/// carry sends the app anywhere surprising.
@Suite("Widget deeplink routing")
struct WidgetDeeplinkRouterTests {

    private func destination(_ string: String) -> WidgetDeeplinkRouter.Destination? {
        WidgetDeeplinkRouter.destination(for: URL(string: string)!)
    }

    @Test
    func routesEveryWidgetDestination() {
        #expect(destination("ihsan://today") == .today)
        #expect(destination("ihsan://today?qibla=1") == .qibla)
        #expect(destination("ihsan://today?hijri=1") == .hijri)
        #expect(destination("ihsan://today?night=1") == .today)
        #expect(destination("ihsan://today?log=asr") == .logSheet(.asr))
        #expect(destination("ihsan://today?log=fajr") == .logSheet(.fajr))
    }

    @Test
    func malformedURLsLandOnTodayNeverNowhere() {
        // A widget tap must never dead-end: unknown hosts and bad
        // queries degrade to Today.
        #expect(destination("ihsan://unknown") == .today)
        #expect(destination("ihsan://today?log=breakfast") == .today)
        #expect(destination("ihsan://today?qibla=0") == .today)
        // Foreign schemes are not ours to answer.
        #expect(destination("https://example.com") == nil)
    }
}
