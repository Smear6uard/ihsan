# Corrective I — the crossing, and first light

Design spec. Follows corrective H (`dbf5ae2`, "the illuminated day").
Nothing in corrective H is undone here.

All timings measured for 2026-08-02, Chicago: Fajr 4:14, sunrise 5:45,
Dhuhr 12:58, Maghrib 20:08, Isha 21:38.

Seven items. 1 and 2 are the substance; 3–5 are the audit's smaller
findings; 6 and 7 are separate reported bugs on the Path screen and the
tasbīḥ instrument.

---

## 1. The crossing goes illegible

### The defect

At sunrise every piece of text on the plate fogs out.

| | worst ratio | sub-AA window |
|---|---|---|
| primary ink | 1.06:1 | 5:42–5:51 (9 min) |
| secondary ink | 1.04:1 | 5:36–6:03 (26 min) |
| maghrib, primary | 1.07:1 | 20:04–20:10 (6 min) |

Pre-existing — identical at `0069ffa`, the commit before corrective H.

`inkHalo` fires at strength 1.00 exactly there. Its presence is not the
mitigation it was assumed to be. `markerLabel` draws

```swift
.shadow(color: tokens.inkHaloDark,  radius: 1)
.shadow(color: tokens.inkHaloLight, radius: 2.5)
.shadow(color: tokens.inkHaloLight, radius: 6)
```

Three problems compound:

1. `.shadow` is a **blur**. The dark and light silhouettes are both
   centred on the glyph and overlap almost completely, so they average
   to mid-grey exactly where separation is needed.
2. SwiftUI's `.shadow` chain applies to the **accumulated** rendering,
   so the light shadow at r=2.5 blurs *the glyph plus its dark halo*,
   spreading light underneath the dark ring rather than outside it.
3. The glyph itself passes through mid-tone. Neither pole helps a
   mid-tone mark that is surrounded by mid-tone fog.

### The constraint

`SkyPhase.figureHalfWidth` already narrows the flip to ±14 min, and its
doc comment states the governing fact: if ink and ground are both
continuous and swap luminance polarity, contrast provably passes
through 1:1 (intermediate value theorem). No timing avoids it.

Two candidate mitigations were worked through and rejected:

- **An opaque cartouche behind the label.** A plate that must be
  invisible at both plateaus still forces the composited local
  background through mid-tone while the ink is also mid-tone. At the
  exit edge (α falling from 1 over a bright morning sky) the measured
  worst case is ~1.15:1. The trap is relocated, not removed.
- **Constant-polarity labels all day.** Mathematically airtight, but
  five dark slabs on a luminous morning sky out-shout the five prayer
  ornaments. Fails the discipline gate.

A hard two-pole flip is also bounded: with a background restricted to
pure black or pure white, the best achievable worst-case foreground
contrast is √21 ≈ 4.58:1 — and a flip is a snap, which the palette
forbids.

### The fix — `.inkKeyline(tokens)`

The glyph stops being the only mark. It gains a **crisp two-tone
outline**: a hard-edged dark keyline ring immediately against the
glyph, and a hard-edged light ring outside that. The rings occupy
different pixels, so they never average.

```
  ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁   light ring   (outer)
  ███ SUNRISE ███   dark keyline (inner)
  ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔
  glyph → dark ring → light ring → sky
```

Whatever value the glyph currently holds, one adjacent band is always
far from it:

| glyph | vs dark ring | vs light ring |
|---|---|---|
| light (dawn ink) | ~15:1 ✓ | merges with ground |
| mid (crossing) | ~5.3:1 ✓ | 3.3:1 |
| dark (morning ink) | 1.2:1 | ~14:1 ✓ |

This is not a new device. It is the palette's own **keyline** rule —
"the fine dark boundary of every gilded form … the dark edge is what
makes gold read as gold rather than tan" (`SkyPalette.swift`) — applied
to text for the one moment it needs it.

**Implementation.** A public `ViewModifier` in
`Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Modifiers/InkKeyline.swift`:

```swift
public extension View {
    func inkKeyline(_ tokens: SkyPaletteTokens) -> some View
}
```

Chained `.shadow(color:radius: 0, x:, y:)` in eight directions dilates
the accumulated silhouette with a hard edge. Radius 0 means no blur,
which is the whole point.

