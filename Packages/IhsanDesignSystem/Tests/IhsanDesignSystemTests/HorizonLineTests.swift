import Foundation
import Testing
@testable import IhsanDesignSystem

// MARK: - HorizonLine.glowOpacity(forSunAltitude:)
//
// The brass rule itself is always visible; only the warm / rose-gold
// glow bands are gated by sun altitude. These tests pin the glow's
// fade behavior so dawn and dusk transition cleanly without the line
// reading as a hard band toggle.

@Test
func glowAtZeroAltitudeIsFullyVisible() {
    #expect(HorizonLine.glowOpacity(forSunAltitude: 0) == 1.0)
}

@Test
func glowAtPlateauEdgeIsFullyVisible() {
    // ±5° is the plateau — full opacity at the inner edge.
    #expect(HorizonLine.glowOpacity(forSunAltitude: 5) == 1.0)
    #expect(HorizonLine.glowOpacity(forSunAltitude: -5) == 1.0)
}

@Test
func glowAtEnvelopeEdgeIsTransparent() {
    // ±10° is the outer envelope — fully transparent.
    #expect(HorizonLine.glowOpacity(forSunAltitude: 10) == 0.0)
    #expect(HorizonLine.glowOpacity(forSunAltitude: -10) == 0.0)
}

@Test
func glowBeyondEnvelopeIsTransparent() {
    #expect(HorizonLine.glowOpacity(forSunAltitude: 30) == 0.0)
    #expect(HorizonLine.glowOpacity(forSunAltitude: -30) == 0.0)
}

@Test
func glowOpacityRampsLinearlyBetweenPlateauAndEnvelope() {
    // At ±7.5° (midpoint of the 5–10° ramp), opacity is 0.5.
    #expect(abs(HorizonLine.glowOpacity(forSunAltitude: 7.5) - 0.5) < 1e-9)
    #expect(abs(HorizonLine.glowOpacity(forSunAltitude: -7.5) - 0.5) < 1e-9)
}

@Test
func glowOpacityIsMonotonicAcrossEnvelope() {
    // Through 0° → 10°, opacity decreases monotonically.
    var previous = 2.0
    for alt in stride(from: 0.0, through: 12.0, by: 0.5) {
        let value = HorizonLine.glowOpacity(forSunAltitude: alt)
        #expect(value <= previous, "glow opacity increased at alt \(alt): \(previous) → \(value)")
        previous = value
    }
}

@Test
func glowOpacityIsSymmetricAroundZero() {
    for alt in stride(from: 0.0, through: 15.0, by: 1.0) {
        let positive = HorizonLine.glowOpacity(forSunAltitude: alt)
        let negative = HorizonLine.glowOpacity(forSunAltitude: -alt)
        #expect(abs(positive - negative) < 1e-9, "glow opacity at +\(alt) was \(positive); at -\(alt) was \(negative)")
    }
}
