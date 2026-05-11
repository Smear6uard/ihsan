import Foundation
import Testing
@testable import IhsanDesignSystem

// MARK: - HorizonLine.opacity(forSunAltitude:)

@Test
func horizonAtZeroAltitudeIsFullyVisible() {
    #expect(HorizonLine.opacity(forSunAltitude: 0) == 1.0)
}

@Test
func horizonAtPlateauEdgeIsFullyVisible() {
    // ±5° is the plateau — full opacity at the inner edge.
    #expect(HorizonLine.opacity(forSunAltitude: 5) == 1.0)
    #expect(HorizonLine.opacity(forSunAltitude: -5) == 1.0)
}

@Test
func horizonAtEnvelopeEdgeIsTransparent() {
    // ±10° is the outer envelope — fully transparent.
    #expect(HorizonLine.opacity(forSunAltitude: 10) == 0.0)
    #expect(HorizonLine.opacity(forSunAltitude: -10) == 0.0)
}

@Test
func horizonBeyondEnvelopeIsTransparent() {
    #expect(HorizonLine.opacity(forSunAltitude: 30) == 0.0)
    #expect(HorizonLine.opacity(forSunAltitude: -30) == 0.0)
}

@Test
func horizonOpacityRampsLinearlyBetweenPlateauAndEnvelope() {
    // At ±7.5° (midpoint of the 5–10° ramp), opacity is 0.5.
    #expect(abs(HorizonLine.opacity(forSunAltitude: 7.5) - 0.5) < 1e-9)
    #expect(abs(HorizonLine.opacity(forSunAltitude: -7.5) - 0.5) < 1e-9)
}

@Test
func horizonOpacityIsMonotonicAcrossEnvelope() {
    // Through 0° → 10°, opacity decreases monotonically.
    var previous = 2.0
    for alt in stride(from: 0.0, through: 12.0, by: 0.5) {
        let value = HorizonLine.opacity(forSunAltitude: alt)
        #expect(value <= previous, "horizon opacity increased at alt \(alt): \(previous) → \(value)")
        previous = value
    }
}

@Test
func horizonOpacityIsSymmetricAroundZero() {
    for alt in stride(from: 0.0, through: 15.0, by: 1.0) {
        let positive = HorizonLine.opacity(forSunAltitude: alt)
        let negative = HorizonLine.opacity(forSunAltitude: -alt)
        #expect(abs(positive - negative) < 1e-9, "horizon opacity at +\(alt) was \(positive); at -\(alt) was \(negative)")
    }
}
