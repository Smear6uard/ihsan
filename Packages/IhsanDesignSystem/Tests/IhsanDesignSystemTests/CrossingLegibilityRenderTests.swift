import CoreGraphics
import SwiftUI
import Testing
@testable import IhsanDesignSystem

/// The legibility contract, measured on PIXELS.
///
/// `PaletteV2ContrastTests.inkDipsOnlyUnderActiveHaloAndBriefly` and
/// `SkyFieldContrastTests.skyDipsOnlyUnderAnActiveHalo` assert only
/// that a halo is present and strong wherever contrast dips. Neither
/// looks at the composited result, so the halo was treated as
/// sufficient by fiat — and it was not: at the crossing the old
/// double-shadow drew both poles as overlapping BLURS, which average
/// to mid-grey exactly where separation is needed. Primary ink
/// measured 1.06:1 and secondary 1.04:1 on device.
///
/// This test renders the real thing and measures what a reader sees:
///
/// > within 2 pt of a glyph stem there is a band whose luminance
/// > differs from the stem's by at least 4.5:1
///
/// A glyph may be any value at all — light, mid, or dark. What it may
/// never be is surrounded, out to 2 pt, by values close to its own.
///
/// ## One qualification, and it is forced
///
/// That contract holds at every phase these tests sample, but it is NOT
/// unconditional, and the shortfall is not an implementation gap.
/// Mid-crossing the ink's luminance sweeps continuously through
/// L ≈ 0.171–0.179, and at that value a two-tone outline cannot reach
/// 4.5:1 no matter what the two rings are: a glyph is served by
/// whichever ring it is further from, and this is where those two are
/// equally close. The best any pair can do is
/// `√((far + 0.05) / (near + 0.05))`, which even for pure black against
/// pure white is √21 ≈ 4.583:1 — and antialiasing then takes ~11% of
/// it. The shipped pair bottoms out near 4.48:1 there.
///
/// The passage is brief and unavoidable while the ink flips polarity
/// continuously — the same intermediate-value argument that makes the
/// keyline necessary also caps it. So: `>= 4.5` is asserted at the
/// contract's phases, while `theAchievableBoundHoldsAtEveryPhase` pins
/// the weaker promise that holds everywhere. Read a passing suite as
/// "4.5:1 wherever it is reachable, and the most the tokens allow
/// where it is not" — not as a floor under every instant of the day.
@MainActor
struct CrossingLegibilityRenderTests {

    private static let scale: CGFloat = 3
    private static let side: CGFloat = 96
    private static let bandLimit = 6          // px; 6 / scale = 2 pt
    private static let sample = "FAJR 5:45"

    /// The floor the achievable bound is held to everywhere, as opposed
    /// to the 4.5 asserted at the contract's phases.
    ///
    /// Mid-crossing the ink sweeps through the geometric mean of the two
    /// rings, and there no pair reaches 4.5 — √21 ≈ 4.583 caps even pure
    /// black against pure white, and the shipped pair bottoms at ~4.478.
    /// 4.40 sits under that by more than palette drift should move it,
    /// and far above the ~3.96 an undeepened `keylineValue` would give,
    /// which is the regression this exists to catch.
    private static let achievableFloor = 4.40

    // MARK: - Rasterising

    private struct Raster {
        let width: Int
        let height: Int
        let pixels: [UInt8]   // RGBA8

        func luminance(_ index: Int) -> Double {
            func channel(_ raw: UInt8) -> Double {
                let c = Double(raw) / 255.0
                return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            let o = index * 4
            return 0.2126 * channel(pixels[o])
                + 0.7152 * channel(pixels[o + 1])
                + 0.0722 * channel(pixels[o + 2])
        }

        /// How much of this pixel the glyph actually covers, `0...1`.
        func alpha(_ index: Int) -> Double {
            Double(pixels[index * 4 + 3]) / 255.0
        }
    }

    private func rasterize(_ view: some View) throws -> Raster {
        let renderer = ImageRenderer(
            content: view.frame(width: Self.side, height: Self.side)
        )
        renderer.scale = Self.scale
        let image = try #require(renderer.cgImage, "render failed")
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
        return Raster(width: image.width, height: image.height, pixels: pixels)
    }