Order matters and is the opposite of the visual stacking: each `.shadow`
applies to the *accumulated* rendering, so the **dark** pole is applied
first (dilating the glyph) and the **light** pole second (dilating
glyph + dark ring). The outermost ring is therefore the last one
applied. This is the same chaining behaviour that made the existing
blurred implementation spread light *underneath* the dark halo — used
deliberately here instead of accidentally.

Emits **nothing** when strength is 0: on a plateau the modifier returns
the content unchanged, so 99% of the day costs one `Text`.

**Strength curve.** A new computed property on `SkyPhase`:

```swift
/// Reaches full strength well before the ink itself approaches
/// mid-tone, so the outline is already solid across the entire
/// figure flip and only ramps in the band's outer margins, where
/// contrast is comfortable without it.
public var inkOutlineStrength: Double { min(1.0, inkHaloStrength * 3.0) }
```

`inkHaloStrength` is `sin(π · amount)` over the atmosphere band
(±0.035). It reaches ⅓ at u₀ ± 0.014, so the outline is at full opacity
across u₀ ± 0.014 — containing the entire figure flip at u₀ ± 0.005 with
room on both sides.

**Call sites replaced.** All three existing shadow treatments go:

| file | site |
|---|---|
| `CelestialPlateScene.swift` | `markerLabel` (3 shadows) |
| `CelestialPlateScene.swift` | `sunriseMark` inscription (2 shadows) |
| `TodayHeader.swift` | `legibilityShadowColor()` — white 0.42 / black 0.48 |

`TodayHeader`'s separate mechanism is deleted outright. One mechanism,
not two; both surfaces survive the crossing by the same construction.

`nightInscription` and the `FocusedPrayerCard` sites adopt the same
modifier where they print on the sky.

### The test — the deliverable

`Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/CrossingLegibilityRenderTests.swift`.

Neither `PaletteV2ContrastTests.inkDipsOnlyUnderActiveHaloAndBriefly`
nor `SkyFieldContrastTests.skyDipsOnlyUnderAnActiveHalo` measures the
composited result — both assert only that a halo is *present and
strong* when contrast dips. The halo is treated as sufficient by fiat.
That is why this shipped.

The new test renders. `ImageRenderer`, in the style `SkyRenderTests`
already establishes, at a fine step through the **whole** sunrise and
maghrib passages:

1. Render the label over the composed sky with `.inkKeyline`.
2. Derive the glyph coverage mask from a reference render (same text,
   flat known ground).
3. Take the glyph **core** (coverage ≥ 0.9), and the concentric bands
   at Chebyshev distance 1…6 px from any covered pixel. Rendered at
   `scale = 3`, so 6 px = 2 pt — just past the light ring's outer edge.
4. Assert:

   > within 2 pt of a glyph stem there is a band whose luminance
   > differs from the stem's by ≥ 4.5:1 contrast

Both primary and secondary ink. Both crossings.

**Verification order matters.** Run this test against the *current*
double-shadow implementation first and confirm it fails, before
changing anything. A test that passes on the broken code proves
nothing.

Also add the non-render companion that the existing pair is missing:
`inkOutlineStrength` must be ≥ 0.99 at every phase where any ink/ground
pair drops below 3:1.

---

## 2. There is no sunrise state

### The defect

`PaletteState` has five members. Fajr→sunrise is a real state (`dawn`).
Sunrise is a *boundary* — palette-unit 0.180, the dawn→morning
transition centre — and owns no tokens. The evening gets both a
boundary (maghrib) and a dedicated jewel state (sunset); the morning's
equivalent moment gets only the boundary.

```
dawn    holds pure 4:43–5:16   (33 min)
sunset  holds pure 20:22–21:24 (62 min)
sunrise crossing 5:16–6:54     (98 min of blend, no state)
```

The app has an evening fire chapter and no morning one.

### The fix — `PaletteState.firstLight`

Named to mirror sunset's construction: the boundary keeps the solar
event's name (`sunrise`), the chapter gets its own. `dawnProgress`
already uses the phrase in its doc comment.

**New unit table.** Six states, six boundaries:

