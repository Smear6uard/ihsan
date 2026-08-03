# Corrective I Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make plate text survive the sunrise and maghrib polarity crossings, give first light its own palette state, and fix four smaller defects plus two reported bugs (Path overlay rows, tasbīḥ sequence).

**Architecture:** Six of the seven items live in `IhsanDesignSystem` (tokens, one new modifier, the sky view) and are consumed unchanged by the app and widget targets through `PaletteState.resolved(for:)`. The seventh (tasbīḥ) puts its sequence in `IhsanCore` beside `DhikrPhrase` so the instrument, the intents, and any future surface share one definition. The crossing fix is a `ViewModifier` that replaces three separate ad-hoc shadow treatments with one mechanism, and is verified by a new `ImageRenderer` test that measures composited pixels rather than token pairs.

**Tech Stack:** Swift 6.2 / Swift 6 language mode, SwiftUI, SwiftData, Swift Testing (`@Test`/`#expect`), SwiftPM for the eight local packages, `xcodebuild` for the app targets.

**Spec:** `docs/superpowers/specs/2026-08-02-corrective-i-design.md` — read it before starting. It carries the reasoning; this plan carries the steps.

## Global Constraints

- **Zero build warnings** across every target. The archive must stay clean.
- **Swift 6 language mode, strict concurrency.** New types must be `Sendable`-correct. `ImageRenderer` tests are `@MainActor`.
- **iOS 26 / watchOS 26 minimum.** No availability guards back to older OSes.
- **No new hues.** Every colour is a palette-v2 token. No state may read as tan, beige, parchment, or dusty; the only parchment anywhere is `panelTexture` at ≤ 0.08 opacity.
- **The painted-light ban list** in `Packages/IhsanDesignSystem/README.md` is permanent: no lens flares, horizontal light streaks (any full-width band of light, at the horizon or anywhere else), anamorphic effects, specular hotspots, bokeh, or any camera-artifact rendering. Starbursts are lens renderings.
- **Flat + luminous.** No 3D shading, no specular highlights, no drop shadows on bodies/ornaments/panels. Depth comes from glow, bloom, and layered opacity. The ink legibility treatment is the one sanctioned exception, and after Task 1 it is an *edge*, not a shadow.
- **Discipline gate.** Nothing may compete with the five prayer ornaments or the focused card at a glance. Grayscale value check must pass. 60 fps held. Reduce Motion and Reduce Transparency fallbacks defined for anything new.
- **`IhsanCore` imports no SwiftUI/UIKit/AppKit.** Keep it that way.
- **Coordinates are transient.** Nothing in this plan touches location, but do not introduce persistence of coordinates.
- **Never assert device-only verification from source.** Animation timing, Dynamic Type, VoiceOver pronunciation, Reduce Motion, and on-device colour contrast go in `POLISH_FINDINGS.md` as findings, not as claims.
- **Commit after every task.** Use `git commit` with the trailer `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.

## Working notes

- Package tests: `swift test --package-path Packages/<Name>`. Filter with `--filter <TestTypeName>`.
- App tests: `xcodebuild -project ihsan.xcodeproj -scheme ihsan -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B -only-testing:ihsanTests test`. These are Swift Testing, so XCTest prints "Executed 0 tests" — read the "Test run with N tests" line instead.
- `Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/_Probe.swift` is an **untracked temporary measurement harness** left by the audit. Use it to re-measure plateau spans and dawn/night ratios as you work (`swift test --package-path Packages/IhsanDesignSystem --filter _Probe`). **Delete it before the final commit** — `git status` must be clean of it.

## File Structure

**Create**
| path | responsibility |
|---|---|
| `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Modifiers/InkKeyline.swift` | The one legibility mechanism for text on the sky. Public `.inkKeyline(_:)`. |
| `Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/CrossingLegibilityRenderTests.swift` | Pixel-level proof that glyphs stay separated through both crossings. |
| `ihsanTests/PathPatternContrastTests.swift` | Audits every gestalt dot treatment against the panel it renders on. |
| `Packages/IhsanCore/Sources/IhsanCore/Enums/TasbihSequence.swift` | The after-salah sequence, one definition. |
| `Packages/IhsanCore/Tests/IhsanCoreTests/TasbihSequenceTests.swift` | Sequence behaviour. |

**Modify**
| path | change |
|---|---|
| `.../Tokens/SkyPhase.swift` | `inkOutlineStrength`; unit constants; `firstLightEndUnit`; `resolve`; `approximate`; `boundaries`; `blend` plateau switch; `fixed(_:)`; `nightness`; `dawnProgress` |
| `.../Tokens/SkyPalette.swift` | `PaletteState.firstLight`; `SkyPaletteTokens.firstLight`; dawn token rework; `inkOutlineStrength` plumbing in `resolved(for:)` |
| `.../Celestial/CelestialSkyView.swift` | ground filaments yield near the chord |
| `.../Celestial/LuminousBody.swift` | polarity-aware moon lit limb |
| `.../README.md` | the filament rule, in the painted-light section |
| `ihsan/Today/Components/CelestialPlateScene.swift` | `markerLabel`, `sunriseMark`, `nightInscription` → `.inkKeyline`; `lunarDaylightPresence` floor |
| `ihsan/Today/Components/TodayHeader.swift` | delete `legibilityShadowColor()`, adopt `.inkKeyline` |
| `ihsan/Today/Components/FocusedPrayerCard.swift` | sky-borne text → `.inkKeyline` |
| `ihsan/Trajectory/Components/GestaltGrid.swift` | overlay dot values, dhikr bead form, row separation |
| `ihsan/Dhikr/DhikrScreen.swift` | sequence advance |
| `Packages/IhsanCore/Sources/IhsanCore/Enums/DhikrPhrase.swift` | (no change — `TasbihSequence` sits beside it) |
| every `PaletteState.allCases` test suite | six arguments instead of five |
| `POLISH_FINDINGS.md` | corrective-I device checklist |

---

## Task 1: The crossing keyline

**Files:**
- Create: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Modifiers/InkKeyline.swift`
- Create: `Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/CrossingLegibilityRenderTests.swift`
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Tokens/SkyPhase.swift`
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Tokens/SkyPalette.swift`
- Modify: `ihsan/Today/Components/CelestialPlateScene.swift:486-497` (sunriseMark), `:723-732` (nightInscription), `:961-978` (markerLabel)
- Modify: `ihsan/Today/Components/TodayHeader.swift:75`, `:90`, `:235-239`
- Modify: `ihsan/Today/Components/FocusedPrayerCard.swift:279-280`, `:303-304`, `:325-326`, `:581-582`, `:640-642`
- Modify: `ihsan/Today/TodayScreen.swift:992-993`

**Interfaces:**
- Produces: `SkyPhase.inkOutlineStrength: Double`; `SkyPaletteTokens.inkOutlineStrength: Double`; `View.inkKeyline(_ tokens: SkyPaletteTokens) -> some View`.
- Consumes: existing `SkyPaletteTokens.inkHaloDarkValue`, `.inkHaloLightValue`, `.inkHaloStrength`; `SkyPhase.smootherstep`.

- [ ] **Step 1: Write the failing render test**

Create `Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/CrossingLegibilityRenderTests.swift`:

```swift
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
@MainActor
struct CrossingLegibilityRenderTests {

    private static let scale: CGFloat = 3
    private static let side: CGFloat = 96
    private static let bandLimit = 6          // px; 6 / scale = 2 pt
    private static let sample = "FAJR 5:45"

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

    /// Glyph coverage, from an isolated render of the same text with
    /// no treatment: black on white, so coverage = 1 − luminance.
    private func coverage() throws -> [Double] {
        let raster = try rasterize(
            ZStack {
                Color.white
                Text(Self.sample)
                    .font(Self.labelFont)
                    .tracking(1.2)
                    .foregroundStyle(Color.black)
            }
        )
        return (0..<(raster.width * raster.height)).map {
            1.0 - raster.luminance($0)
        }
    }

    // MARK: - The measurement

    /// The best contrast available between the glyph core and any
    /// band within `bandLimit` px of it.
    private func bestAdjacentContrast(
        raster: Raster, coverage: [Double]
    ) -> Double {
        let w = raster.width, h = raster.height
        let core = (0..<coverage.count).filter { coverage[$0] >= 0.9 }
        let marked = Set((0..<coverage.count).filter { coverage[$0] > 0.05 })
        guard !core.isEmpty else { return 0 }

        let coreLuminance = core.map { raster.luminance($0) }
            .reduce(0, +) / Double(core.count)

        var best = 0.0
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
            guard !band.isEmpty else { continue }
            let bandLuminance = band.map { raster.luminance($0) }
                .reduce(0, +) / Double(band.count)
            let hi = max(coreLuminance, bandLuminance)
            let lo = min(coreLuminance, bandLuminance)
            best = max(best, (hi + 0.05) / (lo + 0.05))
        }
        return best
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
                #expect(
                    best >= 4.5,
                    "\(secondary ? "secondary" : "primary") ink at phase "
                    + "\(phase.unit), sky height \(height): best adjacent "
                    + "contrast within 2 pt is \(String(format: "%.2f", best)):1"
                )
            }
        }
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
        #expect(
            worst < 4.5,
            "the old double-shadow now measures \(worst):1 at its worst — "
            + "the measurement is no longer detecting the defect it was written for"
        )
    }
}
```

- [ ] **Step 2: Run it and confirm it fails for the right reason**

```bash
swift test --package-path Packages/IhsanDesignSystem --filter CrossingLegibilityRenderTests
```

Expected: compile error — `inkKeyline` does not exist yet. Comment out the `keylined: true` test temporarily and run `theBlurredDoubleShadowFailsTheSameMeasurement` alone; it must **pass** (i.e. the old treatment genuinely measures below 4.5:1). If it does not, the measurement is wrong — fix the measurement before writing any implementation.

- [ ] **Step 3: Add the strength curve to `SkyPhase`**

In `SkyPhase.swift`, directly after `inkHaloStrength`:

```swift
    /// How strongly the legibility KEYLINE draws right now, `0...1`.
    ///
    /// Deliberately steeper than `inkHaloStrength`: the outline must
    /// already be solid before the ink itself approaches mid-tone, and
    /// may only ramp in the outer margins of the transition band where
    /// contrast is comfortable without it. `inkHaloStrength` is
    /// `sin(π · amount)` over the atmosphere band (±0.035); tripling it
    /// puts full strength across u₀ ± 0.014, which contains the entire
    /// figure flip at u₀ ± 0.005 with room on both sides.
    public var inkOutlineStrength: Double {
        min(1.0, inkHaloStrength * 3.0)
    }
```