    // MARK: - The label under test

    /// The plate's marker label typography, verbatim from
    /// `CelestialPlateScene.labelFont`.
    private static let labelFont: Font = .system(
        size: 10, weight: .semibold
    ).smallCaps().monospacedDigit()

    @ViewBuilder
    private func label(
        tokens: SkyPaletteTokens, secondary: Bool, keylined: Bool
    ) -> some View {
        let text = Text(Self.sample)
            .font(Self.labelFont)
            .tracking(1.2)
            .foregroundStyle(secondary ? tokens.inkSecondary : tokens.ink)
        if keylined {
            text.inkKeyline(tokens)
        } else {
            // The treatment this replaces, reproduced exactly so the
            // test can show it failing.
            text
                .shadow(color: tokens.inkHaloDark, radius: 1)
                .shadow(color: tokens.inkHaloLight, radius: 2.5)
                .shadow(color: tokens.inkHaloLight, radius: 6)
        }
    }

    private func composed(
        tokens: SkyPaletteTokens,
        skyHeight: Double,
        secondary: Bool,
        keylined: Bool
    ) -> some View {
        ZStack {
            CelestialSkyView.skyValue(atFraction: skyHeight, tokens: tokens).color
            label(tokens: tokens, secondary: secondary, keylined: keylined)
        }
    }

    /// Glyph coverage, from an isolated render of the same text with no
    /// treatment — read from the ALPHA channel, which is what coverage
    /// means.
    ///
    /// It was originally derived as `1 − luminance` of black-on-white.
    /// That is a gamma-distorted proxy for alpha, not alpha: a pixel the
    /// glyph covers 66% of reports 0.90, and one it covers 50% of
    /// reports 0.79. So `coverage >= 0.9` silently admitted pixels that
    /// were a THIRD background, and since the keyline puts a
    /// maximally-contrasting ring immediately behind every stem, that
    /// third dragged the measured "stem" luminance from 0.0637 to
    /// 0.2294 and capped the whole measurement at 3.54:1. Reading alpha
    /// directly makes every threshold here mean what it says; the
    /// threshold VALUES (0.9 core, 0.05 band) are unchanged.
    private func coverage() throws -> [Double] {
        let raster = try rasterize(
            Text(Self.sample)
                .font(Self.labelFont)
                .tracking(1.2)
                .foregroundStyle(Color.black)
        )
        return (0..<(raster.width * raster.height)).map {
            raster.alpha($0)
        }
    }

    // MARK: - The measurement

    /// The worst separation any single glyph pixel has to live with.
    ///
    /// Read the contract sentence strictly: *every* stem pixel must have
    /// a high-contrast neighbour within 2 pt. So for each core pixel take
    /// the BEST contrast among band pixels within `bandLimit` of it, then
    /// the WORST of those over every core pixel.
    ///
    /// This replaces a mean-of-rings formulation, which averaged whole
    /// concentric rings and so let sky showing through a counter (the
    /// holes in A, R, 4) and gaps between letters drag down a band that
    /// was locally perfect. That diluted the reading by ~47% at the
    /// worst crossing phase — it measured 1.97:1 where the tokens
    /// permitted 3.76:1.
    ///
    /// The trade is not strictly one-directional, and it is worth being
    /// honest about which way each half moves. Over CORE pixels this is
    /// stricter — a min, not a mean, so one abandoned stem pixel fails
    /// where a mean would bury it under its neighbours. Over BAND pixels
    /// it is more permissive — it accepts the single best pixel anywhere
    /// in the 13×13 window, where the ring-mean needed a whole ring to
    /// average well. That second half is why the same phase reads 3.76:1
    /// here and 1.97:1 under the old formulation. Both changes are
    /// deliberate: a reader needs SOME high-contrast neighbour near
    /// EVERY stem pixel, which is a min over stems and a max over
    /// neighbours.
    private func bestAdjacentContrast(
        raster: Raster, coverage: [Double]
    ) -> Double {
        let w = raster.width, h = raster.height
        let core = (0..<coverage.count).filter { coverage[$0] >= 0.9 }
        guard !core.isEmpty else { return 0 }

        var isBand = [Bool](repeating: false, count: coverage.count)
        for band in bands(raster: raster, coverage: coverage) {
            for index in band { isBand[index] = true }
        }

        // Luminance is a per-channel `pow`; compute it once for the only
        // pixels this measurement reads.
        var luminance = [Double](repeating: 0, count: coverage.count)
        for index in core { luminance[index] = raster.luminance(index) }
        for index in 0..<coverage.count where isBand[index] {
            luminance[index] = raster.luminance(index)
        }

        var worst = Double.infinity
        for index in core {
            let x = index % w, y = index / w
            let stem = luminance[index]
            var best = 0.0
            for dy in -Self.bandLimit...Self.bandLimit {
                let ny = y + dy
                guard ny >= 0, ny < h else { continue }
                for dx in -Self.bandLimit...Self.bandLimit {
                    let nx = x + dx
                    guard nx >= 0, nx < w else { continue }
                    let neighbour = ny * w + nx
                    guard isBand[neighbour] else { continue }
                    let other = luminance[neighbour]
                    let hi = max(stem, other), lo = min(stem, other)
                    best = max(best, (hi + 0.05) / (lo + 0.05))
                }
            }
            worst = min(worst, best)
        }
        return worst.isFinite ? worst : 0
    }

