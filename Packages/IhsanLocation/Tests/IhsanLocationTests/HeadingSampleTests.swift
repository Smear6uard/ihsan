import Testing
import Foundation
@testable import IhsanLocation

@Test
func preferredHeadingFavorsTrueHeading() {
    let sample = HeadingSample(
        trueHeading: 47.5,
        magneticHeading: 50.2,
        accuracy: 5,
        timestamp: .now
    )
    #expect(sample.preferredHeading == 47.5)
}

@Test
func preferredHeadingFallsBackToMagneticWhenTrueInvalid() {
    let sample = HeadingSample(
        trueHeading: -1,
        magneticHeading: 50.2,
        accuracy: 5,
        timestamp: .now
    )
    #expect(sample.preferredHeading == 50.2)
}

@Test
func accuracyAcceptableForGoodReading() {
    let sample = HeadingSample(
        trueHeading: 47.5,
        magneticHeading: 50.2,
        accuracy: 8,
        timestamp: .now
    )
    #expect(sample.isAccuracyAcceptable == true)
}

@Test
func accuracyNotAcceptableForNegative() {
    let sample = HeadingSample(
        trueHeading: 47.5,
        magneticHeading: 50.2,
        accuracy: -1,
        timestamp: .now
    )
    #expect(sample.isAccuracyAcceptable == false)
}

@Test
func accuracyNotAcceptableForPoorReading() {
    let sample = HeadingSample(
        trueHeading: 47.5,
        magneticHeading: 50.2,
        accuracy: 35,
        timestamp: .now
    )
    #expect(sample.isAccuracyAcceptable == false)
}