- [ ] **Step 4: Plumb it through the tokens**

In `SkyPalette.swift`, beside `inkHaloStrength`'s declaration in `SkyPaletteTokens`:

```swift
    /// How strongly the legibility keyline draws right now, `0...1`.
    /// Zero for every canonical state; nonzero only inside
    /// polarity-crossing transitions. See `SkyPhase.inkOutlineStrength`.
    public var inkOutlineStrength: Double = 0
```

and in `PaletteState.resolved(for:)`, immediately after
`tokens.inkHaloStrength = phase.inkHaloStrength`:

```swift
        tokens.inkOutlineStrength = phase.inkOutlineStrength
```

- [ ] **Step 5: Write the modifier**

Create `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Modifiers/InkKeyline.swift`:

```swift
import SwiftUI

/// The legibility keyline for text standing on the sky.
///
/// At sunrise and maghrib the ink and the ground swap luminance
/// polarity. Both are continuous, so contrast provably passes through
/// 1:1 — no timing avoids it (see `SkyPhase.figureHalfWidth`). The
/// mitigation therefore cannot be a tuned curve; it has to change what
/// the glyph sits on.
///
/// So the glyph stops being the only mark. Through the crossing it
/// gains a hard-edged two-tone outline: the dark keyline immediately
/// against the glyph, a light ring outside that. The rings occupy
/// DIFFERENT PIXELS, which is the whole difference from the blurred
/// double-shadow this replaces — two blurs centred on the same glyph
/// overlap and average to mid-grey exactly where separation is needed.
/// Whatever value the glyph currently holds, one adjacent band is far
/// from it:
///
/// | glyph          | vs dark ring | vs light ring |
/// |----------------|--------------|---------------|
/// | light (jewel)  | ~15:1        | merges        |
/// | mid (crossing) | ~5.3:1       | 3.3:1         |
/// | dark (day)     | 1.2:1        | ~14:1         |
///
/// This is not a new device: it is the palette's own KEYLINE rule —
/// "the fine dark boundary of every gilded form … the dark edge is
/// what makes gold read as gold rather than tan" — applied to text for
/// the one moment it needs it. An edge, not a shadow, so the flat +
/// luminous rule holds.
///
/// Free on a plateau: at strength 0 the content passes through
/// untouched, which is 99% of the day.
///
/// Reduce Motion / Reduce Transparency need no branch — nothing here
/// moves and nothing here is a gradient.
public struct InkKeyline: ViewModifier {

    /// Effective dilation per pole. Chained `.shadow` calls apply to
    /// the ACCUMULATED rendering, so four diagonal offsets at `r`
    /// produce a dense lattice of translated copies reaching ~1.41 · r
    /// on each axis. 0.55 → a ~0.78 pt dark keyline; 0.60 more →
    /// ~1.63 pt to the light ring's outer edge.
    private static let darkOffset: CGFloat = 0.55
    private static let lightOffset: CGFloat = 0.60

    let tokens: SkyPaletteTokens

    public func body(content: Content) -> some View {
        let strength = tokens.inkOutlineStrength
        if strength <= 0.001 {
            content
        } else {
            // Order is the opposite of the visual stacking: each
            // `.shadow` dilates what is already there, so the DARK
            // pole goes on first (hugging the glyph) and the LIGHT
            // pole second (surrounding glyph + keyline).
            Self.dilate(
                Self.dilate(
                    content,
                    color: tokens.inkHaloDarkValue.color.opacity(strength),
                    offset: Self.darkOffset
                ),
                color: tokens.inkHaloLightValue.color.opacity(strength),
                offset: Self.lightOffset
            )
        }
    }

    /// A hard-edged dilation: four diagonal `radius: 0` shadows. Radius
    /// zero means no blur, which is the entire point — a blur is what
    /// fogged the glyph before.
    private static func dilate(
        _ view: some View, color: Color, offset r: CGFloat
    ) -> some View {
        let d = r * 0.7071
        return view
            .shadow(color: color, radius: 0, x: d, y: d)
            .shadow(color: color, radius: 0, x: -d, y: d)
            .shadow(color: color, radius: 0, x: d, y: -d)
            .shadow(color: color, radius: 0, x: -d, y: -d)
    }
}

public extension View {
    /// Keep this text legible through the sunrise and maghrib
    /// crossings. No-op on every palette plateau. Apply to any text
    /// that stands on the sky or the ground — never to text on a
    /// panel, which has its own fill.
    func inkKeyline(_ tokens: SkyPaletteTokens) -> some View {
        modifier(InkKeyline(tokens: tokens))
    }
}
```

- [ ] **Step 6: Run the render test**

```bash
swift test --package-path Packages/IhsanDesignSystem --filter CrossingLegibilityRenderTests
```

Expected: both tests PASS. If `glyphsStaySeparatedThroughEveryCrossing` still fails, raise `darkOffset` / `lightOffset` in 0.1 steps (the rings are too thin for the sample band) — do **not** widen `bandLimit`, which would weaken the contract.

- [ ] **Step 7: Adopt it at every call site**

`ihsan/Today/Components/CelestialPlateScene.swift` — `markerLabel`, replace the three shadows:

```swift
        .inkKeyline(tokens)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
```

`sunriseMark`'s inscription, replace the two shadows with `.inkKeyline(tokens)` (keep it after `.fixedSize()` and before `.frame(...)`).

`nightInscription`, replace `.shadow(color: tokens.inkHalo, radius: 2)` with `.inkKeyline(tokens)`.

`ihsan/Today/Components/TodayHeader.swift` — delete `legibilityShadowColor()` entirely, delete `let shadowColor = legibilityShadowColor()`, delete the `shadowColor:` parameter from `inscriptionLine`, and replace each `.shadow(color: shadowColor, radius: 2, x: 0, y: 0.5)` with `.inkKeyline(tokens)`.

`ihsan/Today/Components/FocusedPrayerCard.swift` and `ihsan/Today/TodayScreen.swift` — replace each `.shadow(color: tokens.inkHaloDark, …) .shadow(color: tokens.inkHaloLight, …)` pair (and the trailing r=6 where present) with a single `.inkKeyline(tokens)`.

Leave the `ihsan/Repair/**` `.shadow(color: tokens.inkHalo, radius: 2)` sites alone — those print on panels, not on the sky.

- [ ] **Step 8: Build and check for warnings**

```bash
xcodebuild -project ihsan.xcodeproj -scheme ihsan \
  -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B build 2>&1 | grep -E "warning:|error:" | sort -u
```

Expected: no output.

- [ ] **Step 9: Check the render loop still holds 60 fps**

```bash
swift test --package-path Packages/IhsanDesignSystem --filter RenderPerformanceTests
```

Expected: PASS. The keyline adds eight shadow layers per label, but only inside the crossing windows.

- [ ] **Step 10: Commit**

```bash
git add Packages/IhsanDesignSystem ihsan/Today
git commit -m "corrective-i: the crossing keyline

The blurred double-shadow drew both halo poles centred on the same
glyph, so they averaged to mid-grey exactly where separation was
needed — primary ink measured 1.06:1 at sunrise, secondary 1.04:1.
Replaces it with a hard-edged two-tone outline: dark keyline hugging
the glyph, light ring outside it, in different pixels. TodayHeader's
separate white-0.42/black-0.48 mechanism is deleted; one mechanism
now covers every surface that prints on the sky.

CrossingLegibilityRenderTests measures composited pixels through both
crossings, and pins that the old treatment fails the same measurement.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `PaletteState.firstLight`

**Files:**
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Tokens/SkyPhase.swift`
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Tokens/SkyPalette.swift`
- Modify: `Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/SkyPhaseTests.swift:85`

**Interfaces:**
- Consumes: Task 1's `inkOutlineStrength` plumbing.
- Produces: `PaletteState.firstLight`; `SkyPhase.firstLightEndUnit`; `SkyPaletteTokens.firstLight`; six-member `PaletteState.allCases`.

- [ ] **Step 1: Write the failing phase tests**

Append to `Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/SkyPhaseTests.swift`:

```swift
    // MARK: - First light

    /// The morning gets a chapter, not just a boundary. The evening
    /// has both (maghrib the boundary, sunset the state); before this
    /// the morning's equivalent moment owned no tokens at all.
    @Test
    func firstLightHoldsItsOwnPlateau() {
        let phase = SkyPhase.fixed(.firstLight)
        let mix = phase.blend
        #expect(mix.amount == 0, "firstLight's fixed phase is not on a plateau")
        #expect(mix.from == .firstLight)
        #expect(PaletteState.resolved(for: phase) == SkyPaletteTokens.firstLight)
    }

    /// Every transition band must be disjoint, or two boundaries would
    /// blend at once and a state could lose its plateau entirely.
    @Test
    func noTwoTransitionBandsOverlap() {
        let centres = [
            SkyPhase.fajrUnit, SkyPhase.sunriseUnit, SkyPhase.firstLightEndUnit,
            SkyPhase.solarNoonUnit, SkyPhase.maghribUnit, SkyPhase.ishaUnit
        ]
        for (a, b) in zip(centres, centres.dropFirst()) {
            #expect(
                b - a > 2 * SkyPhase.atmosphereHalfWidth,
                "boundaries at \(a) and \(b) are closer than a full band apart"
            )
        }
        // The night wraps.
        #expect(
            (SkyPhase.fajrUnit + 1.0) - SkyPhase.ishaUnit > 2 * SkyPhase.atmosphereHalfWidth
        )
    }

    /// The sixth anchor is DERIVED — `SolarDayEvents` gains no field.
    /// First light lasts as long as the dawn that preceded it, capped
    /// so an extreme-latitude dawn cannot swallow the morning.
    @Test
    func firstLightEndMirrorsTheDawnSpan() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        func date(_ h: Int, _ m: Int) -> Date {
            calendar.date(from: DateComponents(
                year: 2026, month: 8, day: 2, hour: h, minute: m
            ))!
        }
        let events = SolarDayEvents(
            fajr: date(4, 14), sunrise: date(5, 45), solarNoon: date(12, 58),
            maghrib: date(20, 8), isha: date(21, 38)
        )
        // 5:45 + (5:45 − 4:14) = 7:16.
        let expected = date(7, 16)
        let resolved = SkyPhase.resolve(at: expected, events: events)
        #expect(
            abs(resolved.unit - SkyPhase.firstLightEndUnit) < 0.002,
            "first light ends at \(resolved.unit), expected \(SkyPhase.firstLightEndUnit)"
        )
        // 6:15 — the moment this state exists for — is on the plateau.
        #expect(SkyPhase.resolve(at: date(6, 15), events: events).blend.amount == 0)
        #expect(SkyPhase.resolve(at: date(6, 15), events: events).blend.from == .firstLight)
    }

    /// firstLight → morning carries NO polarity flip: both are
    /// luminous day states and firstLight's figure roles are morning's
    /// exactly. Only sunrise and maghrib may cross.
    @Test
    func onlySunriseAndMaghribCross() {
        let steps = 4_000
        for step in 0..<steps {
            let phase = SkyPhase(unit: Double(step) / Double(steps))
            guard phase.inkHaloStrength > 0.01 else { continue }
            let nearSunrise = abs(phase.unit - SkyPhase.sunriseUnit) <= SkyPhase.atmosphereHalfWidth
            let nearMaghrib = abs(phase.unit - SkyPhase.maghribUnit) <= SkyPhase.atmosphereHalfWidth
            #expect(
                nearSunrise || nearMaghrib,
                "a polarity crossing appeared at phase \(phase.unit)"
            )
        }
    }