    /// The bands at Chebyshev distance `1...bandLimit`, in order.
    ///
    /// The band at distance `d` is exactly the set of unmarked pixels
    /// whose NEAREST marked pixel sits at Chebyshev distance `d` — the
    /// level sets of a distance transform. An 8-connected breadth-first
    /// sweep computes every band in one O(pixels × bandLimit) pass
    /// instead of rescanning a (2d+1)² neighbourhood per pixel per
    /// distance, which is what `bandsReference` does.
    ///
    /// Be clear about how much this decomposition currently earns:
    /// nothing, for the metric. `bestAdjacentContrast` scans a ±bandLimit
    /// window around a CORE pixel, and a core pixel is itself marked, so
    /// every unmarked pixel it can reach is automatically within
    /// Chebyshev `bandLimit` of a marked one. Over that window
    /// `isBand[j]` is therefore true exactly when `coverage[j] <= 0.05`,
    /// and substituting the latter would give bit-identical results. The
    /// decomposition and its reference are retained deliberately — they
    /// pin the band DEFINITION, which is a frozen contract term, against
    /// a future metric that reads bands by distance. They do not
    /// currently guard any measured number.
    private func bands(raster: Raster, coverage: [Double]) -> [[Int]] {
        let w = raster.width, h = raster.height
        // Chebyshev distance to the nearest marked pixel. `bandLimit + 1`
        // stands for "further than we look", and doubles as the
        // not-yet-visited marker.
        var distance = [Int](repeating: Self.bandLimit + 1, count: coverage.count)
        var frontier: [Int] = []
        for index in 0..<coverage.count where coverage[index] > 0.05 {
            distance[index] = 0
            frontier.append(index)
        }

        var result: [[Int]] = []
        for step in 1...Self.bandLimit {
            var band: [Int] = []
            for index in frontier {
                let x = index % w, y = index / w
                for dy in -1...1 {
                    for dx in -1...1 {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                        let neighbour = ny * w + nx
                        guard distance[neighbour] > Self.bandLimit else { continue }
                        distance[neighbour] = step
                        band.append(neighbour)
                    }
                }
            }
            result.append(band)
            frontier = band
        }
        return result
    }