| unit | role | | unit | role |
|---|---|---|---|---|
| 0.000 | night ● | | 0.400 | solarNoon |
| 0.050 | fajr | | 0.525 | afternoon ● |
| 0.105 | dawn ● | | 0.650 | maghrib |
| 0.160 | sunrise | | 0.760 | sunset ● |
| 0.2275 | **firstLight ●** | | 0.875 | isha |
| 0.295 | **firstLightEnd** | | | |

(● = plateau centre, i.e. `SkyPhase.fixed(_:)`.)

Every adjacent boundary pair is > 0.070 apart, so with
`atmosphereHalfWidth = 0.035` no two transition bands overlap and every
state keeps a genuine plateau.

**The sixth anchor is derived, not a new input.** `SolarDayEvents`
gains no field. Inside `resolve(at:events:)`:

```swift
// First light lasts as long as the dawn that preceded it — the
// morning's mirror of the maghrib→isha span that gives the evening
// its sunset chapter. Capped so an extreme-latitude dawn cannot
// swallow the morning.
let firstLightEnd = sunrise + min(sunrise - fajr, 0.35 * (solarNoon - sunrise))
```

`approximate(at:)` gains the matching clock anchor at 7:15 (its sunrise
is 6:00, its fajr 4:45).

**Measured result**, Chicago 2026-08-02:

```
dawn        pure 4:43–5:16   (33 min — unchanged)
sunrise crossing 5:13–6:14   (61 min, was 98)
firstLight  pure 6:08–6:53   (45 min — 6:15 lands inside it)
morning     pure 9:10–11:04
```

6:15 AM was identified as the best-looking moment of the whole
sequence. It now arrives as a designed chapter rather than as a
by-product of a blend.

### firstLight's identity

**A luminous day state**, not a jewel one. Two consequences, both
wanted:

- The polarity flip stays at **sunrise**, where the sun actually
  crests. Item 1's work is not multiplied.
- firstLight→morning carries **no crossing at all**: firstLight's
  `ink`, `inkSecondary`, `keyline`, `panelFill`, `positive`, and
  `attention` are morning's exactly, so `inkHaloStrength` is 0 at that
  boundary by construction.

What makes it its own page — every lever is an existing token role, no
new hues:

| token | direction |
|---|---|
| `skyZenith` | deeper and more chromatic than morning's `#94BFFB` — the sky is deepest when the sun is low |
| `horizonWash` | **warm gold**, where morning's `#DCE7F4` is cool blue. The single strongest lever: it makes the vertical ramp read blue-overhead → gold-at-the-horizon, which is what a post-sunrise sky is |
| `glow`, `leafGold`, `metalHighlight` | the day's richest, warmest gold |
| `groundPlane` | warmer than morning's `#E8E0CB` — the gold on the ground |
| `groundTop`, `groundBottom` | cool-neutral luminous near-white. Palette v2's thesis holds: **all saturation lives in the ink, the metal, and the glow, never in the ground** |

`daytimeGroundsAreLuminousNotBeige` gains `firstLight` as a third
argument (OKLab `l ≥ 0.93`, `b ≤ 0.02`). That test is the guardrail
against golden-hour warmth leaking into the ground and reading as
parchment.

### Blast radius

| file | change |
|---|---|
| `SkyPhase.swift` | unit constants, `firstLightEndUnit`, `resolve`, `approximate` anchors, `boundaries` table, `blend` plateau switch, `fixed(_:)`, `nightness`, `dawnProgress` |
| `SkyPalette.swift` | enum case, `tokens` switch, `SkyPaletteTokens.firstLight` |
| `SkyPhaseTests.swift` | hard-coded `SkyPhase(unit: 0.125) == .dawn` → 0.105; boundary assertions |
| every `PaletteState.allCases` suite | 6 arguments instead of 5 — `PaletteV2ContrastTests`, `SkyFieldContrastTests`, `ArabicTypographyTests`, `WorshipSurfaceContrastTests`, `PrayerLogSheetContrastTests`, `AdhkarSurfaceContrastTests`, `PageChromeContrastTests`, `ShipPassContrastTests` |
| galleries | `DesignV2Gallery`, `AdhkarTypeGallery`, `AdhkarTypeGalleryScreen`, `IhsanIlluminatedPanel`, `PrayerMarkerOrnament` previews |

Widgets (`CompactPlate`, `WidgetPalette`) consume through
`PaletteState.resolved(for:)` and inherit the sixth state without
edits. Their hard-coded `.night` references stay correct.

