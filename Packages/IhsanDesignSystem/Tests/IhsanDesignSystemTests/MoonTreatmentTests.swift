import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import IhsanDesignSystem

/// Pins the moon's lit-object treatment on the dark grounds — the
/// dawn review found it collapsed to a flat gray disc, so the
/// contract is now pixel-sampled: the lit limb carries the warm
/// gold-white pole, the dark limb holds a cool indigo earthshine
/// (present, but clearly darker), the phase reads as a real
/// asymmetry, and the tight cool glow lifts the sky immediately
/// around the disc. A flat gray disc fails every one of these.
@MainActor
struct MoonTreatmentTests {

    private struct Sample {
        let r: Double, g: Double, b: Double
        var brightness: Double { (r + g + b) / 3 }
    }

    private func render(tokens: SkyPaletteTokens) throws -> (CGImage, Int) {
        let side: CGFloat = 120
        let view = ZStack {
            tokens.groundBottomValue.color
            LuminousBody(
                kind: .moon(illuminatedFraction: 0.35, isWaxing: false),
                diameter: 44,
                tokens: tokens
            )
        }
        .frame(width: side, height: side)
        .environment(\.celestialForceReducedMotion, true)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.cgImage, "moon failed to render")
        return (image, Int(side * 2))
    }

    private func pixel(_ image: CGImage, _ x: Int, _ y: Int) throws -> Sample {
        var data = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return Sample(r: Double(data[0]) / 255, g: Double(data[1]) / 255, b: Double(data[2]) / 255)
    }

    @Test
    func moonIsALitObjectOnTheDawnGround() throws {
        let tokens = SkyPaletteTokens.dawn
        let (image, side) = try render(tokens: tokens)
        let center = side / 2
        // Disc radius is 44 pt at 2× = 44 px; sample the two limbs
        // well inside the disc.
        let limbOffset = 26
        let left = try pixel(image, center - limbOffset, center)
        let right = try pixel(image, center + limbOffset, center)
        let lit = left.brightness >= right.brightness ? left : right
        let dark = left.brightness >= right.brightness ? right : left
        let background = try pixel(image, 6, 6)

        // The phase is a real asymmetry — one limb clearly lit.
        #expect(lit.brightness > dark.brightness + 0.10, "no visible phase — the disc reads flat")

        // The lit limb is the warm gold-white pole, not gray.
        #expect(lit.r > lit.b + 0.02, "lit limb has no warmth — reads gray")

        // Earthshine: the dark limb still holds the disc's form above
        // the ground, and stays cool (indigo family, not gray).
        #expect(dark.brightness > background.brightness + 0.03, "dark limb vanished — no earthshine")
        #expect(dark.b > dark.r, "earthshine lost its coolness")

        // The tight cool glow: the sky immediately around the disc is
        // lifted above the far ground.
        let nearHalo = try pixel(image, center, center - 33)
        #expect(nearHalo.brightness > background.brightness + 0.01, "no cool glow around the disc")
    }

    /// The same contract holds on the night ground — one treatment,
    /// every dark sky.
    @Test
    func moonIsALitObjectOnTheNightGround() throws {
        let tokens = SkyPaletteTokens.night
        let (image, side) = try render(tokens: tokens)
        let center = side / 2
        let left = try pixel(image, center - 26, center)
        let right = try pixel(image, center + 26, center)
        let lit = max(left.brightness, right.brightness)
        let dark = min(left.brightness, right.brightness)
        let background = try pixel(image, 6, 6)
        #expect(lit > dark + 0.10)
        #expect(dark > background.brightness + 0.03)
    }

    /// The daytime moon is a pale ghost, not a coin.
    ///
    /// `moonCore`'s lit limb was `mix(ink, metalHighlight, 0.35)`,
    /// which assumes `ink` is the light pole. True on the jewel
    /// grounds; false on the day grounds, where ink is #1B2350 — so on
    /// a near-white sky the moon rendered as a dark slate disc and
    /// became the single element competing hardest with the five
    /// ornaments.
    ///
    /// Two ways to fail: a dark coin (the defect), or nothing at all
    /// (the overcorrection). This pins both edges.
    @Test(arguments: [PaletteState.firstLight, PaletteState.morning, PaletteState.afternoon])
    func moonIsAPaleGhostOnTheDayGrounds(state: PaletteState) throws {
        let tokens = state.tokens
        let (image, side) = try render(tokens: tokens)
        let center = side / 2
        // Sampled by GEOMETRY, not by brightness. The sibling tests
        // take max/min of the two limbs, which is sound on the jewel
        // grounds where the lit limb is the brighter one — but that
        // heuristic inverts here and silently reads the sky as the
        // moon. `isWaxing: false` lights the LEFT limb; measured on
        // the unfixed code, left was the slate crescent at 0.339 and
        // right the earthshine side at 0.958 against a sky of 0.950.
        let lit = try pixel(image, center - 26, center).brightness
        let dark = try pixel(image, center + 26, center).brightness
        let sky = try pixel(image, 4, 4)

        // Not a coin: the lit limb sits within a quarter of the sky's
        // own brightness, so it reads as pale rather than as an object
        // punched out of the page.
        #expect(
            abs(lit - sky.brightness) < 0.25,
            Comment(rawValue: "\(state.rawValue) lit limb is \(lit) against a sky of "
                + "\(sky.brightness) — that is a coin, not a ghost")
        )
        // Still a moon: the phase is legible, the lit limb clearly
        // separated from the earthshine side.
        #expect(
            lit - dark > 0.03,
            Comment(rawValue: "\(state.rawValue) phase has dissolved — lit \(lit), dark \(dark)")
        )
    }
}