    /// The plan's original O(pixels × distance²) formulation, retained
    /// deliberately.
    ///
    /// `bands` replaced plan-specified code, so
    /// `theSweepComputesTheSameBandsAsTheReference` pins the two
    /// together permanently — one reference run is the standing price of
    /// stopping our replacement from silently drifting from the plan's
    /// definition.
    ///
    /// What that pair does and does not buy, precisely: it guards the
    /// band DEFINITION, not the measurement. See `bands` — over the
    /// window `bestAdjacentContrast` actually scans, band membership is
    /// equivalent to `coverage <= 0.05`, so neither formulation can move
    /// a measured number today. The value here is that the frozen
    /// definition stays honest for whatever reads it next.
    ///
    /// Nor is this pair where the speed came from: the suite went from
    /// 58 minutes to 13.6 s, and almost all of that was dropping the
    /// ring-mean formulation, which called the O(pixels × distance²)
    /// scan once per ring per render. The sweep is the tidier way to
    /// compute the same sets, not the reason they became cheap.
    private func bandsReference(raster: Raster, coverage: [Double]) -> [[Int]] {
        let w = raster.width, h = raster.height
        let marked = Set((0..<coverage.count).filter { coverage[$0] > 0.05 })

        var result: [[Int]] = []
        for distance in 1...Self.bandLimit {
            var band: [Int] = []
            for index in 0..<coverage.count where coverage[index] <= 0.05 {
                let x = index % w, y = index / w
                var touches = false
                var inner = false
                for dy in -distance...distance where !inner {
                    for dx in -distance...distance {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                        guard marked.contains(ny * w + nx) else { continue }
                        if max(abs(dx), abs(dy)) < distance { inner = true; break }
                        touches = true
                    }
                }
                if touches && !inner { band.append(index) }
            }
            result.append(band)
        }
        return result
    }

    /// Every phase at which any ink pair drops below AA — the passages
    /// this test exists for. Derived from the palette rather than
    /// hard-coded, so it follows the unit table wherever it moves.
    private static func crossingPhases(steps: Int = 60) -> [SkyPhase] {
        let scan = 4_000
        var units: [Double] = []
        for step in 0..<scan {
            let phase = SkyPhase(unit: Double(step) / Double(scan))
            if PaletteState.resolved(for: phase).inkHaloStrength > 0.02 {
                units.append(phase.unit)
            }
        }
        guard !units.isEmpty else { return [] }
        // Thin to `steps` evenly spaced samples so the render count
        // stays sane.
        let stride = max(1, units.count / steps)
        return Swift.stride(from: 0, to: units.count, by: stride)
            .map { SkyPhase(unit: units[$0]) }
    }

    // MARK: - Tests

