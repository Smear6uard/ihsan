# IhsanDesignSystem

The visual primitives that every Ihsan screen is built from — design
tokens (color, typography, spacing, material) and reusable SwiftUI
components built on iOS 26's Liquid Glass design language.

## Flat + luminous — the global rendering rule

The celestial layer's visual language is **flat + luminous**. Applied
everywhere, no exceptions without a spec change:

- **No 3D shading.** No offset-center radial gradients implying a lit
  sphere, no simulated volume on any body or ornament.
- **No specular highlights.** No rim strokes, no glints, no
  iridescent sheen standing in for reflected light.
- **No drop shadows** on celestial bodies, ornaments, or panels.
  Panels sit on the page by fill and hairline border alone.
- **Depth comes from glow, bloom, and layered opacity only.** A body
  that must read as bright gets a corona; a panel that must read as
  active gets an interior glow; a region that must read as deeper
  gets the same material one lightness step down.
- **Sanctioned exception:** the text-legibility ink halo
  (`SkyPaletteTokens.inkHalo`) — it is itself a glow, not a shadow,
  and exists only to keep engraved labels readable through palette
  transitions.

Concretely: the sun is three layers of light (near-white core
dissolving into a warm corona into the atmospheric wash) with no
radius at which an edge exists; the moon is a lit object with a
defined limb, earthshine, and a cool glow on jewel grounds; arcs are
continuous tapered metal filaments — never dotted, never dashed.

### Painted light — the permanent ban list

Ihsan **paints** light; it does not film it. Light on the plate is
one of three things: a radial bloom, a graded wash, or gilding.
Everything a camera adds to light is banned **permanently,
app-wide** (corrective G, hard rule 3):

- lens flares
- horizontal light streaks (any full-width band of light, at the
  horizon or anywhere else)
