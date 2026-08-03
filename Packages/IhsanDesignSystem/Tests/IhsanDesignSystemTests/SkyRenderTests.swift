import CoreGraphics
import SwiftUI
import Testing
@testable import IhsanDesignSystem

/// The discipline gate for corrective H, measured on pixels rather
/// than on tokens.
///
/// Item 1 roughly tripled the perceptual distance the day sky ramp has
/// to travel. Everything else in this pass — the gold dust, the raised
/// engraving, the deeper ground band — is laid on top of that ramp.
/// Two things can go wrong at the pixel level and neither shows up in
/// a token audit: the longer ramp can band, and the added marks can
/// stop working once colour is removed. These render the real view and
/// check both.
@MainActor
struct SkyRenderTests {

    private static let width = 393
    private static let height = 420

    /// A rendered sky, as relative-luminance rows.
    private struct Render {
        let width: Int
        let height: Int
        let pixels: [UInt8]   // RGBA8

        func luminance(x: Int, y: Int) -> Double {
            let offset = (y * width + x) * 4
            func channel(_ raw: UInt8) -> Double {
                let c = Double(raw) / 255.0
                return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(pixels[offset])
                + 0.7152 * channel(pixels[offset + 1])
                + 0.0722 * channel(pixels[offset + 2])
        }
    }

    private func render(_ state: PaletteState) throws -> Render {
        // A fixed-state phase and a high sun: no horizon bloom, no
        // dawn wash, so the column measures the RAMP and the marks laid
        // on it, not a transient light.
        let renderer = ImageRenderer(
            content: CelestialSkyView(
                phase: .fixed(state),
                sunAltitudeDegrees: 55
            )
            .frame(width: CGFloat(Self.width), height: CGFloat(Self.height))
        )
        renderer.scale = 1
        let image = try #require(renderer.cgImage, "\(state) sky failed to render")

        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Render(width: width, height: height, pixels: pixels)
    }

    /// The default horizon sits at 0.62 of the height; every sample
    /// stops above the band so the terrain filament never enters it.
    private func skyLimit(_ render: Render) -> Int {
        Int(Double(render.height) * 0.52)
    }

    /// Statistics down one column of sky, above the horizon band.
    private func column(_ render: Render, atFraction x: Double) -> [Double] {
        let column = Int(Double(render.width) * x)
        return (0..<skyLimit(render)).map { render.luminance(x: column, y: $0) }
    }

    /// Row means down the sky. Banding is a property of a ROW — the
    /// ramp is horizontally uniform, so a band is a step every pixel
    /// in a row takes together. A single column cannot tell a band
    /// from a fleck of gold dust sitting on it, and an early version
    /// of this test duly failed on the dust it was supposed to be
    /// ignoring. Averaging across the row cancels the speckle (it is
    /// sparse and unsigned-random) and leaves the ramp.
    private func rowMeans(_ render: Render) -> [Double] {
        (0..<skyLimit(render)).map { y in
            var total = 0.0
            for x in 0..<render.width {
                total += render.luminance(x: x, y: y)
            }
            return total / Double(render.width)
        }
    }

    /// The day ramp does not band. The zenith→horizon journey is long
    /// now, and it is drawn as a stop table with straight
    /// interpolation between OKLCH samples, so this is the measurement
    /// that says whether 17 stops were enough.
    ///
    /// Over a 218 px sky a perfectly even ramp spanning the full 0.32
    /// luminance range steps ~0.0015 a row. The bound is set an order
    /// of magnitude above that: anything larger is a stop boundary
    /// showing through, which is exactly what banding is.
    @Test(arguments: [PaletteState.morning, PaletteState.afternoon])
    func dayRampDoesNotBand(state: PaletteState) throws {
        let means = rowMeans(try render(state))
        var maxStep = 0.0
        var worstRow = 0
        for (row, pair) in zip(means, means.dropFirst()).enumerated() {
            let step = abs(pair.1 - pair.0)
            if step > maxStep {
                maxStep = step
                worstRow = row
            }
        }
        #expect(
            maxStep <= 0.015,
            "\(state.rawValue) sky steps \(maxStep) in mean luminance at row \(worstRow) — a band"
        )
        print(String(
            format: "🎚 %@ ramp: worst row-to-row step %.5f at row %d",
            state.rawValue, maxStep, worstRow
        ))
    }