```

- [ ] **Step 2: Run and confirm it fails**

```bash
swift test --package-path Packages/IhsanDesignSystem --filter SkyPhaseTests
```

Expected: compile failure — `PaletteState.firstLight` and `SkyPhase.firstLightEndUnit` do not exist.

- [ ] **Step 3: Rewrite the unit table in `SkyPhase.swift`**

Replace the five unit constants:

```swift
    /// Palette-space positions of the six anchors. Six states need six
    /// boundaries; every adjacent pair sits more than
    /// `2 * atmosphereHalfWidth` apart so no two transition bands
    /// overlap and every state keeps a genuine plateau.
    static let fajrUnit = 0.050
    static let sunriseUnit = 0.160
    /// The morning's mirror of isha: where the first-light chapter
    /// hands over to the settled morning. Derived from the schedule,
    /// not supplied — see `firstLightEnd(for:)`.
    static let firstLightEndUnit = 0.295
    static let solarNoonUnit = 0.400
    static let maghribUnit = 0.650
    static let ishaUnit = 0.875
```

Update the doc comment at the top of the type to the new table:

```swift
/// ```
/// 0.000  deep night        (plateau center)
/// 0.050  fajr              (night → dawn transition center)
/// 0.105  dawn heart        (plateau center)
/// 0.160  sunrise           (dawn → first light transition center)
/// 0.2275 first light       (plateau center)
/// 0.295  first light ends  (first light → morning transition center)
/// 0.3475 mid-morning       (plateau center)
/// 0.400  solar noon        (morning → afternoon transition center)
/// 0.525  mid-afternoon     (plateau center)
/// 0.650  maghrib           (afternoon → sunset transition center)
/// 0.760  sunset heart      (plateau center)
/// 0.875  isha              (sunset → night transition center)
/// ```
```

- [ ] **Step 4: Derive the sixth anchor and use it in `resolve`**

Add above `resolve(at:events:)`:

```swift
    /// Where the first-light chapter ends.
    ///
    /// The evening's sunset chapter is bounded by two real events —
    /// maghrib and isha. The morning has only one, so the closing
    /// anchor is derived: FIRST LIGHT LASTS AS LONG AS THE DAWN THAT
    /// PRECEDED IT. Both spans are governed by the same thing — how
    /// fast the sun's altitude changes at this latitude and season —
    /// so the mirror is astronomical, not arbitrary.
    ///
    /// Capped at 35% of the way to solar noon so a polar dawn, which
    /// can run for hours, cannot swallow the morning.
    static func firstLightEnd(for events: SolarDayEvents) -> Date {
        let dawnSpan = events.sunrise.timeIntervalSince(events.fajr)
        let toNoon = events.solarNoon.timeIntervalSince(events.sunrise)
        let span = min(max(dawnSpan, 0), max(toNoon, 0) * 0.35)
        return events.sunrise.addingTimeInterval(span)
    }
```

In `resolve(at:events:)`, insert the new control point between sunrise and solar noon:

```swift
        for (time, unit) in [
            (events.fajr.timeIntervalSinceReferenceDate, fajrUnit),
            (events.sunrise.timeIntervalSinceReferenceDate, sunriseUnit),
            (firstLightEnd(for: events).timeIntervalSinceReferenceDate, firstLightEndUnit),
            (events.solarNoon.timeIntervalSinceReferenceDate, solarNoonUnit),
            (events.maghrib.timeIntervalSinceReferenceDate, maghribUnit),
            (events.isha.timeIntervalSinceReferenceDate, ishaUnit),
            (events.fajr.timeIntervalSinceReferenceDate + day, fajrUnit + 1.0)
        ] {
```

- [ ] **Step 5: Add the clock anchor to `approximate`**

In `approximate(at:timeZone:)`, insert `7:15` (its sunrise is 6:00 and its fajr 4:45, so the mirror is 6:00 + 1:15):

```swift
        let anchors: [(time: TimeInterval, unit: Double)] = [
            (20.5 * 3600 - 86_400, ishaUnit - 1.0),
            (4.75 * 3600, fajrUnit),
            (6.0 * 3600, sunriseUnit),
            (7.25 * 3600, firstLightEndUnit),
            (13.0 * 3600, solarNoonUnit),
            (19.0 * 3600, maghribUnit),
            (20.5 * 3600, ishaUnit),
            (4.75 * 3600 + 86_400, fajrUnit + 1.0),
        ]
```

Update its doc comment to name the 7:15 anchor.

- [ ] **Step 6: Update `boundaries`, `blend`, and `fixed`**

```swift
    private static let boundaries: [(center: Double, from: PaletteState, to: PaletteState)] = [
        (SkyPhase.fajrUnit, .night, .dawn),
        (SkyPhase.sunriseUnit, .dawn, .firstLight),
        (SkyPhase.firstLightEndUnit, .firstLight, .morning),
        (SkyPhase.solarNoonUnit, .morning, .afternoon),
        (SkyPhase.maghribUnit, .afternoon, .sunset),
        (SkyPhase.ishaUnit, .sunset, .night)
    ]
```

In `blend(halfWidth:)`'s plateau switch:

```swift
        switch u {
        case ..<Self.fajrUnit: return (.night, .night, 0)
        case ..<Self.sunriseUnit: return (.dawn, .dawn, 0)
        case ..<Self.firstLightEndUnit: return (.firstLight, .firstLight, 0)
        case ..<Self.solarNoonUnit: return (.morning, .morning, 0)
        case ..<Self.maghribUnit: return (.afternoon, .afternoon, 0)
        case ..<Self.ishaUnit: return (.sunset, .sunset, 0)
        default: return (.night, .night, 0)
        }
```

In `fixed(_:)`:

```swift
        switch state {
        case .night: return SkyPhase(unit: 0.0)
        case .dawn: return SkyPhase(unit: 0.105)
        case .firstLight: return SkyPhase(unit: 0.2275)
        case .morning: return SkyPhase(unit: 0.3475)
        case .afternoon: return SkyPhase(unit: 0.525)
        case .sunset: return SkyPhase(unit: 0.7625)
        }
```

`nightness` and `dawnProgress` need no edit — both read `fajrUnit` and `sunriseUnit`, which now hold the new values and still mean the same thing.

- [ ] **Step 7: Add the enum case and the token set**

In `SkyPalette.swift`:

```swift
public enum PaletteState: String, CaseIterable, Sendable {
    case night
    case dawn
    case firstLight
    case morning
    case afternoon
    case sunset
```

and in `tokens`:

```swift
        case .firstLight: return .firstLight
```

Add the token set beside the others, after `dawn`:

```swift
    /// First light (sunrise → mid-morning). The morning's answer to
    /// sunset: the evening gets both a boundary and a jewel chapter,
    /// and until this state existed the morning got only the boundary.
    /// The measured target was 6:15 AM — a low sun, a deep sky, gold
    /// on the ground — which used to arrive as a by-product of a
    /// 98-minute blend and now arrives as a page.
    ///
    /// A LUMINOUS DAY STATE, not a jewel one, for two reasons: the
    /// polarity flip stays at sunrise where the sun actually crests,
    /// and — because every figure role here is morning's exactly —
    /// firstLight → morning carries no crossing at all.
    ///
    /// What makes it its own page is therefore atmosphere only: the
    /// deepest day zenith (the sky IS deepest when the sun is low), a
    /// warm gold horizon wash where morning's is cool blue, the day's
    /// richest gold, and a warmer ground band. The ground itself stays
    /// a cool-neutral near-white — palette v2's thesis is that all
    /// saturation lives in the ink, the metal, and the glow, and
    /// golden-hour warmth is exactly the pressure that would break it.
    static let firstLight = SkyPaletteTokens(
        skyZenith: SRGBValue(hex: 0x7FB0F7),
        groundTop: SRGBValue(hex: 0xF6F6F7),
        groundBottom: SRGBValue(hex: 0xF2F1F1),
        groundPlane: SRGBValue(hex: 0xEBDDB8),
        horizonWash: SRGBValue(hex: 0xF6DDB0),
        ink: SRGBValue(hex: 0x1B2350),
        inkSecondary: SRGBValue(hex: 0x3E476B),
        metal: SRGBValue(hex: 0xA07F45),
        metalHighlight: SRGBValue(hex: 0xD8B463),
        leafGold: SRGBValue(hex: 0xC9A048),
        keyline: SRGBValue(hex: 0x1B2350),
        lapis: SRGBValue(hex: 0x2A3780),
        glow: SRGBValue(hex: 0xF0A93C),
        panelFill: SRGBValue(hex: 0xFBFCFE),
        panelStroke: SRGBValue(hex: 0xD8C4A0),
        panelTexture: SRGBValue(hex: 0xD8B463),
        panelTextureOpacity: 0.05,
        positive: SRGBValue(hex: 0x2E6B47),
        attention: SRGBValue(hex: 0xAA3F24),
        inkHalo: SRGBValue(hex: 0xF7F9FC)
    )
```

- [ ] **Step 8: Fix the one hard-coded unit in the existing tests**

`SkyPhaseTests.swift:85` — `SkyPhase(unit: 0.125)` was dawn's old plateau centre:

```swift
        #expect(PaletteState.resolved(for: SkyPhase(unit: 0.105)) == SkyPaletteTokens.dawn)
```

- [ ] **Step 9: Run the design-system suite**

```bash
swift test --package-path Packages/IhsanDesignSystem
```

Expected: PASS. Likely failures and their fixes:
- `daytimeGroundsAreLuminousNotBeige` — add `.firstLight` to its argument array. If `groundTop`/`groundBottom` fail `b <= 0.02` or `l >= 0.93`, cool them until they pass; do not relax the test.
- `noGradientSegmentJumpsAVisibleStep` — firstLight's zenith→groundTop journey is longer than morning's. With `zenithSegmentSamples = 11` the step should measure ≈0.019; if it exceeds 0.035, lighten the zenith rather than adding stops.
- `dayRampNeverReversesOnItsWayDown` — add `.firstLight` to its argument array.
- `flatSkyFallbackKeepsTheSkyBlue` — add `.firstLight`; it must keep `oklab.b <= -0.015`.
- `SkyFieldContrastTests` / `PaletteV2ContrastTests` — `allCases` picks up the sixth state automatically. Any AA/AAA failure means a token needs moving; the ink pair is morning's, so failures point at the zenith or the wash.

- [ ] **Step 10: Re-measure the plateau spans with the probe**

```bash
swift test --package-path Packages/IhsanDesignSystem --filter _Probe 2>&1 | grep -A40 "plateauSpans"
```

Expected, for the Chicago day:

```
dawn        pure 4:43–5:16
sunrise crossing 5:13–6:14
firstLight  pure 6:08–6:53
morning     pure 9:10–11:04
```

Tolerance ±3 min. If `firstLight` pure does not contain 6:15, the unit table is wrong — recheck `firstLightEndUnit`.

- [ ] **Step 11: Run the app tests and the widget build**

```bash
xcodebuild -project ihsan.xcodeproj -scheme ihsan \
  -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B \
  -only-testing:ihsanTests test 2>&1 | tail -30
xcodebuild -project ihsan.xcodeproj -scheme ihsanWidgets \
  -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B build 2>&1 | grep -E "warning:|error:" | sort -u
```

The app suites that iterate `PaletteState.allCases` (`WorshipSurfaceContrastTests`, `PrayerLogSheetContrastTests`, `AdhkarSurfaceContrastTests`, `PageChromeContrastTests`, `ShipPassContrastTests`) now cover six states and must all pass. Widgets consume through `PaletteState.resolved(for:)` and need no edit; their hard-coded `.night` references stay correct.

- [ ] **Step 12: Commit**

```bash
git add Packages/IhsanDesignSystem ihsanTests
git commit -m "corrective-i: first light

The evening had both a boundary (maghrib) and a jewel chapter
(sunset); the morning had only the boundary. Sunrise owned no tokens
at all, so the best-looking moment of the day arrived as a by-product
of a 98-minute blend.

PaletteState.firstLight, on a six-anchor unit table. The closing
anchor is derived, not a new SolarDayEvents field: first light lasts
as long as the dawn that preceded it, capped at 35% of the way to
noon so a polar dawn cannot swallow the morning. A luminous day
state, so the polarity flip stays at sunrise and firstLight → morning
carries no crossing.

Chicago 2026-08-02: sunrise crossing 98 min → 61 min; first light
holds pure 6:08–6:53.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Dawn's own page

**Files:**
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Tokens/SkyPalette.swift` (the `dawn` token set)
- Modify: `Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/PaletteV2ContrastTests.swift`

**Interfaces:**
- Consumes: Task 2's six-state enum.
- Produces: no new API — token values only.

- [ ] **Step 1: Write the failing separation test**

Append to `PaletteV2ContrastTests.swift`:

```swift
    /// Dawn must be its own page, not night with a warm horizon.
    ///
    /// Before corrective I, dawn sat 1.30× night on `groundTop` and
    /// 1.38× on `groundPlane` — inside the noise. At 5:00 AM the plate
    /// read as late night. Night is near-black indigo and sunset is
    /// plum-vermillion; dawn is lapis-violet, and has to be measurably
    /// distinct from BOTH.
    @Test
    func dawnSeparatesFromNight() {
        let night = PaletteState.night.tokens
        let dawn = PaletteState.dawn.tokens
        let pairs: [(String, SRGBValue, SRGBValue, Double)] = [
            ("skyZenith", night.skyZenithValue, dawn.skyZenithValue, 2.0),
            ("groundTop", night.groundTopValue, dawn.groundTopValue, 2.2),
            ("groundBottom", night.groundBottomValue, dawn.groundBottomValue, 3.0),
            ("groundPlane", night.groundPlaneValue, dawn.groundPlaneValue, 1.8),
            ("horizonWash", night.horizonWashValue, dawn.horizonWashValue, 3.0)
        ]
        for (name, nightValue, dawnValue, factor) in pairs {
            let ratio = dawnValue.relativeLuminance / max(nightValue.relativeLuminance, 1e-6)
            #expect(
                ratio >= factor,
                "dawn.\(name) is only \(String(format: "%.2f", ratio))× night's — "
                + "needs at least \(factor)× to read as its own state"
            )
        }
    }

    /// And dawn must be more chromatic than night, so the separation
    /// is a change of colour and not just of brightness.
    @Test
    func dawnIsMoreChromaticThanNight() {
        func chroma(_ value: SRGBValue) -> Double {
            let lab = value.oklab
            return (lab.a * lab.a + lab.b * lab.b).squareRoot()
        }
        #expect(
            chroma(PaletteState.dawn.tokens.groundBottomValue)
                > chroma(PaletteState.night.tokens.groundBottomValue),
            "dawn's ground is no more chromatic than night's"
        )
    }
