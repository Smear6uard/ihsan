import Foundation
import Testing
@testable import IhsanDesignSystem

// MARK: - WCAG contrast math
//
// Pure sRGB math, no UIKit dependency, so the test runs anywhere the
// package builds. Following WCAG 2.1 §1.4.3 / §1.4.6 luminance formula.

private struct SRGB {
    let r: Double
    let g: Double
    let b: Double

    /// Composite a translucent white over an opaque background.
    static func whiteOver(_ background: SRGB, alpha: Double) -> SRGB {
        SRGB(
            r: alpha + (1 - alpha) * background.r,
            g: alpha + (1 - alpha) * background.g,
            b: alpha + (1 - alpha) * background.b
        )
    }

    /// WCAG relative luminance.
    var relativeLuminance: Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}

private func contrastRatio(_ a: SRGB, _ b: SRGB) -> Double {
    let la = a.relativeLuminance
    let lb = b.relativeLuminance
    let (lighter, darker) = la > lb ? (la, lb) : (lb, la)
    return (lighter + 0.05) / (darker + 0.05)
}

private var ground: SRGB {
    SRGB(
        r: IhsanColor.groundSRGB.red,
        g: IhsanColor.groundSRGB.green,
        b: IhsanColor.groundSRGB.blue
    )
}

private func contrastOfWhite(alpha: Double) -> Double {
    let composite = SRGB.whiteOver(ground, alpha: alpha)
    return contrastRatio(composite, ground)
}

// MARK: - Tests

@Test
func textPrimaryMeetsWCAGAAA() {
    // 100% white on the ground should be >= 7.0 (WCAG AAA for normal text).
    let ratio = contrastOfWhite(alpha: IhsanColor.textPrimaryOpacity)
    #expect(ratio >= 7.0, "textPrimary contrast was \(ratio), expected ≥ 7.0")
}

@Test
func textSecondaryMeetsWCAGAA() {
    // 70% white on the ground should be >= 4.5 (WCAG AA for normal text).
    let ratio = contrastOfWhite(alpha: IhsanColor.textSecondaryOpacity)
    #expect(ratio >= 4.5, "textSecondary contrast was \(ratio), expected ≥ 4.5")
}

@Test
func textMutedMeetsLargeTextThreshold() {
    // 40% white on the ground should be >= 3.0 (WCAG AA for large text only).
    // Anywhere this is used at small sizes is a documented liability — the
    // README anti-patterns section warns against using textMuted for body
    // text.
    let ratio = contrastOfWhite(alpha: IhsanColor.textMutedOpacity)
    #expect(ratio >= 3.0, "textMuted contrast was \(ratio), expected ≥ 3.0")
}

@Test
func atmosphericIsBelowTextThresholds() {
    // 20% atmospheric is intentionally non-readable — used only for hairline
    // separators. We assert it's BELOW the readable threshold so the design
    // system can't accidentally start using it as text.
    let ratio = contrastOfWhite(alpha: IhsanColor.atmosphericOpacity)
    #expect(ratio < 3.0, "atmospheric contrast was \(ratio), should be below text thresholds")
}

@Test
func opacityTiersAreMonotonicallyDecreasing() {
    let p = IhsanColor.textPrimaryOpacity
    let s = IhsanColor.textSecondaryOpacity
    let m = IhsanColor.textMutedOpacity
    let a = IhsanColor.atmosphericOpacity
    #expect(p > s)
    #expect(s > m)
    #expect(m > a)
}

@Test
func opacityTiersMatchSpec() {
    // The 100/70/40/20 tier is the contract — pin the values so a casual
    // tweak shows up as a test failure rather than a silent visual drift.
    #expect(IhsanColor.textPrimaryOpacity == 1.0)
    #expect(IhsanColor.textSecondaryOpacity == 0.70)
    #expect(IhsanColor.textMutedOpacity == 0.40)
    #expect(IhsanColor.atmosphericOpacity == 0.20)
}