---

## 3. Dawn barely separates from night

### The defect

Dawn's tokens sit only 1.30–1.38× night's luminance on `groundTop` and
`groundPlane`; only `groundBottom` (2.43×) and `horizonWash` (1.88×)
really move. At 5:00 AM the plate reads as late night with a warm
horizon, not as dawn.

### The fix

Night is near-black indigo. Sunset is plum-vermillion. Dawn becomes
**lapis-violet** — clearly distinct from both, and the brightest jewel
ground after sunset.

Targets, relative to night:

| token | now | target |
|---|---|---|
| `groundTop` | 1.30× | ≈ 2.5× |
| `groundBottom` | 2.43× | ≈ 3.5–4× |
| `groundPlane` | 1.38× | ≈ 2× |
| chroma | — | up across the set |

`horizonWash` carries the first warmth without entering sunset's
vermillion — dawn and dusk share optics but must not share a page.

Same family, no new hues. Exact hexes are tuned against the contrast
suite, not asserted here: dawn's `ink` (`#EDEFF6`) and `inkSecondary`
(`#AEB4CB`) must still clear AAA and AA respectively on the lifted
grounds, and `inkSecondary` is the pair most at risk — expect to lift
it a step.

A new test pins the separation so it cannot silently regress:
dawn's `groundBottom` luminance ≥ 3× night's, and dawn's ground chroma
strictly greater than night's.

---

## 4. Horizontal streaks at the horizon during the crossing

### The defect

At 05:45 the three "worked earth" ground filaments (depths 7/14/21 pt
below the chord, `CelestialSkyView`) read as rays off the sun when it
sits exactly on the chord — visually close to the README's permanent
ban on "horizontal light streaks (any full-width band of light, at the
horizon or anywhere else)".

Pixel-identical pre-corrective-H, so it is not new. It wants a
decision.

### The decision — the filaments yield

They are engraving, not light; but at the crossing the bloom lights
them and the eye reads parallel lines around a light source. The
engraving yields to the light:

```swift
// The engraving yields to the light. As the sun approaches the
// chord its bloom lights these lines and three parallel full-width
// marks around a light source read as rays — the one thing the
// painted-light ban exists to prevent. Same proximity term the
// bloom itself uses, so the two can never disagree.
let engravingPresence = 1.0 - 0.85 * exp(-pow(sunAltitudeDegrees / 9.0, 2))
```

The terrain chord and its paired lapis hairline stay — they are the
horizon, not a field.

README gains the rule, in the painted-light section, stating where the
line sits (as corrective H did for the starburst).

A test asserts the filament opacity at sun altitude 0° is < 20% of its
value at altitude 45°.

---

## 5. The daytime moon is a flat gray disc

### The defect

`moonCore`'s lit limb is `mix(ink, metalHighlight, 0.35)`. That formula
assumes `ink` is the light pole — true on the jewel grounds (dawn's ink
is `#EDEFF6`), false on the day grounds where ink is `#1B2350`. On a
near-white sky it yields a dark slate coin. It is the single element on
the day plate that most competes with the five ornaments.

`lunarDaylightPresence` floors at 0.28, which is too present for a
daytime moon.

Pre-existing; written up in POLISH_FINDINGS under "Found, not fixed" at
the end of the corrective-H section.

### The fix

Branch on ground polarity, exactly as `LuminousBody` already does for
its halo and blend mode:

- **Dark grounds** — the formula is unchanged, byte for byte.
  `MoonTreatmentTests` renders on `SkyPaletteTokens.dawn` and pins the
  treatment deliberately (warm lit limb R>B, cool earthshine B>R, glow
  lift). Its intent is preserved in full.
- **Luminous grounds** — a pale warm near-white mixed off the sky, so
  the moon reads as the pale ghost a daytime moon actually is rather
  than a coin. The limb rim stays: the moon is the one body with a
  pixel where it stops.

`lunarDaylightPresence` floor 0.28 → 0.12.

A companion test, `moonIsAPaleGhostOnTheMorningGround`, asserts on the
morning tokens that the disc's mean brightness is close to the sky's
and that the lit limb is still distinguishable from the dark limb — a
gray coin fails the first, an invisible moon fails the second.