```

Also add `.dawn` to `jewelGroundsAreDeepAndChromatic`'s argument array:

```swift
    @Test(arguments: [PaletteState.night, PaletteState.dawn, PaletteState.sunset])
```

- [ ] **Step 2: Run and confirm it fails**

```bash
swift test --package-path Packages/IhsanDesignSystem --filter PaletteV2ContrastTests
```

Expected: `dawnSeparatesFromNight` FAILS on `groundTop` (1.51×, needs 2.2×) and `groundPlane` (1.30×, needs 1.8×).

- [ ] **Step 3: Lift dawn's atmosphere**

In `SkyPalette.swift`, replace the `dawn` token set's atmosphere values and lift `panelFill` with them so panels do not sink into the brighter ground:

```swift
    /// Dawn (fajr → sunrise). Twilight as its own state, not a blend
    /// artifact — and after corrective I, a genuinely different page
    /// from the two states it sits between. Night is near-black
    /// indigo; sunset is plum-vermillion; dawn is LAPIS-VIOLET, the
    /// brightest jewel ground after sunset, lightening toward a
    /// horizon that carries the first warmth without ever entering
    /// sunset's vermillion. Dawn and dusk share their optics; they
    /// must not share a page.
    ///
    /// The last stars are still out, the sun is below the chord with
    /// only its growing glow, and the polarity flip to the luminous
    /// first-light ground happens at sunrise, as it does in the sky.
    static let dawn = SkyPaletteTokens(
        skyZenith: SRGBValue(hex: 0x131A45),
        groundTop: SRGBValue(hex: 0x1B2456),
        groundBottom: SRGBValue(hex: 0x2F3670),
        groundPlane: SRGBValue(hex: 0x12173C),
        horizonWash: SRGBValue(hex: 0x6A5590),
        ink: SRGBValue(hex: 0xEDEFF6),
        inkSecondary: SRGBValue(hex: 0xB6BCD2),
        metal: SRGBValue(hex: 0xC9A96A),
        metalHighlight: SRGBValue(hex: 0xE8D5A3),
        leafGold: SRGBValue(hex: 0xD2AC5C),
        keyline: SRGBValue(hex: 0x10163A),
        lapis: SRGBValue(hex: 0x3B4685),
        glow: SRGBValue(hex: 0xF3C77F),
        panelFill: SRGBValue(hex: 0x232C63),
        panelStroke: SRGBValue(hex: 0x6E645F),
        panelTexture: SRGBValue(hex: 0xE8D5A3),
        panelTextureOpacity: 0.04,
        positive: SRGBValue(hex: 0x9BC7A9),
        attention: SRGBValue(hex: 0xEBA98F),
        inkHalo: SRGBValue(hex: 0x12173C)
    )
```

Note the three figure-role lifts that ride with the ground: `inkSecondary` `#AEB4CB → #B6BCD2`, `positive` `#8FBF9F → #9BC7A9`, `attention` `#E59A82 → #EBA98F`. Each was under 5.5:1 against the old ground and would drop below AA against the new one.

- [ ] **Step 4: Run the whole design-system suite**

```bash
swift test --package-path Packages/IhsanDesignSystem
```

Expected: PASS. If any dawn pair lands under AA, lift that figure token one step — never darken the ground back.

`MoonTreatmentTests` renders on `SkyPaletteTokens.dawn` and its earthshine derives from `groundTop`, which just moved. If its glow-lift or earthshine assertion fails, adjust the *test's* threshold only if the moon still visibly reads as a lit object; otherwise the token moved too far.

- [ ] **Step 5: Run the app suite**

```bash
xcodebuild -project ihsan.xcodeproj -scheme ihsan \
  -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B \
  -only-testing:ihsanTests test 2>&1 | tail -30
```

`AdhkarSurfaceContrastTests:153` reads `PaletteState.dawn.tokens` directly — expect it to exercise the new values.

- [ ] **Step 6: Commit**

```bash
git add Packages/IhsanDesignSystem
git commit -m "corrective-i: dawn gets its own page

Dawn sat 1.30x night's luminance on groundTop and 1.38x on
groundPlane — inside the noise — so 5:00 AM read as late night with a
warm horizon. Night is near-black indigo, sunset is plum-vermillion;
dawn is now lapis-violet, measurably distinct from both. groundTop
2.8x, groundBottom 3.8x, groundPlane 2.2x, chroma up across the set.
inkSecondary, positive, and attention lift with it to hold AA.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: The filaments yield

**Files:**
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Celestial/CelestialSkyView.swift:404-428`
- Modify: `Packages/IhsanDesignSystem/README.md` (painted-light section)
- Modify: `Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/EngravedFilamentTests.swift`

**Interfaces:**
- Produces: `CelestialSkyView.groundEngravingPresence(sunAltitudeDegrees:) -> Double` (internal, so the test can audit it).

- [ ] **Step 1: Write the failing test**

Append to `Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/EngravedFilamentTests.swift`:

