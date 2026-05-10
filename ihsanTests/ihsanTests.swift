//
//  ihsanTests.swift
//  ihsanTests
//
//  Created by Sameer Akhtar on 5/9/26.
//

import Testing
@testable import ihsan

@MainActor
struct HapticsTests {

    @Test func impactMapExposesLockedWeights() {
        #expect(Haptics.Impact.allCases == [.light, .medium, .soft])
    }

    @Test func notificationMapOmitsErrorFeedback() {
        #expect(Haptics.Notification.allCases == [.success, .warning])
    }

}