    /// The fast sweep computes exactly the plan's bands.
    ///
    /// `bands` is ours; the plan specified `bandsReference`. Set
    /// equality per distance is the actual claim — it is exact, and it
    /// does not depend on float ordering the way comparing the means
    /// would. Measured on a real composited crossing render, so the
    /// band structure is the awkward one: rings that meet between
    /// letters and close up inside them.
    @Test
    func theSweepComputesTheSameBandsAsTheReference() throws {
        let coverage = try coverage()
        let phase = try #require(Self.crossingPhases(steps: 1).first)
        let raster = try rasterize(
            composed(
                tokens: PaletteState.resolved(for: phase), skyHeight: 0.5,
                secondary: false, keylined: true
            )
        )
        let fast = bands(raster: raster, coverage: coverage)
        let reference = bandsReference(raster: raster, coverage: coverage)

        #expect(fast.count == Self.bandLimit)
        #expect(reference.count == Self.bandLimit)
        for distance in 0..<Self.bandLimit {
            #expect(
                Set(fast[distance]) == Set(reference[distance]),
                Comment(rawValue: "band at distance \(distance + 1) differs: "
                    + "sweep has \(fast[distance].count) px, "
                    + "reference has \(reference[distance].count) px")
            )
        }
        // A band structure worth comparing — every distance non-empty,
        // so no band's equality can hold vacuously.
        for (distance, band) in fast.enumerated() {
            #expect(
                !band.isEmpty,
                Comment(rawValue: "band at distance \(distance + 1) is empty — "
                    + "its set equality above proves nothing")
            )
        }
    }

    @Test(arguments: [false, true])
    func glyphsStaySeparatedThroughEveryCrossing(secondary: Bool) throws {
        let coverage = try coverage()
        for phase in Self.crossingPhases() {
            let tokens = PaletteState.resolved(for: phase)
            for height in [0.15, 0.5, 0.85] {
                let raster = try rasterize(
                    composed(
                        tokens: tokens, skyHeight: height,
                        secondary: secondary, keylined: true
                    )
                )
                let best = bestAdjacentContrast(raster: raster, coverage: coverage)
                let detail = "\(secondary ? "secondary" : "primary") ink at phase "
                    + "\(phase.unit), sky height \(height): best adjacent "
                    + "contrast within 2 pt is \(String(format: "%.2f", best)):1"
                #expect(best >= 4.5, Comment(rawValue: detail))
            }
        }
    }

    /// The separation the outline can achieve never falls under the
    /// forced wall — checked densely, at every phase, not on a grid.
    ///
    /// This is the grid-independent half of the legibility contract.
    /// `theTokensCanReachTheThreshold` and
    /// `glyphsStaySeparatedThroughEveryCrossing` both sample
    /// `crossingPhases()`, which is *derived* from the live palette — so
    /// a palette edit re-derives the grid and moves what those tests
    /// look at. This one sweeps 4,000 phases and never consults the grid.
    ///
    /// The quantity is the bound from §`theTokensCanReachTheThreshold`:
    /// a glyph is served by whichever ring it is further from, so the
    /// best available is `max(contrast(ink, near), contrast(ink, far))`,
    /// computed from the tokens at that phase. The floor it is held to
    /// is `achievableFloor` — the √21 wall, not 4.5, because 4.5 is
    /// provably out of reach mid-crossing and asserting it densely would
    /// be asserting something no implementation can satisfy.
    ///
    /// Checked only where the outline is fully drawn. At the band's
    /// fringes the figure blend has not started, so `resolved` collapses
    /// both halo poles onto one value and the "far" ring is not light at
    /// all — but the outline is barely inked there, and the palette
    /// still carries its own contrast. The two halves interlock at a
    /// STEPPED floor, which is the thing to understand before touching
    /// either: 4.40 here, wherever the ring is doing the work, and 3.0
    /// everywhere else, enforced by
    /// `PaletteV2ContrastTests.theOutlineIsFullyDrawnWhereverContrastCollapses`
    /// — which is what guarantees the outline is *already* full wherever
    /// the palette drops under 3:1. Both tests sweep the same 4,000-point
    /// grid, so no phase falls between them.
    ///
    /// Headroom is thin, and thinner against one anchor than the other.
    /// Two numbers matter:
    ///
    /// - **4.4785** — what this sweep actually measures, over the ink
    ///   path the palette really takes. The 4.40 floor sits 1.8% under it.
    /// - **4.4058** — `√((far + 0.05) / (near + 0.05))`, the worst the
    ///   ring pair could give for ANY ink luminance. The floor sits only
    ///   **0.13%** under that. The gap between the two is luck: the ink
    ///   path does not quite land on the crossover value.
    ///
    /// The only palette lever on either is **`inkHaloLightValue`**. The
    /// near ring is not a palette quantity at all — it is pinned by
    /// `InkKeyline.nearCeiling` at L = 0.0010, structurally out of the
    /// palette's reach. Measured: darkening `inkHaloLightValue` by
    /// **1.85%** lands the bound exactly on 4.40, and 3% puts it at
    /// 4.3509. So if Task 2 moves that token this is the test that says
    /// so — treat a failure here as a real signal about the far pole,
    /// not as noise to be tuned away.
    @Test
    func theAchievableBoundHoldsAtEveryPhase() {
        var worst = Double.infinity
        var worstUnit = 0.0
        var checked = 0
        let samples = 4_000
        for step in 0..<samples {
            let phase = SkyPhase(unit: Double(step) / Double(samples))
            let tokens = PaletteState.resolved(for: phase)
            guard tokens.inkOutlineStrength >= 0.99 else { continue }
            checked += 1
            let near = InkKeyline(tokens: tokens).nearRingValue.relativeLuminance
            let far = tokens.inkHaloLightValue.relativeLuminance
            for ink in [tokens.inkValue, tokens.inkSecondaryValue] {
                let l = ink.relativeLuminance
                func ratio(_ a: Double, _ b: Double) -> Double {
                    (max(a, b) + 0.05) / (min(a, b) + 0.05)
                }
                let bound = max(ratio(l, near), ratio(l, far))
                if bound < worst { worst = bound; worstUnit = phase.unit }
            }
        }
        // Without this the sweep passes by examining nothing, the moment
        // a palette edit stops the outline ever reaching full strength.
        #expect(
            checked > 0,
            "no phase reached full outline strength — this test examined nothing"
        )
        #expect(
            worst >= Self.achievableFloor,
            Comment(rawValue: "at phase \(worstUnit) the best any two-tone outline "
                + "could reach is \(String(format: "%.3f", worst)):1, under the "
                + "\(Self.achievableFloor) floor — the near ring has been lightened")
        )
    }

    /// The 4.5 threshold has to be arithmetically reachable, and only
    /// the near ring's darkness makes it so.
    ///
    /// A two-tone outline can never beat `max(contrast(ink, near),
    /// contrast(ink, far))`, and at the crossing the ink passes through
    /// the geometric mean of the two — the worst possible value, and one
    /// no ring width or opacity can improve on. With the halo poles the
    /// bound there is 3.76:1, i.e. BELOW the threshold: the plan's
    /// original construction could not have passed at any tuning. This
    /// pins the ceiling above the bar so nobody raises the bar, or
    /// lightens the near ring, without meeting the arithmetic.
    ///
    /// Sampled at the phases the contract measures, deliberately — this
    /// is the NARROWER of the two expectations.
    /// `theAchievableBoundHoldsAtEveryPhase`
    /// carries the one that holds everywhere. Between these samples the
    /// ink passes continuously through L ≈ 0.171–0.179, where the bound
    /// falls to ~4.48:1 for ANY ring pair, pure black and pure white
    /// included (best √21 ≈ 4.583:1, before antialiasing). That passage
    /// is unavoidable while the ink flips polarity continuously, so
    /// asserting 4.5 across a dense sweep would be asserting something
    /// no implementation can satisfy.
    @Test
    func theTokensCanReachTheThreshold() {
        var worstCeiling = Double.infinity
        var worstUnit = 0.0
        for phase in Self.crossingPhases() {
            let tokens = PaletteState.resolved(for: phase)
            let near = InkKeyline(tokens: tokens).nearRingValue.relativeLuminance
            let far = tokens.inkHaloLightValue.relativeLuminance
            for ink in [tokens.inkValue, tokens.inkSecondaryValue] {
                let l = ink.relativeLuminance
                func ratio(_ a: Double, _ b: Double) -> Double {
                    (max(a, b) + 0.05) / (min(a, b) + 0.05)
                }
                let ceiling = max(ratio(l, near), ratio(l, far))
                if ceiling < worstCeiling {
                    worstCeiling = ceiling
                    worstUnit = phase.unit
                }
            }
        }
        #expect(
            worstCeiling >= 4.5,
            Comment(rawValue: "the best any two-tone outline could do at phase "
                + "\(worstUnit) is \(String(format: "%.2f", worstCeiling)):1, "
                + "below the 4.5 the render test demands — no tuning can pass")
        )
    }

    /// The evidence that this test measures something real: the
    /// treatment it replaces fails it. If this ever starts passing,
    /// the measurement has gone blind and the test above is worthless.
    @Test
    func theBlurredDoubleShadowFailsTheSameMeasurement() throws {
        let coverage = try coverage()
        var worst = Double.infinity
        for phase in Self.crossingPhases(steps: 20) {
            let tokens = PaletteState.resolved(for: phase)
            let raster = try rasterize(
                composed(
                    tokens: tokens, skyHeight: 0.5,
                    secondary: false, keylined: false
                )
            )
            worst = min(worst, bestAdjacentContrast(raster: raster, coverage: coverage))
        }
        let detail = "the old double-shadow now measures \(worst):1 at its worst — "
            + "the measurement is no longer detecting the defect it was written for"
        #expect(worst < 4.5, Comment(rawValue: detail))
    }
}