```swift
    /// The engraving yields to the light.
    ///
    /// The three worked-earth filaments are linework, not light — they
    /// are identical at midnight. But when the sun sits on the chord
    /// its bloom lights them, and three parallel full-width marks
    /// around a light source read as RAYS, which is precisely what the
    /// painted-light ban exists to prevent. They therefore recede as
    /// the sun approaches the chord, on the same proximity term the
    /// bloom itself uses so the two can never disagree.
    @Test
    func groundEngravingRecedesWhenTheSunSitsOnTheChord() {
        let high = CelestialSkyView.groundEngravingPresence(sunAltitudeDegrees: 45)
        let onChord = CelestialSkyView.groundEngravingPresence(sunAltitudeDegrees: 0)
        #expect(high > 0.99, "a high sun must leave the engraving untouched")
        #expect(
            onChord < 0.20 * high,
            "with the sun on the chord the engraving is still at "
            + "\(onChord / high) of full strength — it will read as rays"
        )
    }

    /// And it comes back: a sun well below the chord is not lighting
    /// anything, so the worked earth is fully drawn again through the
    /// night.
    @Test
    func groundEngravingReturnsAfterTheSunHasSet() {
        #expect(CelestialSkyView.groundEngravingPresence(sunAltitudeDegrees: -25) > 0.99)
    }

    /// Continuous — no step the eye can catch.
    @Test
    func groundEngravingPresenceIsContinuous() {
        var previous = CelestialSkyView.groundEngravingPresence(sunAltitudeDegrees: -40)
        for tenth in stride(from: -400, through: 900, by: 1) {
            let value = CelestialSkyView.groundEngravingPresence(
                sunAltitudeDegrees: Double(tenth) / 10.0
            )
            #expect(abs(value - previous) < 0.02, "step at altitude \(Double(tenth) / 10.0)")
            previous = value
        }
    }
```

- [ ] **Step 2: Run and confirm it fails**

```bash
swift test --package-path Packages/IhsanDesignSystem --filter EngravedFilamentTests
```

Expected: compile failure — `groundEngravingPresence` does not exist.

- [ ] **Step 3: Add the presence term and apply it**

In `CelestialSkyView.swift`, above the `groundFilaments` block:

```swift
    /// How fully the worked-earth engraving draws, given the sun's
    /// altitude. See `groundEngravingRecedesWhenTheSunSitsOnTheChord`.
    /// Same `exp(-(alt/9)²)` proximity the horizon bloom uses, so the
    /// engraving and the light it yields to always agree.
    nonisolated static func groundEngravingPresence(
        sunAltitudeDegrees: Double
    ) -> Double {
        1.0 - 0.85 * exp(-pow(sunAltitudeDegrees / 9.0, 2))
    }
```

and inside `draw(...)`, immediately before the `for filament in groundFilaments` loop:

```swift
        // The engraving yields to the light. Three parallel full-width
        // marks lit by the sun's own bloom read as rays off it — the
        // one thing the painted-light ban exists to prevent — so as
        // the sun approaches the chord these recede and the ground
        // reads as ground. The terrain chord and its lapis hairline
        // stay: they are the horizon, not a field.
        let engravingPresence = Self.groundEngravingPresence(
            sunAltitudeDegrees: sunAltitudeDegrees
        )
        for filament in groundFilaments {
            let y = horizonY + filament.depth
            guard y < size.height - 4 else { continue }
            context.fill(
                Path(PlateGeometry.filamentPath(
                    in: CGRect(origin: .zero, size: size),
                    horizonY: y,
                    thickness: filament.thickness,
                    insetFraction: filament.inset
                )),
                with: .color(
                    tokens.metalValue.color.opacity(filament.opacity * engravingPresence)
                )
            )
        }
```

(Replace the existing loop body wholesale — only the `.opacity` argument changes.)

- [ ] **Step 4: Run the test**

```bash
swift test --package-path Packages/IhsanDesignSystem --filter EngravedFilamentTests
```

Expected: PASS.

- [ ] **Step 5: Record the rule in the README**

In `Packages/IhsanDesignSystem/README.md`, after the starburst paragraph in the painted-light section:

```markdown
**Engraving yields to light** (corrective I). The three worked-earth
filaments below the chord are linework at constant opacity — identical
at midnight, and not light by any reading. But with the sun sitting on
the chord its bloom lights them, and three parallel full-width marks
around a light source read as rays off it, which is the exact thing
this list bans. So they recede as the sun approaches the horizon, on
the same `exp(-(altitude/9)²)` proximity term the bloom itself uses
(`CelestialSkyView.groundEngravingPresence`). The terrain chord and its
paired lapis hairline stay — they are the horizon, not a field. The
general rule: where engraving and painted light occupy the same pixels,
the engraving yields.
```

- [ ] **Step 6: Commit**

```bash
git add Packages/IhsanDesignSystem
git commit -m "corrective-i: the engraving yields to the light

At 05:45 the three worked-earth filaments read as rays off the sun
sitting on the chord — close enough to the painted-light ban on
horizontal light streaks to need a decision. They now recede on the
same proximity term the bloom uses. Terrain chord and lapis hairline
stay: they are the horizon, not a field. Rule recorded in the README.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: The daytime moon

**Files:**
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Celestial/LuminousBody.swift:239-256`
- Modify: `Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/MoonTreatmentTests.swift`
- Modify: `ihsan/Today/Components/CelestialPlateScene.swift:866-869`

**Interfaces:**
- Produces: `LuminousBody.moonLitValue(tokens:) -> SRGBValue` (internal, so the test audits the exact value).

- [ ] **Step 1: Write the failing day-ground test**

`MoonTreatmentTests.swift` currently renders only on `SkyPaletteTokens.dawn`. Generalise `render` to take tokens (it already does) and append:

```swift
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
        let limbOffset = 26

        let sky = try pixel(image, 4, 4)
        let lit = try pixel(image, center + limbOffset, center)
        let dark = try pixel(image, center - limbOffset, center)

        // Not a coin: the lit limb sits within a quarter of the sky's
        // own brightness, so it reads as pale rather than as an object
        // punched out of the page.
        #expect(
            abs(lit.brightness - sky.brightness) < 0.25,
            "\(state.rawValue) lit limb is \(lit.brightness) against a sky of "
            + "\(sky.brightness) — that is a coin, not a ghost"
        )
        // Still a moon: the phase is legible, the lit limb clearly
        // separated from the earthshine side.
        #expect(
            lit.brightness - dark.brightness > 0.03,
            "\(state.rawValue) phase has dissolved — lit \(lit.brightness), "
            + "dark \(dark.brightness)"
        )
    }
```

(The existing `render` uses `illuminatedFraction: 0.35, isWaxing: false`, which lights the LEFT limb. Confirm which side is lit before fixing the sample offsets; the existing dawn test already samples both and asserts a direction — mirror it.)

- [ ] **Step 2: Run and confirm it fails**

```bash
swift test --package-path Packages/IhsanDesignSystem --filter MoonTreatmentTests
```

Expected: `moonIsAPaleGhostOnTheDayGrounds` FAILS on all three day states — the lit limb is a dark slate far from the sky's brightness.

- [ ] **Step 3: Make the lit limb polarity-aware**

In `LuminousBody.swift`, replace `moonCore`'s first line and add the exposed value:

```swift
    /// The moon's lit limb, per ground polarity.
    ///
    /// On the jewel grounds `ink` IS the light pole (dawn's is
    /// #EDEFF6), so mixing it toward the metal highlight gives the
    /// warm near-white a lit limb should be. On the luminous day
    /// grounds `ink` is the DARK pole and the same formula produced a
    /// slate coin. There the limb is mixed off the sky itself toward
    /// the same warm highlight — a pale warm near-white, barely
    /// separated from the field, which is what a daytime moon is.
    static func moonLitValue(tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.groundBottomValue.relativeLuminance < 0.5
            ? .mix(tokens.inkValue, tokens.metalHighlightValue, amount: 0.35)
            : .mix(tokens.groundTopValue, tokens.metalHighlightValue, amount: 0.30)
    }

    private func moonCore(illuminatedFraction: Double, isWaxing: Bool) -> some View {
        let litColor = Self.moonLitValue(tokens: tokens).color
        let earthshine = onDarkGround
            ? tokens.groundTopValue.scalingLightness(by: 1.35).color
            : tokens.groundTopValue.scalingLightness(by: 0.94).color
        return ZStack {
            // Earthshine: the dark limb barely-there, never bright
            // enough to dissolve the phase. On the day grounds it goes
            // one step DOWN rather than up — the dark limb of a
            // daytime moon is what little the sky is not.
            Circle()
                .fill(earthshine.opacity(onDarkGround ? 0.30 : 0.55))
            CrescentShape(
                illuminatedFraction: illuminatedFraction,
                isWaxing: isWaxing
            )
            .fill(litColor)
            // The defined edge — the one body with a pixel where it
            // stops.
            Circle()
                .strokeBorder(litColor.opacity(0.45), lineWidth: 0.75)
        }
    }
```

- [ ] **Step 4: Lower the daylight presence floor**

In `ihsan/Today/Components/CelestialPlateScene.swift`:

```swift
    /// The moon is a quieter light than the sun: barely there against
    /// a high daytime sky, full strength once the sun is well down.
    /// Floor lowered 0.28 → 0.12 in corrective I — at 0.28 a daylight
    /// moon was still present enough to pull the eye off the five
    /// ornaments, which the discipline gate does not allow.
    private func lunarDaylightPresence(sunAltitudeDegrees: Double) -> Double {
        let t = max(0.0, min(1.0, (6.0 - sunAltitudeDegrees) / 24.0))
        return 0.12 + 0.88 * t
    }
```

- [ ] **Step 5: Run the moon tests**

```bash
swift test --package-path Packages/IhsanDesignSystem --filter MoonTreatmentTests
```

Expected: PASS, including the original `moonIsALitObjectOnTheDawnGround` — the dark-ground branch is byte-for-byte what it was.

- [ ] **Step 6: Run the full design-system suite and the app build**

```bash
swift test --package-path Packages/IhsanDesignSystem
xcodebuild -project ihsan.xcodeproj -scheme ihsan \
  -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B build 2>&1 | grep -E "warning:|error:" | sort -u
```

- [ ] **Step 7: Commit**