    /// The sky is a real gradient, not a flat field with a tint at the
    /// top. This is item 1's acceptance, measured: top-to-horizon the
    /// day sky must cover a substantial luminance span.
    @Test(arguments: [PaletteState.morning, PaletteState.afternoon])
    func daySkyCoversARealValueSpan(state: PaletteState) throws {
        let render = try render(state)
        let series = column(render, atFraction: 0.08)
        let span = (series.last ?? 0) - (series.first ?? 0)
        #expect(
            span >= 0.25,
            "\(state.rawValue) sky spans only \(span) in luminance — reads flat"
        )
    }

    /// Nothing in the sky clips. A pure-black or pure-white pixel in a
    /// painted field is a value that has run out of room, and it is
    /// where posterization starts on a real display.
    @Test(arguments: PaletteState.allCases)
    func nothingInTheSkyClips(state: PaletteState) throws {
        let render = try render(state)
        var lowest = 1.0
        var highest = 0.0
        for y in stride(from: 0, to: Int(Double(render.height) * 0.52), by: 3) {
            for x in stride(from: 0, to: render.width, by: 3) {
                let value = render.luminance(x: x, y: y)
                lowest = min(lowest, value)
                highest = max(highest, value)
            }
        }
        #expect(lowest > 0.0005, "\(state.rawValue) sky reaches pure black (\(lowest))")
        #expect(highest < 0.9995, "\(state.rawValue) sky reaches pure white (\(highest))")
    }

    /// The gold dust stays at or below the grain's presence — the
    /// acceptance criterion the brief states, measured as ink budget.
    ///
    /// "Presence" here is total ink laid on the field: marks × alpha ×
    /// area. That is the quantity the eye integrates when it decides
    /// whether a field is textured, and it is what separates a scatter
    /// of glints from a screen. Computed from the constants rather
    /// than from pixels, so it cannot drift silently when either
    /// density is retuned.
    @Test
    func goldDustLaysLessInkThanTheGrain() {
        // Reference field: the sky region of a phone-width plate.
        let width = 393.0
        let skyHeight = 300.0
        let area = width * skyHeight

        let grainMarks = area / PlateGrainOverlay.markArea
        // Grain squares are 0.7–1.5 pt on a side, alpha 0.4–1.0 of the
        // intensity — both uniform, so the means are the midpoints.
        let grainInk = grainMarks
            * (PlateGrainOverlay.dayIntensity * 0.7)
            * pow(1.1, 2)

        let dustMarks = area / CelestialSkyView.goldDustMarkArea
        // Radii 0.35–0.90 pt (mean 0.625), weights 0.34 + 0.66·u^2.2
        // (mean ≈ 0.546).
        let dustInk = dustMarks
            * (CelestialSkyView.goldDustPeakOpacity * 0.546)
            * (Double.pi * pow(0.625, 2))

        #expect(
            dustInk <= grainInk,
            "gold dust lays \(dustInk) of ink against the grain's \(grainInk) — it is a texture"
        )
        print(String(
            format: "✨ ink budget — dust %.2f, grain %.2f (%.0f%% of grain)",
            dustInk, grainInk, 100 * dustInk / grainInk
        ))
    }

    /// The grayscale value check for the speckle field: with colour
    /// removed, the sky must still read as material rather than noise,
    /// and no single fleck may be bright enough to read as an object
    /// in its own right.
    @Test
    func skySpeckleStaysInTheMaterialRegister() throws {
        let render = try render(.morning)
        let limit = skyLimit(render)
        var deviations: [Double] = []
        for y in 2..<(limit - 2) {
            for x in stride(from: 4, to: render.width - 4, by: 1) {
                // Local ramp = the vertical neighbours; any departure
                // from it is a mark (grain or dust), not the sky.
                let expected = (render.luminance(x: x, y: y - 2)
                    + render.luminance(x: x, y: y + 2)) / 2
                deviations.append(abs(render.luminance(x: x, y: y) - expected))
            }
        }
        let mean = deviations.reduce(0, +) / Double(deviations.count)
        let peak = deviations.max() ?? 0
        #expect(mean < 0.004, "sky field roughness \(mean) reads as texture, not material")
        #expect(peak < 0.09, "a single speckle deviates \(peak) — too bright to be a glint")
        print(String(
            format: "🌾 morning sky speckle: mean deviation %.5f, peak %.5f",
            mean, peak
        ))
    }
}