Dawn's tokens change in item 3; re-verify `MoonTreatmentTests` after.

---

## 6. The Path overlay rows are invisible

### The defect

Reported as "the dhikr and Nafl button in Path — if they do [anything]
it's not showing it well."

Measured on the morning panel (`panelFill #FBFCFE`, `metal #A8895A`):

| mark | opacity | composited contrast |
|---|---|---|
| dhikr / nafl **present** | 0.40 | **1.52:1** |
| fardh **unlogged** ring | 0.28 | **1.30:1** |

The overlay's "present" mark is 1.52:1 against the panel — below the
threshold of resolution — and only 0.22 apart from the mark that means
*nothing happened here*. At 30D the dot is 7 pt and at 90D it is 3 pt,
where a 0.5 pt stroke at that value does not exist.

Same root cause corrective H item 3 identified for the almucantars:
the same alpha buys less on a near-white field.

Two further problems:

- `DhikrOverlayDot` draws an **outlined ring** — the identical form to
  an unlogged fardh cell. Even at a legible value it would say the
  wrong thing.
- The overlay rows sit at the grid's own row spacing, so a sixth or
  seventh row reads as a sixth prayer.

`GestaltDot`'s doc comment cites `PathPatternContrastTests` "so the
tests audit what the dots render". **That test does not exist.** That is
why this shipped.

### The fix

1. Polarity-aware value with a real contrast floor, using the rule
   `GestaltDot.lateOutlineValue` already establishes: plain metal on
   jewel panels, deepened toward `keyline` on the near-white days.
   Expose it as a static function so the test audits the exact value.
2. The dhikr mark becomes a small **filled bead** — the tasbīḥ bead —
   rather than a ring, so it cannot be confused with an empty fardh
   cell. Nafl keeps its four-pointed star, which is already distinct.
3. A real gap between the five fardh rows and the overlay rows, so the
   overlay reads as its own register. `gridHeight` accounts for it.
4. Write `ihsanTests/PathPatternContrastTests.swift`: every dot
   treatment, in every palette state, against the panel it renders on.
   Present marks ≥ 3:1; and every present mark must be separated from
   the unlogged mark by a stated margin, so "something happened here"
   can never again be one step from "nothing did".

Presence-only semantics are unchanged: no count, no denominator, no
figure. The overlay stays quieter than the fardh rows — visible if
sought, quiet if not. It just has to be *visible* when sought.

---

## 7. The tasbīḥ counts one phrase forever

### The defect

Reported as "the tasbeh 33 33 33 times is broken, it just keeps showing
subhanallah."

`DhikrScreen` holds `storedPhraseRaw` fixed for the whole sitting.
Completing 33 lights a cycle dot and starts the next 33 — with the same
label. From mark 34 onward the label contradicts what the person is
actually reciting.

### Ground truth

The tasbīḥ after each fard salah, **Muslim 597**: 33 × Subḥānallāh,
33 × Alḥamdulillāh, 33 × Allāhu Akbar, then the hundredth —
"Lā ilāha illa'llāhu waḥdahu lā sharīka lah, lahu'l-mulku wa
lahu'l-ḥamd, wa huwa ʿalā kulli shay'in qadīr."

This is already in the repo, correctly transcribed and sourced, as the
`postPrayer` items in
`Packages/IhsanCore/Sources/IhsanCore/Resources/adhkar-content.json`
(`postPrayer.subhanallah` / `.alhamdulillah` / `.allahu-akbar`, each
`repetitions: 33`, plus `postPrayer.completion-of-the-hundred`). The
guided set has been right all along; the instrument was not. That file
sits behind the scholar-review gate (`reviewStatus: "draft"`), so the
instrument states the reference in code rather than reading the gated
text.

(The sleep variant — Tasbīḥ Fāṭima, 33/33/34, al-Bukhārī 5362 /
Muslim 2727 — is also in the file. It is **out of scope**: a mode
picker contradicts an instrument whose whole thesis is that tapping is
the entire interface.)

### The fix

Completing 33 advances the label to the next phrase and lights the
cycle dot. The sequence is what the ring does when the sitting starts
at Subḥānallāh.