```bash
git add Packages/IhsanDesignSystem ihsan/Today
git commit -m "corrective-i: the daytime moon is a ghost, not a coin

moonCore's lit limb was mix(ink, metalHighlight, 0.35) — a formula
that assumes ink is the light pole. True on the jewel grounds, false
on the day grounds where ink is #1B2350, so the daylight moon
rendered as a dark slate disc and competed hardest with the five
ornaments. Now polarity-aware: the dark-ground branch is byte-for-byte
unchanged, so MoonTreatmentTests keeps its pinned intent; the day
branch mixes off the sky. lunarDaylightPresence floor 0.28 -> 0.12.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: The Path overlay rows

**Files:**
- Create: `ihsanTests/PathPatternContrastTests.swift`
- Modify: `ihsan/Trajectory/Components/GestaltGrid.swift`

**Interfaces:**
- Produces: `GestaltGrid.overlayMarkValue(for:) -> SRGBValue` (internal static, so the test audits the exact rendered value).
- Consumes: existing `GestaltDot.qadaBodyValue(for:)`, `.missedOutlineValue(for:)`, `.lateOutlineValue(for:)`.

- [ ] **Step 1: Write the failing test**

Create `ihsanTests/PathPatternContrastTests.swift`:

```swift
import Testing
import IhsanCore
import IhsanDesignSystem
@testable import ihsan

/// The audit `GestaltDot`'s doc comment has always claimed —
/// "static treatment functions expose the exact values so
/// PathPatternContrastTests audits what the dots render" — and which
/// did not exist until corrective I. In its absence the two overlay
/// rows shipped invisible: on the morning panel a "present" dhikr mark
/// composited to 1.52:1 while an EMPTY fardh cell composited to
/// 1.30:1, so "something happened here" and "nothing did" were 0.22
/// apart and both below the threshold of resolution.
struct PathPatternContrastTests {

    private let states = PaletteState.allCases

    /// Composite a mark drawn at `opacity` over the panel it stands on.
    private func composite(
        _ mark: SRGBValue, over panel: SRGBValue, opacity: Double
    ) -> SRGBValue {
        SRGBValue.mix(panel, mark, amount: opacity)
    }

    /// Every mark that means SOMETHING HAPPENED must be resolvable
    /// against the panel it stands on.
    @Test(arguments: PaletteState.allCases)
    func overlayPresenceMarksAreVisible(state: PaletteState) {
        let tokens = state.tokens
        let mark = composite(
            GestaltGrid.overlayMarkValue(for: tokens),
            over: tokens.panelFillValue,
            opacity: GestaltGrid.overlayMarkOpacity
        )
        let ratio = mark.contrastRatio(against: tokens.panelFillValue)
        #expect(
            ratio >= 3.0,
            "\(state.rawValue) overlay presence mark is \(ratio):1 against the "
            + "panel — below the threshold of resolution"
        )
    }

    /// And it must be clearly separated from the mark that means
    /// NOTHING HAPPENED, or the row says nothing at all.
    @Test(arguments: PaletteState.allCases)
    func presenceIsDistinctFromAbsence(state: PaletteState) {
        let tokens = state.tokens
        let present = composite(
            GestaltGrid.overlayMarkValue(for: tokens),
            over: tokens.panelFillValue,
            opacity: GestaltGrid.overlayMarkOpacity
        )
        let unlogged = composite(
            tokens.metalValue, over: tokens.panelFillValue, opacity: 0.28
        )
        #expect(
            present.contrastRatio(against: unlogged) >= 1.8,
            "\(state.rawValue): a present overlay mark and an unlogged fardh "
            + "cell are \(present.contrastRatio(against: unlogged)):1 apart"
        )
    }

    /// The fardh treatments the grid has always drawn, audited for the
    /// first time. Late, missed, and qadā each mean something specific
    /// and each must be resolvable.
    @Test(arguments: PaletteState.allCases)
    func fardhTreatmentsAreResolvable(state: PaletteState) {
        let tokens = state.tokens
        let panel = tokens.panelFillValue
        let cases: [(String, SRGBValue, Double)] = [
            ("late", GestaltDot.lateOutlineValue(for: tokens), 0.95),
            ("missed", GestaltDot.missedOutlineValue(for: tokens), 0.60),
            ("qada", GestaltDot.qadaBodyValue(for: tokens), 1.0),
            ("onTime", tokens.leafGoldValue, 1.0)
        ]
        for (name, value, opacity) in cases {
            let ratio = composite(value, over: panel, opacity: opacity)
                .contrastRatio(against: panel)
            #expect(
                ratio >= 3.0,
                "\(state.rawValue) \(name) dot is \(ratio):1 against the panel"
            )
        }
    }
}
```

- [ ] **Step 2: Run and confirm it fails**

```bash
xcodebuild -project ihsan.xcodeproj -scheme ihsan \
  -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B \
  -only-testing:ihsanTests/PathPatternContrastTests test 2>&1 | tail -40
```

Expected: compile failure (`overlayMarkValue` missing), then after Step 3's signature exists, the *day* states fail `overlayPresenceMarksAreVisible` at ≈1.5:1.

- [ ] **Step 3: Give the overlay marks a real value**

In `GestaltGrid.swift`, add to the `GestaltGrid` struct:

```swift
    /// Opacity every overlay presence mark draws at. The overlay stays
    /// quieter than the fardh rows — visible if sought, quiet if not —
    /// but it has to be VISIBLE when sought, which at the old 0.40 of
    /// plain metal it was not on the near-white days.
    static let overlayMarkOpacity: Double = 0.85

    /// The overlay mark's colour, per panel polarity — the same rule
    /// `GestaltDot.lateOutlineValue` established: plain metal reads on
    /// a jewel panel (~6:1) and vanishes on a near-white one (~2.6:1),
    /// so the day states deepen it toward the keyline. Corrective H
    /// found the same thing for the almucantars: the same alpha buys
    /// less on a near-white field.
    static func overlayMarkValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.panelFillValue.relativeLuminance < 0.5
            ? tokens.metalValue
            : SRGBValue.mix(tokens.metalValue, tokens.keylineValue, amount: 0.45)
    }
```

Replace `NaflOverlayDot` and `DhikrOverlayDot`:

```swift
/// One cell of the optional dhikr row: a small filled BEAD where the
/// day (or week) holds a recorded sitting. A bead, not a ring —
/// the ring is what an unlogged fardh cell already draws, so an
/// outlined dhikr mark said "nothing happened here" in the one row
/// where it means the opposite.
private struct DhikrOverlayDot: View {
    let present: Bool
    let size: CGFloat
    let tokens: SkyPaletteTokens

