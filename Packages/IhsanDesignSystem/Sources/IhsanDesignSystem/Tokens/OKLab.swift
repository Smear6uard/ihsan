import SwiftUI

/// A gamma-encoded sRGB value — the raw form every palette-v2 token is
/// stored in. Keeping tokens as plain component triples (rather than
/// opaque `Color` values) lets the contrast tests compute WCAG ratios
/// directly and lets the palette interpolate through OKLab without
/// round-tripping through platform color spaces.
public struct SRGBValue: Sendable, Equatable, Hashable {

    /// Gamma-encoded components in `0...1`.
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Build from a 24-bit hex literal (`0xRRGGBB`).
    public init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    /// The SwiftUI color for this value.
    public var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    /// WCAG 2.1 relative luminance.
    public var relativeLuminance: Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// WCAG contrast ratio against another value.
    public func contrastRatio(against other: SRGBValue) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        let (lighter, darker) = a > b ? (a, b) : (b, a)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// This value converted to OKLab.
    public var oklab: OKLabValue {
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = linear(red), g = linear(green), b = linear(blue)

        let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
        let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
        let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

        let lc = cbrt(l), mc = cbrt(m), sc = cbrt(s)

        return OKLabValue(
            l: 0.2104542553 * lc + 0.7936177850 * mc - 0.0040720468 * sc,
            a: 1.9779984951 * lc - 2.4285922050 * mc + 0.4505937099 * sc,
            b: 0.0259040371 * lc + 0.7827717662 * mc - 0.8086757660 * sc
        )
    }
}

/// A color in the OKLab perceptual space. All palette interpolation
/// happens here — mixing in gamma sRGB produces the muddy midpoints
/// that caused the v1 boundary-snapping workaround; OKLab midpoints
/// stay perceptually on the path between the two endpoints.
public struct OKLabValue: Sendable, Equatable {

    public var l: Double
    public var a: Double
    public var b: Double

    public init(l: Double, a: Double, b: Double) {
        self.l = l
        self.a = a
        self.b = b
    }

    /// Linear interpolation in OKLab. `t == 0` returns `self`,
    /// `t == 1` returns `other`.
    public func mixed(with other: OKLabValue, amount t: Double) -> OKLabValue {
        let clamped = max(0.0, min(1.0, t))
        return OKLabValue(
            l: l + (other.l - l) * clamped,
            a: a + (other.a - a) * clamped,
            b: b + (other.b - b) * clamped
        )
    }

    /// Interpolation in OKLCH — the cylindrical form of OKLab, with
    /// hue traveling the SHORTER arc. Rectangular OKLab mixing pulls
    /// a blue→gold ramp through the achromatic center (the gray dead
    /// zone that kills sky gradients); OKLCH keeps chroma alive along
    /// the way. Endpoints are returned exactly. When either endpoint
    /// is effectively achromatic its hue snaps to the other's so the
    /// arc is well defined.
    public func mixedOKLCH(with other: OKLabValue, amount t: Double) -> OKLabValue {
        let clamped = max(0.0, min(1.0, t))
        if clamped <= 0 { return self }
        if clamped >= 1 { return other }

        let c0 = (a * a + b * b).squareRoot()
        let c1 = (other.a * other.a + other.b * other.b).squareRoot()
        let epsilon = 1e-5
        var h0 = atan2(b, a)
        var h1 = atan2(other.b, other.a)
        if c0 < epsilon { h0 = h1 }
        if c1 < epsilon { h1 = h0 }

        var dh = h1 - h0
        if dh > .pi { dh -= 2 * .pi }
        if dh < -.pi { dh += 2 * .pi }

        let lm = l + (other.l - l) * clamped
        let cm = c0 + (c1 - c0) * clamped
        let hm = h0 + dh * clamped
        return OKLabValue(l: lm, a: cm * cos(hm), b: cm * sin(hm))
    }

    /// Convert back to gamma-encoded sRGB, clamping any slightly
    /// out-of-gamut interpolation results into range.
    public var srgb: SRGBValue {
        let lc = l + 0.3963377774 * a + 0.2158037573 * b
        let mc = l - 0.1055613458 * a - 0.0638541728 * b
        let sc = l - 0.0894841775 * a - 1.2914855480 * b

        let l3 = lc * lc * lc, m3 = mc * mc * mc, s3 = sc * sc * sc

        let r = +4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
        let g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
        let bl = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3

        func gamma(_ c: Double) -> Double {
            let clamped = max(0.0, min(1.0, c))
            return clamped <= 0.0031308
                ? clamped * 12.92
                : 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
        }
        return SRGBValue(red: gamma(r), green: gamma(g), blue: gamma(bl))
    }
}

public extension SRGBValue {

    /// Mix two sRGB values through OKLab — the only sanctioned way to
    /// blend palette tokens. Endpoints are returned exactly, so a
    /// plateau resolution is bit-identical to its canonical state.
    static func mix(_ x: SRGBValue, _ y: SRGBValue, amount t: Double) -> SRGBValue {
        if t <= 0 { return x }
        if t >= 1 { return y }
        return x.oklab.mixed(with: y.oklab, amount: t).srgb
    }

    /// Mix through OKLCH — for gradient STOP generation, where a
    /// blue→warm ramp must hold its chroma instead of graying out in
    /// the middle. Token-state blending stays on `mix`.
    static func mixOKLCH(_ x: SRGBValue, _ y: SRGBValue, amount t: Double) -> SRGBValue {
        if t <= 0 { return x }
        if t >= 1 { return y }
        return x.oklab.mixedOKLCH(with: y.oklab, amount: t).srgb
    }

    /// A copy with its OKLab lightness scaled by `factor` (< 1 darkens,
    /// > 1 lightens) while hue and chroma stay put. Used for tonal
    /// siblings like the below-horizon ground plane, which must read as
    /// "the same material, deeper" rather than a new color. Lightness
    /// is capped short of both poles so no derived value can become
    /// pure black or pure white.
    func scalingLightness(by factor: Double) -> SRGBValue {
        var lab = oklab
        lab.l = max(0.02, min(0.98, lab.l * factor))
        return lab.srgb
    }
}