**The hundredth is named, not printed — and that is the gate's doing.**
`DhikrPhrase`'s four labels are short, universally-known formulas
hard-coded in `IhsanCore` and already shipping ungated. The hundredth
is a full narrated supplication, and the copy of it in this repo lives
in `adhkar-content.json` behind `reviewStatus: "draft"`. Printing it
from Swift would route unreviewed text around the gate that exists to
stop exactly that. So at 99 the third dot lights and the instrument
shows a quiet completion inscription; the hundredth's text stays in the
guided set, where the gate governs it. A POLISH_FINDINGS entry records
that it becomes available to the instrument when the gate clears.

Swiping the label row still pins a single phrase — starting anywhere
other than Subḥānallāh, or on the custom slot, keeps the current
single-phrase behaviour. The sequence is a property of the *canonical
start*, not a mode the user has to find.

Held in `IhsanCore` beside `DhikrPhrase` so the sequence has one
definition and the intents, the instrument, and any future surface
cannot drift:

```swift
/// The tasbīḥ after each fard salah — Muslim 597.
public static let afterSalah: [DhikrPhrase] = [.subhanallah, .alhamdulillah, .allahuAkbar]
```

Unit-tested in `IhsanCore`: the sequence advances at 33/66, the
hundredth is offered at 99, and a sitting started on a non-canonical
phrase does not advance.

VoiceOver: the existing 11/22/33 waypoint announcements stand; the 33
announcement gains the name of the phrase being handed over to, because
a phrase change is exactly the thing a per-tap haptic cannot carry.

`SaveDhikrSessionIntent` records the sitting as it does now. Whether a
multi-phrase sitting stores one row or three is an implementation
detail for the plan to settle; the dedup key must stay stable either
way.

---

## Constraints (all items)

- Zero build warnings across every target; the archive stays clean.
- Swift 6 language mode, strict concurrency, `Sendable`-correct.
- The painted-light ban list in `Packages/IhsanDesignSystem/README.md`
  is permanent: no lens flares, horizontal light streaks, anamorphic
  effects, specular hotspots, bokeh, or any camera-artifact rendering.
  Starbursts are lens renderings.
- No new hues. Every colour is a palette-v2 token.
- Discipline gate: nothing may compete with the five prayer ornaments
  or the focused card at a glance. Grayscale value check must pass;
  60 fps held; Reduce Motion and Reduce Transparency fallbacks defined
  for anything new.

## Verification (all items, before pushing)

- `swift test` on all eight packages under `Packages/`.
- App tests: `xcodebuild -project ihsan.xcodeproj -scheme ihsan
  -destination id=7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B
  -only-testing:ihsanTests test`. They are Swift Testing, so XCTest
  reports "Executed 0 tests" — read "Test run with N tests" instead.
- Build both the `ihsan` and `ihsanWidgets` schemes.
- Simulator captures across the whole passage, at minimum 03:30, 04:14,
  05:00, 05:30, 05:45, 06:15, 06:54, and 20:00, 20:08, 20:20 for the
  maghrib side. Plus the Path screen with both overlays on, and the
  tasbīḥ at counts 33, 66, 99.

  Recipe (iPhone 17 Pro, UDID `7B907EE4-84DF-41F4-A940-B4D3DC3BAC7B`):

  ```bash
  xcrun simctl privacy <udid> grant location com.sameerstudios.ihsan
  xcrun simctl location <udid> set 41.8781,-87.6298
  xcrun simctl terminate <udid> com.sameerstudios.ihsan
  xcrun simctl launch <udid> com.sameerstudios.ihsan \
      -IhsanDebugCompletedOnboarding \
      -IhsanNowOverride 2026-08-02T05:45:00
  sleep 9 && xcrun simctl io <udid> screenshot --type=png
  ```

  Gotchas that cost real time: `simctl location` **lapses** during a
  session — re-issue before every run or the day never resolves.
  `-IhsanNowOverride` only applies on a genuinely fresh launch, so
  terminate first. Use the suffix-less wall-time form shown; a bare
  ISO8601 with `Z` or an offset resolves an hour off. Wait for
  "Loading prayer times…" to disappear, not for the tab bar.

- To attribute anything as pre-existing, build a worktree at an earlier
  commit with its own `-derivedDataPath` and capture the same instant.
  Do not assert "pre-existing" without doing this.
- Append device-only items to `POLISH_FINDINGS.md`. Device
  verification is the maintainer's, never asserted from source.