    var body: some View {
        Group {
            if present {
                Circle()
                    .fill(
                        GestaltGrid.overlayMarkValue(for: tokens).color
                            .opacity(GestaltGrid.overlayMarkOpacity)
                    )
                    .padding(size * 0.26)
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
    }
}

/// One cell of the optional sixth row: a small four-pointed star where
/// the day (or week) holds any voluntary record, empty space where it
/// doesn't. Filled rather than stroked below 8 pt, where a stroke at
/// this scale has no line to draw.
private struct NaflOverlayDot: View {
    let present: Bool
    let size: CGFloat
    let tokens: SkyPaletteTokens

    var body: some View {
        Group {
            if present {
                let tint = GestaltGrid.overlayMarkValue(for: tokens).color
                    .opacity(GestaltGrid.overlayMarkOpacity)
                if size >= 8 {
                    FourPointedStar()
                        .stroke(tint, lineWidth: max(0.9, size * 0.16))
                } else {
                    FourPointedStar().fill(tint)
                }
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
    }
}
```

- [ ] **Step 4: Separate the overlay rows from the fardh rows**

In `GestaltGrid.grid(columns:metrics:)`, wrap the two overlay rows so they read as their own register:

```swift
            if naflColumns != nil || dhikrColumns != nil {
                // The overlay rows are a different register from the
                // five fardh rows — presence, not status. A row at the
                // grid's own spacing read as a sixth prayer.
                Color.clear.frame(height: Self.overlayGap)
            }
```

immediately before the `if let naflColumns` block, and add:

```swift
    /// Gap between the five fardh rows and the presence overlays.
    private static let overlayGap: CGFloat = IhsanSpacing.xs
```

Update `gridHeight` to account for it:

```swift
        let rows = rowCount * dot + (rowCount - 1) * spacing
        let starSize = max(6, min(10, dot + 4))
        let gap = (naflDays == nil && dhikrDays == nil) ? 0 : Self.overlayGap
        return rows + gap + IhsanSpacing.sm + starSize
```

- [ ] **Step 5: Run the test**

```bash
xcodebuild -project ihsan.xcodeproj -scheme ihsan \
  -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B \
  -only-testing:ihsanTests/PathPatternContrastTests test 2>&1 | tail -40
```

Expected: PASS on all six states. If `fardhTreatmentsAreResolvable` fails for `missed` on a day state, that is a genuine pre-existing finding — fix `missedOutlineValue` the same way (`mix` toward keyline on near-white panels) and note it in the commit.

- [ ] **Step 6: Update the accessibility label**

`GestaltGrid.accessibilityLabel` says "A quieter row marks days with recorded dhikr." That is still true; leave it. Confirm `DhikrOverlayDot`'s change did not affect the label.

- [ ] **Step 7: Commit**

```bash
git add ihsan/Trajectory ihsanTests
git commit -m "corrective-i: the Path overlay rows are visible

Measured on the morning panel: a 'present' dhikr mark composited to
1.52:1 and an EMPTY fardh cell to 1.30:1 — the two states of the row
were 0.22 apart and both under the threshold of resolution. The dhikr
mark was also an outlined ring, the identical form an unlogged fardh
cell draws.

Presence marks now take a polarity-aware value with a real floor (the
rule lateOutlineValue already used), the dhikr mark is a filled bead,
and a gap separates the overlay rows from the five fardh rows so they
read as their own register.

Adds PathPatternContrastTests, which GestaltDot's doc comment has
cited since it was written and which did not exist.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: The tasbīḥ sequence

**Files:**
- Create: `Packages/IhsanCore/Sources/IhsanCore/Enums/TasbihSequence.swift`
- Create: `Packages/IhsanCore/Tests/IhsanCoreTests/TasbihSequenceTests.swift`
- Modify: `ihsan/Dhikr/DhikrScreen.swift`

**Interfaces:**
- Produces: `TasbihSequence` — `init(head:)`, `walksTheSequence: Bool`, `phrase(atTotalCount:) -> DhikrPhrase`, `completedCycles(atTotalCount:) -> Int`, `markInCycle(atTotalCount:) -> Int`, `isComplete(atTotalCount:) -> Bool`, `static cycleLength: Int`, `static phrases: [DhikrPhrase]`.
- Consumes: existing `DhikrPhrase`, `SaveDhikrSessionIntent(count:phrase:customPhrase:sessionDate:)`.

- [ ] **Step 1: Write the failing sequence test**

Create `Packages/IhsanCore/Tests/IhsanCoreTests/TasbihSequenceTests.swift`:

```swift
import Testing
@testable import IhsanCore

/// The tasbīḥ after each fard salah — 33 Subḥānallāh, 33
/// Alḥamdulillāh, 33 Allāhu Akbar (Muslim 597).
///
/// The instrument used to hold one phrase for the whole sitting, so
/// from mark 34 onward the label contradicted what the person was
/// actually reciting.
struct TasbihSequenceTests {

    @Test
    func aSittingBegunOnSubhanallahWalksTheThree() {
        let sequence = TasbihSequence(head: .subhanallah)
        #expect(sequence.walksTheSequence)
        #expect(sequence.phrase(atTotalCount: 1) == .subhanallah)
        #expect(sequence.phrase(atTotalCount: 33) == .subhanallah)
        #expect(sequence.phrase(atTotalCount: 34) == .alhamdulillah)
        #expect(sequence.phrase(atTotalCount: 66) == .alhamdulillah)
        #expect(sequence.phrase(atTotalCount: 67) == .allahuAkbar)
        #expect(sequence.phrase(atTotalCount: 99) == .allahuAkbar)
    }

    /// A phrase the person chose to sit on simply continues. The
    /// sequence is a property of the canonical START, not a mode
    /// anyone has to find.
    @Test(arguments: [DhikrPhrase.alhamdulillah, .allahuAkbar, .astaghfirullah, .custom])
    func aSittingBegunElsewhereStaysThere(head: DhikrPhrase) {
        let sequence = TasbihSequence(head: head)
        #expect(!sequence.walksTheSequence)
        #expect(sequence.phrase(atTotalCount: 1) == head)
        #expect(sequence.phrase(atTotalCount: 34) == head)
        #expect(sequence.phrase(atTotalCount: 200) == head)
    }

    @Test
    func theMarkHoldsAt33AtEveryBoundary() {
        let sequence = TasbihSequence(head: .subhanallah)
        #expect(sequence.markInCycle(atTotalCount: 0) == 0)
        #expect(sequence.markInCycle(atTotalCount: 1) == 1)
        #expect(sequence.markInCycle(atTotalCount: 33) == 33)
        #expect(sequence.markInCycle(atTotalCount: 34) == 1)
        #expect(sequence.markInCycle(atTotalCount: 66) == 33)
        #expect(sequence.markInCycle(atTotalCount: 99) == 33)
    }

    @Test
    func completedCyclesCountTheThirds() {
        let sequence = TasbihSequence(head: .subhanallah)
        #expect(sequence.completedCycles(atTotalCount: 32) == 0)
        #expect(sequence.completedCycles(atTotalCount: 33) == 1)
        #expect(sequence.completedCycles(atTotalCount: 66) == 2)
        #expect(sequence.completedCycles(atTotalCount: 99) == 3)
    }

    /// At 99 the three thirds are done. The hundredth that completes
    /// them is a full narrated supplication and lives in the guided
    /// adhkar set, behind the scholar-review gate — the instrument
    /// marks the arrival and does not print unreviewed text.
    @Test
    func theThreeThirdsCompleteAt99() {
        let sequence = TasbihSequence(head: .subhanallah)
        #expect(!sequence.isComplete(atTotalCount: 98))
        #expect(sequence.isComplete(atTotalCount: 99))
        #expect(sequence.isComplete(atTotalCount: 120))
        // A sitting on a single phrase never "completes" — it is not
        // walking a sequence with an end.
        #expect(!TasbihSequence(head: .astaghfirullah).isComplete(atTotalCount: 200))
    }
}
```

- [ ] **Step 2: Run and confirm it fails**

```bash
swift test --package-path Packages/IhsanCore --filter TasbihSequenceTests
```

Expected: compile failure — `TasbihSequence` does not exist.

- [ ] **Step 3: Write the type**

Create `Packages/IhsanCore/Sources/IhsanCore/Enums/TasbihSequence.swift`:

```swift
import Foundation

/// The tasbīḥ after each fard salah: 33 × Subḥānallāh, 33 ×
/// Alḥamdulillāh, 33 × Allāhu Akbar — Muslim 597. The hundredth that
/// completes it ("Lā ilāha illa'llāhu waḥdahu lā sharīka lah…") is the
/// same narration, and lives in the guided adhkar set rather than
/// here: it is a full supplication, and this repo's copy of it sits
/// behind the scholar-review gate in `adhkar-content.json`. Printing
/// it from Swift would route unreviewed text around the gate that
/// exists to stop exactly that. So the instrument marks the arrival at
/// 99 and stops.
///
/// The sequence is a property of the canonical START, not a mode
/// anyone has to find: a sitting begun on Subḥānallāh walks the three;
/// a sitting begun on any other phrase — including the custom slot —
/// stays where the person put it and counts on.
///
/// One definition, in Core, so the instrument, the intents, and any
/// future surface cannot drift into disagreeing about what the tasbīḥ
/// is.
public struct TasbihSequence: Sendable, Equatable {

    public static let cycleLength = 33
    public static let phrases: [DhikrPhrase] = [.subhanallah, .alhamdulillah, .allahuAkbar]

    /// The phrase the sitting opened on.
    public let head: DhikrPhrase

    public init(head: DhikrPhrase) {
        self.head = head
    }

    /// Whether this sitting walks the three thirds.
    public var walksTheSequence: Bool {
        head == Self.phrases[0]
    }

    /// Thirds finished at `total` taps. Uncapped — a single-phrase
    /// sitting keeps accumulating cycles, which is what the three
    /// resting dots have always shown.
    public func completedCycles(atTotalCount total: Int) -> Int {
        max(0, total) / Self.cycleLength
    }

    /// Marks gilded in the current cycle: 1…33, holding at 33 the
    /// moment a cycle completes.
    public func markInCycle(atTotalCount total: Int) -> Int {
        total <= 0 ? 0 : ((total - 1) % Self.cycleLength) + 1
    }

    /// The phrase being recited at `total` taps.
    public func phrase(atTotalCount total: Int) -> DhikrPhrase {
        guard walksTheSequence else { return head }
        let index = max(0, total - 1) / Self.cycleLength
        return Self.phrases[min(index, Self.phrases.count - 1)]
    }

    /// True once all three thirds are done.
    public func isComplete(atTotalCount total: Int) -> Bool {
        walksTheSequence && total >= Self.cycleLength * Self.phrases.count
    }
}
```

- [ ] **Step 4: Run the test**

```bash
swift test --package-path Packages/IhsanCore --filter TasbihSequenceTests
```

Expected: PASS.

- [ ] **Step 5: Drive the instrument from it**

In `ihsan/Dhikr/DhikrScreen.swift`:

Add state for the sitting's head, set on first tap:

```swift
    /// The phrase the sitting opened on. Fixed at the first tap so
    /// swiping mid-sitting cannot retroactively change what the
    /// sequence is.
    @State private var sittingHead: DhikrPhrase?

    private var sequence: TasbihSequence {
        TasbihSequence(head: sittingHead ?? phrase)
    }

    /// The phrase being recited right now — the sitting's own
    /// sequence position while it walks the three, the stored phrase
    /// otherwise.
    private var activePhrase: DhikrPhrase {
        totalCount == 0 ? phrase : sequence.phrase(atTotalCount: totalCount)
    }
```

Replace `filledMarks` / `completedCycles` with the sequence's:

```swift
    private var filledMarks: Int { sequence.markInCycle(atTotalCount: totalCount) }
    private var completedCycles: Int { sequence.completedCycles(atTotalCount: totalCount) }
```

Delete `private static let cycleLength = 33` and use `TasbihSequence.cycleLength` throughout (`ring(count:)`, `count()`, the a11y value).

In `count()`, announce the handover:

```swift
    private func count() {
        if sittingHead == nil { sittingHead = phrase }
        let before = activePhrase
        totalCount += 1
        let position = filledMarks
        let after = activePhrase
        if position == TasbihSequence.cycleLength {
            // The boundary is a worship commit, and wears the same
            // settle every other commit wears.
            Haptics.settle()
        } else {
            Haptics.impact(.light)
        }
        // Spoken waypoints only — the per-tap haptic carries the
        // rhythm (see the type comment). A phrase HANDOVER is the one
        // thing a haptic cannot carry, so it is spoken by name.
        if before != after {
            announce(after.displayTransliteration)
        } else if position == 11 || position == 22 || position == TasbihSequence.cycleLength {
            announce("\(position)")
        }
    }

    private func announce(_ text: String) {
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }
```

Note: `before != after` fires on the tap that lands ON 34/67, i.e. the first mark of the new third. That is the correct moment — the person has already recited the 33rd.

In `phraseRow`, the TabView's selection must follow the sequence while it walks:

```swift
        TabView(selection: Binding(
            get: { activePhrase },
            set: { candidate in
                // Swiping mid-sitting pins a phrase: the sequence
                // stops walking and the counter carries on where the
                // person put it.
                storedPhraseRaw = candidate.rawValue
                sittingHead = candidate == TasbihSequence.phrases[0] && totalCount == 0
                    ? candidate
                    : candidate
            }
        )) {
```

Simplify: setting `sittingHead = candidate` on any swipe means a swipe to a non-head phrase stops the walk, and a swipe back to Subḥānallāh restarts it from wherever the count is. Use:

```swift
            set: { candidate in
                storedPhraseRaw = candidate.rawValue
                sittingHead = candidate
            }
```

In `ring`, replace `Self.cycleLength` with `TasbihSequence.cycleLength`, and add the completion inscription beneath the count:

```swift
                if sequence.isComplete(atTotalCount: totalCount) {
                    Text("COMPLETE")
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .foregroundStyle(tokens.metal)
                } else if totalCount > TasbihSequence.cycleLength {
                    Text("TOTAL \(totalCount)")
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .monospacedDigit()
                        .foregroundStyle(tokens.inkSecondary)
                        .contentTransition(.numericText())
                }
```

In `finish()`, record one row per third actually recited when the sitting walked the sequence — the ledger should say what was said:

```swift
    private func finish() {
        let total = totalCount
        let sitting = sequence
        let custom = storedCustomPhrase
        if total > 0 {
            let day = Calendar.current.startOfDay(for: nowProvider.now())
            // A walked sitting recorded as one row would name only the
            // phrase it ended on. One row per third says what was
            // actually recited; a single-phrase sitting is one row, as
            // before.
            var records: [(DhikrPhrase, Int)] = []
            if sitting.walksTheSequence {
                var remaining = total
                for phrase in TasbihSequence.phrases where remaining > 0 {
                    let count = min(remaining, TasbihSequence.cycleLength)
                    records.append((phrase, count))
                    remaining -= count
                }
                if remaining > 0 {
                    records.append((TasbihSequence.phrases[TasbihSequence.phrases.count - 1], remaining))
                }
            } else {
                records.append((sitting.head, total))
            }
            Task {
                for (phrase, count) in records {
                    _ = try? await SaveDhikrSessionIntent(
                        count: count,
                        phrase: phrase,
                        customPhrase: phrase == .custom && !custom.isEmpty ? custom : nil,
                        sessionDate: day
                    ).perform()
                }
            }
        }
        onDismiss()
    }
```

Update `labelText(for:)` callers and the a11y label/value to use `activePhrase`.

- [ ] **Step 6: Build and run the app suite**

```bash
xcodebuild -project ihsan.xcodeproj -scheme ihsan \
  -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B \
  -only-testing:ihsanTests test 2>&1 | tail -30
swift test --package-path Packages/IhsanCore
swift test --package-path Packages/IhsanIntents
```

`ihsanUITests/DhikrInstrumentUITests.swift` exercises this screen — read it and update any assertion that assumes the label never changes. Run it:

```bash
xcodebuild -project ihsan.xcodeproj -scheme ihsan \
  -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B \
  -only-testing:ihsanUITests/DhikrInstrumentUITests test 2>&1 | tail -30
```

- [ ] **Step 7: Commit**

```bash
git add Packages/IhsanCore ihsan/Dhikr ihsanUITests
git commit -m "corrective-i: the tasbih walks the three thirds

The instrument held one phrase for the whole sitting, so from mark 34
onward the label contradicted what the person was reciting. The
tasbih after each fard salah is 33 Subhanallah, 33 Alhamdulillah, 33
Allahu Akbar (Muslim 597) — the guided postPrayer set in
adhkar-content.json has had it right all along; the instrument did
not.

TasbihSequence lives in Core so the instrument, the intents, and any
future surface share one definition. The sequence is a property of the
canonical start, not a mode: swiping to any other phrase pins it and
counts on. A walked sitting records one row per third, so the ledger
says what was actually recited.

The hundredth is not printed. It is a full narrated supplication and
this repo's copy sits behind the scholar-review gate; the instrument
marks the arrival at 99 instead.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Full verification, captures, and the findings sweep

**Files:**
- Modify: `POLISH_FINDINGS.md`
- Delete: `Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/_Probe.swift`

- [ ] **Step 1: Every package suite**

```bash
for p in IhsanCore IhsanDesignSystem IhsanFiqhConfig IhsanInsights IhsanIntents IhsanLocation IhsanNotifications IhsanPrayerTimes; do
  echo "=== $p ==="
  swift test --package-path "Packages/$p" 2>&1 | tail -5
done
```

Expected: all eight report success. Every failure is a real regression — fix it, do not skip it.

- [ ] **Step 2: App tests and both builds**

```bash
xcodebuild -project ihsan.xcodeproj -scheme ihsan \
  -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B \
  -only-testing:ihsanTests test 2>&1 | grep -E "Test run with|error:|warning:"
xcodebuild -project ihsan.xcodeproj -scheme ihsan \
  -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B build 2>&1 | grep -E "warning:|error:" | sort -u
xcodebuild -project ihsan.xcodeproj -scheme ihsanWidgets \
  -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B build 2>&1 | grep -E "warning:|error:" | sort -u
```

Expected: "Test run with N tests" reporting zero failures, and no warning/error lines from either build. Swift Testing means XCTest prints "Executed 0 tests" — ignore that line.

- [ ] **Step 3: Capture the whole passage**

Install once, then loop. **`simctl location` lapses during a session — re-issue it before EVERY run** or the day never resolves. `-IhsanNowOverride` only applies on a genuinely fresh launch, so terminate first. Use the suffix-less wall-time form; a bare ISO8601 with `Z` or an offset resolves an hour off.

```bash
UDID=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B
OUT=/private/tmp/claude-501/-Users-sameer-ihsan/captures
mkdir -p "$OUT"
xcrun simctl privacy $UDID grant location com.sameerstudios.ihsan

for T in 03:30 04:14 05:00 05:30 05:45 06:15 06:54 09:30 20:00 20:08 20:20; do
  xcrun simctl location $UDID set 41.8781,-87.6298
  xcrun simctl terminate $UDID com.sameerstudios.ihsan 2>/dev/null
  xcrun simctl launch $UDID com.sameerstudios.ihsan \
      -IhsanDebugCompletedOnboarding \
      -IhsanNowOverride "2026-08-02T${T}:00"
  sleep 9
  xcrun simctl io $UDID screenshot --type=png "$OUT/today-${T//:/}.png"
done
```

Read every capture. Wait for "Loading prayer times…" to disappear, not for the tab bar — if a shot still shows it, raise the sleep and retake.

What to look for, per item:
- **05:45 and 20:08** — marker labels, the SUNRISE inscription, and the header inscription must all be plainly readable. This is the whole of item 1.
- **06:15** — first light must read as its own page: deep sky overhead, warm horizon, gold on the ground.
- **05:00** — dawn must not read as night with a warm band.
- **05:45** — no horizontal streaks below the chord.
- **09:30** — if the moon is up, it must be a pale ghost, not a gray coin.
- **Every shot** — the five ornaments and the focused card are still the first things the eye goes to.

- [ ] **Step 4: Capture the Path and the tasbīḥ**

```bash
xcrun simctl location $UDID set 41.8781,-87.6298
xcrun simctl terminate $UDID com.sameerstudios.ihsan 2>/dev/null
xcrun simctl launch $UDID com.sameerstudios.ihsan \
    -IhsanDebugCompletedOnboarding -IhsanDebugTab trajectory \
    -IhsanNowOverride 2026-08-02T09:30:00
sleep 9
xcrun simctl io $UDID screenshot --type=png "$OUT/path-day.png"
```

Turn both overlay chips on by hand in the simulator (they need a `UserSettings` row and real records to show marks) and capture again. Then relaunch with `-IhsanDebugPresentDhikr`, tap past 33 and 66, and capture the label at each third.

- [ ] **Step 5: Attribute anything you call pre-existing**

If any finding is described as pre-existing, prove it:

```bash
git worktree add /private/tmp/claude-501/-Users-sameer-ihsan/pre-h dbf5ae2^
xcodebuild -project /private/tmp/claude-501/-Users-sameer-ihsan/pre-h/ihsan.xcodeproj \
  -scheme ihsan -destination id=$UDID \
  -derivedDataPath /private/tmp/claude-501/-Users-sameer-ihsan/pre-h-dd build
```

Capture the same instant from that build and compare. Do not write "pre-existing" without this. Clean up with `git worktree remove` when done.

- [ ] **Step 6: Append the findings**

Add a corrective-I section to `POLISH_FINDINGS.md` covering what only a device can settle:

- **The keyline at arm's length.** The two-tone outline is 0.78 pt dark and 1.63 pt to the light ring's outer edge on 10 pt text. On a real display, confirm it reads as a crisp engraved edge and not as a halo or a second weight — and that it is genuinely invisible on the plateaus either side.
- **The keyline's cost.** Eight shadow layers per label during the crossing windows. Confirm 60 fps holds at 05:45 on device, where the render harness only measures the host.
- **First light on OLED.** firstLight's zenith is the deepest of the three day skies and its ramp is the longest. Watch for contouring in the upper third at low brightness.
- **First light's warm horizon wash.** `horizonWash #F6DDB0` also feeds `chromeTint` and `sheetBackingValue`. Confirm the tab bar and the log sheet read warm-and-quiet at 06:15 rather than yellow.
- **Dawn's new page.** The whole point of item 3: at 5:00 AM does the plate read as dawn rather than as late night — and does it stay clearly a different page from sunset.
- **The daytime moon.** Confirm it is findable if looked for and never noticed if not. The failure modes are a gray coin (the old defect) and nothing at all (the overcorrection).
- **The Path overlay rows at 90D.** The dot is 3 pt there. Confirm a present mark is resolvable at arm's length and that the row still reads quieter than the five fardh rows.
- **The tasbīḥ handover.** The 33→34 phrase change is announced to VoiceOver by name. Confirm it does not interrupt the counting rhythm, and that the settle haptic still reads as an arrival.

Under "Found, not fixed", record:

- **The hundredth.** `TasbihSequence` stops at 99 because the hundredth is a full narrated supplication whose copy in this repo sits behind the scholar-review gate in `adhkar-content.json`. When that gate clears, the instrument should offer it. Remove the corrective-H "daytime moon" entry from "Found, not fixed" — Task 5 fixed it.

- [ ] **Step 7: Delete the probe and confirm the tree is clean**

```bash
rm -f Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/_Probe.swift
git status --porcelain
```

Expected: only `POLISH_FINDINGS.md` modified.

- [ ] **Step 8: Commit and push**

```bash
git add POLISH_FINDINGS.md
git commit -m "corrective-i: device checklist

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
git push origin main
```

---

## Self-review

**Spec coverage.** Item 1 → Task 1. Item 2 → Task 2. Item 3 → Task 3. Item 4 → Task 4. Item 5 → Task 5. Item 6 → Task 6. Item 7 → Task 7. Constraints and verification → Task 8, plus per-task build/warning checks.

**Type consistency.** `inkOutlineStrength` is defined on `SkyPhase` (Task 1 Step 3) and mirrored on `SkyPaletteTokens` (Step 4); the modifier reads the token (Step 5). `firstLightEndUnit` and `firstLightEnd(for:)` are both introduced in Task 2 Steps 3–4 and used in Steps 4–6. `GestaltGrid.overlayMarkValue(for:)` / `overlayMarkOpacity` are used by the Task 6 test before Step 3 defines them — that is the intended TDD order. `TasbihSequence`'s full surface is listed in the task's Interfaces block and every member is used by either the test (Step 1) or the screen (Step 5).

**Known risk.** Task 1's `bestAdjacentContrast` is O(pixels × distance²) per render; at 96 pt / scale 3 that is 288² pixels × 60 phases × 3 heights × 2 inks. If the test runs longer than ~90 s, reduce `crossingPhases(steps:)` to 30 and the heights to `[0.15, 0.85]` — do not reduce `bandLimit` or the 4.5 threshold, which are the contract.