- anamorphic effects
- specular hotspots (including any glow anchored to the screen's
  geometry — center, edges — instead of to a body's own position)
- bokeh
- any other camera-artifact rendering

The sun's horizon interaction is the reference implementation: a
radial bloom centered on the sun's own position, falloff dying to
nothing within ~35% of the screen width, brightening the horizon
filament and bleeding a few points into the ground **only** inside
that radius. Elsewhere the chord stays the quiet tapered gold with
its paired lapis hairline.

**Starbursts are lens renderings** (corrective H). The sun carries an
engraved ray collar on the day states — twelve short ticks on the
Shamsa's own angular construction, in `metal`, terminating short of
every ornament like all the plate's linework. That is an engraving,
and it is sanctioned. Run the same twelve rays out past the bloom and
it becomes a star filter's rendering of a light source, which is
banned. The line between the two is length and weight, so both are
pinned in `EngravedSunRays`: the collar runs 0.68→0.88 diameters,
never further, and never at an opacity that lets it compete with the
five ornaments at a glance.

## What this design system encodes

Ihsan is a private personal ibadah ledger for practicing Muslims. The
visual identity is "Apple-native expression of Islamic ibadah" —
restrained, considered, never decorative for its own sake.

**The single most important rule: the ground stays constant; the glass
refracts time of day.** A consistent deep ultramarine-near-black ground
(`#0E1428`) is used across every screen at every time of day. There is
NO time-of-day background color shift. Time of day is expressed only
through how Liquid Glass cards refract light — at Fajr, glass cards
pick up cool violet specular highlights; at Asr, warm honey-gold; at
Maghrib, rose-gold; at Isha, deep blue-magenta. The ground stays the
same; the glass shimmers differently across hours.

This is the iOS 26 Liquid Glass principle applied to ibadah: identity
through material, not through background color. Future contributors,
do not reinstate full-bleed colored backgrounds — that's the change
this package was built to prevent.

## How to compose a screen

Every screen starts with `.ihsanBackground()` at the root, then composes
`GlassCard`, `PrayerRow`, `CountdownDisplay`, etc.:

```swift
import SwiftUI
import IhsanCore
import IhsanDesignSystem

struct TodayView: View {
    @State private var fajrStatus: PrayerStatus? = .onTime
    @State private var fajrJamaah = true

    var body: some View {
        ScrollView {
            VStack(spacing: IhsanSpacing.md) {
                CountdownDisplay(
                    targetPrayer: .maghrib,
                    targetTime: nextMaghribTime
                )
                PrayerRow(
                    prayer: .fajr,
                    scheduledTime: fajrTime,
                    status: $fajrStatus,
                    isJamaah: $fajrJamaah
                )
                ReflectionPromptCard(
                    prompt: "What helped you turn toward Allah today?",
                    citation: "— al-Ghazali, Ihya 'Ulum al-Din"
                )
            }
            .padding()
        }
        .ihsanBackground()
    }
}
```

Open `Sources/IhsanDesignSystem/Previews/DesignSystemPreviews.swift`
in the Xcode canvas to see the complete catalog of components in one
place.

## The opacity-tier system

All text and icon colors use white at one of four documented opacities.
This is non-negotiable; the four tiers are the entire visible-content
palette.

| Tier | Opacity | Use for |
|------|---------|---------|
| `textPrimary` | 100% | Vital content — prayer names, countdown numbers, headlines |
| `textSecondary` | 70% | Supporting content — times, secondary labels |
| `textMuted` | 40% | Decorative — dividers, missed-prayer text, metadata |
| `atmospheric` | 20% | Hairlines, subtle backgrounds — never text |

Status indicators (`statusOnTime`, `statusLate`, `statusMissed`,
`statusQada`) live within the same brass / bone / ivory palette —
never bright greens, ambers, or reds.

## The adaptive tint function

`IhsanColor.adaptiveTint(at: Date)` returns the iridescent specular
tint for the moment. It uses HSB keyframe interpolation across seven
points across the day (midnight → Fajr → post-sunrise → noon → Asr →
Maghrib → Isha → midnight) and is applied to Liquid Glass surfaces via
the `.ihsanGlass(...)` wrapper.

It is **never** applied as a background color. The full-screen ground
stays `IhsanColor.ground` no matter what.

For previews, set the `\.timeOfDayOverride` environment value to render
a component as it would appear at a specific moment without
clock-mocking:

```swift
SomeView()
    .environment(\.timeOfDayOverride, TimeOfDay.fajr.representativeDate)
```

## Anti-patterns that will be rejected in code review

- Inline `Color(red:green:blue:)` literals in screen code. Every color
  routes through `IhsanColor`.
- Inline `Font(...)` or `Font.system(size:)` literals in screen code.
  Every font routes through `IhsanFont`. Using the tokens preserves
  Dynamic Type behavior and tabular figures.
- Hard-coded paddings, frames, or radii. Use `IhsanSpacing` tokens.
- Red for missed prayers (punitive — explicitly avoided), bright
  greens for jama'ah (gamification), or amber/yellow for late prayers.
- Recording indicator in red. Use `IhsanColor.recordingPulse` (soft
  pulsing brass at 60% opacity) — never red.
- Background patterns, watermarks, or full-bleed colored gradients.
  The ground is `IhsanColor.ground`. Period.
- Decorative scripture or Quranic verses on non-reflection screens.
  Sacred text is reserved for reflection contexts where it provides
  the intended companionship, not as ornament.
- Direct calls to `.glassEffect(...)`. Use `.ihsanGlass(...)` so the
  adaptive tint and intensity tier stay consistent.

## Components

| Component | Purpose |
|-----------|---------|
| `GlassCard` | The fundamental container — Liquid Glass with standard padding |
| `PrayerRow` | Symbol + name + time + status pill + jama'ah toggle |
| `StatusPill` | 4-state status indicator (onTime / late / missed / qada) |
| `JamaahToggle` | Independent boolean toggle, orthogonal to status |
| `CountdownDisplay` | Hero countdown for the Today screen, ticks every second |
| `HeatmapDot` / `HeatmapGrid` | Trajectory grid for 30 / 90 / 365-day views |
| `ReflectionPromptCard` | Glass card with prompt and citation |
| `SectionHeader` | Small caps section label |
| `SettingsRow` | iOS-grouped-list-style row, rendered in Liquid Glass |
| `PrayerSymbol` | SF Symbol mapping per prayer |
| `HairlineDivider` | 1pt atmospheric divider at 20% white |

## Modifiers

| Modifier | Purpose |
|----------|---------|
| `.ihsanBackground()` | The standard dark ground — apply once per screen |
| `.ihsanGlass(intensity:)` | Liquid Glass with the adaptive time-of-day tint |
| `.ihsanGlassHero()` | Hero variant for primary surfaces |
| `.glassCardStyle(...)` | Padding + glass for ad-hoc content |

## Platform support

- iOS 26+
- watchOS 26+

iOS 26 SDK only. Uses the native `glassEffect(_:in:)` API for the
Liquid Glass material. No external dependencies.

## Verification

Run the test suite:

```bash
xcodebuild test -scheme IhsanDesignSystem \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4'
```

The tests cover:

- `AdaptiveTintTests` — keyframe ordering, midnight wraparound,
  hue ranges at each canonical prayer time, interpolation determinism,
  and continuity (no >6° jump per 5-minute step).
- `ColorContrastTests` — WCAG AAA for `textPrimary`, AA for
  `textSecondary`, large-text AA for `textMuted`, and that
  `atmospheric` is intentionally below text thresholds.

Open the design system catalog in the Xcode canvas:

- `Previews/DesignSystemPreviews.swift` — every component, once.
- `Previews/TimeOfDaySweep.swift` — the same scene rendered five times,
  one per prayer time, on the same constant ground. This is the visual
  proof that the iridescent quality is working.
