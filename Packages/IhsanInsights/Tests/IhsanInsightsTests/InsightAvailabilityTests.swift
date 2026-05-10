import Testing
@testable import IhsanInsights

@Test
func availabilityGateCanBeMockedForBothStates() {
    InsightAvailability.setAvailabilityProviderForTesting { true }
    defer { InsightAvailability.resetAvailabilityProviderForTesting() }

    #expect(InsightAvailability.isAvailable)

    InsightAvailability.setAvailabilityProviderForTesting { false }
    #expect(!InsightAvailability.isAvailable)
}
