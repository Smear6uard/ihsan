# Today Screen State Integrity + Composition Corrective — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One injectable clock drives every time-dependent surface of the Today screen; the prayer-state resolver is provably correct at any timestamp; the plate gains its specified horizon band, ground plane, engraved filaments, and flat+luminous craft; the focused card becomes an illuminated panel sharing the plate's ornament language.

**Architecture:** A `NowProvider` value (IhsanCore, Foundation-only) is injected via SwiftUI environment and resolved once per tick by a single 1-second `TimelineView` in `TodayReadyView`; all children become pure functions of that date. A pure `PrayerScheduleWindow` (IhsanPrayerTimes) carries yesterday-Isha → today → tomorrow-Fajr and resolves `(current, next, windowEnd)` at any instant. Rendering changes live in IhsanDesignSystem (PlateGeometry, CelestialSkyView, LuminousBody, PrayerMarkerOrnament, new tokens-based panel) and the app's `CelestialPlateScene` / `FocusedPrayerCard`.

**Tech Stack:** Swift 6.2 / Swift 6 language mode, SwiftUI, SwiftData, Adhan-Swift, Swift Testing (new tests), XCTest (existing package tests stay).

## Global Constraints

- iOS 26 minimum; no availability guards for older OSes.
- Swift 6 strict concurrency; new types `Sendable`-correct.
- IhsanCore: **no SwiftUI/UIKit imports** (NowProvider is Foundation-only there; the Environment key lives in the app target).
- Coordinates never persisted; no new storage of location.
- No new third-party dependencies; no analytics.
- Schema untouched (no new @Model types).
- POLISH_FINDINGS.md: append device-verification items touched by this work; do not claim them verified.
- Work directly on `main`; push only after simulator verification.
- All prayer `Date`s are absolute instants; formatting happens at the UI layer in the *place's* timezone.

---

### Task 1: NowProvider (IhsanCore) + environment plumbing

**Files:**
- Create: `Packages/IhsanCore/Sources/IhsanCore/Time/NowProvider.swift`
- Create: `Packages/IhsanCore/Tests/IhsanCoreTests/NowProviderTests.swift`
- Create: `ihsan/App/NowProviderEnvironment.swift` (EnvironmentValues entry `\.nowProvider`)
- Modify: `ihsan/App/IhsanApp.swift` (inject `NowProvider.fromLaunchArguments()` into the WindowGroup)

**Interfaces (produces):**
```swift
public struct NowProvider: Sendable, Equatable {
    public static let system: NowProvider
    public init(overrideStart: Date, systemStart: Date)   // flowing override
    public func now() -> Date                              // the ONE sanctioned Date() site
    public func resolve(_ systemDate: Date) -> Date        // maps TimelineView tick dates
    public static func fromLaunchArguments(_ arguments: [String]) -> NowProvider
}
```
Override semantics: `resolve(d) = overrideStart + (d − systemStart)` — time *flows* from the anchor at 1×, so countdowns tick and boundary transitions happen under an override. `fromLaunchArguments` reads `-IhsanNowOverride <ISO8601>` **in DEBUG only**; returns `.system` otherwise.

- [ ] Write failing tests: system passthrough (`resolve(d) == d`), flowing override math, ISO8601 arg parsing, garbage arg → `.system`.
- [ ] Run `swift test --package-path Packages/IhsanCore --filter NowProviderTests` → FAIL.
- [ ] Implement; tests PASS.
- [ ] Add environment key in app target; inject in `IhsanApp`.
- [ ] Commit.

### Task 2: PrayerScheduleWindow resolver + provider fix (Part A items 2, 3-core)

**Files:**
- Create: `Packages/IhsanPrayerTimes/Sources/IhsanPrayerTimes/PrayerScheduleWindow.swift`
- Modify: `Packages/IhsanPrayerTimes/Sources/IhsanPrayerTimes/AdhanPrayerTimesProvider.swift` (window-aware `currentPrayer`, new `scheduleWindow(for:...)`)
- Modify: `Packages/IhsanPrayerTimes/Sources/IhsanPrayerTimes/PrayerTimesProviding.swift` (protocol extension providing `scheduleWindow` — default impl so conformers/mocks don't break)
- Create: `Packages/IhsanPrayerTimes/Tests/IhsanPrayerTimesTests/PrayerScheduleWindowTests.swift`

**Interfaces (produces):**
```swift
public struct PrayerMoment: Sendable, Equatable {
    public let current: PrayerTime?      // window contains `now`; nil only in [sunrise, dhuhr)
    public let next: PrayerTime          // strictly later than `now`
    public let currentWindowEnd: Date?   // fajr→sunrise, dhuhr→asr, asr→maghrib, maghrib→isha, isha→tomorrow fajr
}
public struct PrayerScheduleWindow: Sendable, Equatable {
    public let yesterdayIsha: PrayerTime
    public let day: DayPrayerTimes
    public let tomorrowFajr: PrayerTime
    public func moment(at now: Date) -> PrayerMoment
}
// protocol extension:
func scheduleWindow(for date: Date, coordinates:, timeZone:, calculationMethod:, madhab:, highLatitudeRule:) throws -> PrayerScheduleWindow
```
Window rules: Fajr [fajr, sunrise); gap [sunrise, dhuhr) → current == nil; Dhuhr [dhuhr, asr); Asr [asr, maghrib); Maghrib [maghrib, isha); Isha [isha, tomorrowFajr) — pre-dawn hours the current prayer is *yesterday's* Isha. `AdhanPrayerTimesProvider.currentPrayer` delegates to this (semantic fix: no more "Fajr current all forenoon", no more nil pre-dawn).

- [ ] Property test: seeded RNG, 50 random (time, lat ∈ ±55°, lon ∈ ±180°, tz from a fixed pool) — invariants: `next.scheduledTime > t`; next is minimal among candidates; `current` iff its window contains `t`; `currentWindowEnd > t` whenever current != nil; boundary tests at exact instants (t == fajr, t == sunrise, t == isha, t == maghrib − 60, post-Isha → next-day Fajr rollover).
- [ ] Countdown-atomicity test (item 3 core): at `t == windowEnd` the moment already belongs to the next state; countdown target (`current != nil ? currentWindowEnd : next.scheduledTime`) is strictly > t for every t.
- [ ] Run → FAIL; implement; PASS. Run full `swift test --package-path Packages/IhsanPrayerTimes`.
- [ ] Commit.

### Task 3: CloudKit account gate (Part A item 6)

**Files:**
- Modify: `Packages/IhsanCore/Sources/IhsanCore/ModelContainer/IhsanModelContainer.swift` (`makeContainer(inMemory:cloudSync:)`, default `true`)
- Create: `ihsan/App/CloudAccountGate.swift`
- Modify: `ihsan/App/IhsanApp.swift`
- Create: `ihsanTests/CloudAccountGateTests.swift`

Gate: cached availability flag in app-group UserDefaults (default available). Launch: container built synchronously from the cache; one async `CKContainer.accountStatus()` check; on `.noAccount` → `os.Logger` notice **once** + cache false (next launch local-only); on `.available` → cache true. Re-check only on `CKAccountChanged` notification. **No polling, no retry loops.** Pure decision function `CloudAccountGate.decision(status:previouslyAvailable:) -> (cacheAvailable: Bool, shouldLog: Bool)` unit-tested.

- [ ] Failing tests for decision table (available/noAccount/couldNotDetermine/restricted × prev true/false — couldNotDetermine keeps previous cache, logs nothing).
- [ ] Implement gate + factory param + app wiring; tests PASS (app test target).
- [ ] Commit.

### Task 4: Single clock through the Today screen (Part A items 1, 3, 4 + Part D 16–17 data)

**Files:**
- Modify: `ihsan/Today/TodayScreen.swift` — `TodayReadyView` wraps content in ONE `TimelineView(.periodic(from:by: 1))`; `let now = nowProvider.resolve(context.date)`; computes `moment = snapshot.scheduleWindow.moment(at: now)`; all `.now`/`Date.now` removed (day-window @Query predicate keeps init-time `nowProvider.now()`; pause toggle timestamps use `nowProvider.now()`).
- Modify: `ihsan/Today/ViewModel/TodayState.swift` — Snapshot gains `scheduleWindow: PrayerScheduleWindow`; `nextPrayerTime`/`activePrayer` dropped in favor of derived `moment` (keep fields only if Ramadan helpers need them — rewire `isWithinSuhoorWindow`/`isCountingDownToIftar` to take `moment`).
- Modify: `ihsan/Today/ViewModel/TodayViewModel.swift` — builds `scheduleWindow` once per refresh; `Date.now` → injected `NowProvider` (constructor param, default `.system`).
- Modify: `ihsan/Today/Components/TodayHeader.swift` — takes `now: Date` + `moment: PrayerMoment` + `timeZone`; internal TimelineView removed; NEXT inscription uses `moment.next` + shared formatter (item 4).
- Modify: `ihsan/Today/Components/CelestialPlateScene.swift` — `timeOverride` replaced by required `now: Date`; internal TimelineView removed.
- Modify: `ihsan/Today/Components/FocusedPrayerCard.swift` — takes `now: Date`, `loggedAt: Date?`, `tokens: SkyPaletteTokens`; internal TimelineView + every `.now` removed; countdown/inscriptions derive from `now` (never renders 0:00:00 — strict `>` gates from Task 2 contract).
- Create: `ihsan/Today/Helpers/PlateTimeFormat.swift` — the single time formatter (Date.FormatStyle, shortened time, explicit timezone) used by header, markers, card.
- Modify: `ihsan/App/CustomTabBar.swift` — resolve tint date through `\.nowProvider`.
- Modify: `ihsan/Today/Helpers/MoonPhase.swift` — remove `= .now` default args.
- Delete dead legacy files: `TodayHeroSection.swift`, `TodayPrayerList.swift`, `DaylightWallpaper.swift`, `SunriseBoundaryRow.swift`, `SuhoorIftarBanner.swift`, `EveningReflectionEntry.swift`, `PrayerRowInscription.swift` (verify no references first); rewrite `Previews/TodayScreenPreviews.swift` minimal.
- Create: `ihsanTests/TodayMomentDerivationTests.swift` — header NEXT string and marker label for the same `PrayerTime` are equal to the minute (same formatter, same source); marker-state derivation at boundaries; countdown text never "0:00:00" for t ∈ {end−1, end, end+1}.

Acceptance (item 1): `grep -rnE 'Date\(\)|Date\.now|\.now\b' ihsan/Today ihsan/App/CustomTabBar.swift` → only `nowProvider` definitions/`DispatchTime`-free; zero direct clock reads.

- [ ] Failing app tests; implement; PASS via `xcodebuild test`.
- [ ] Grep check clean.
- [ ] Commit.

### Task 5: Ephemeris-true bodies (Part A item 5)

**Files:**
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Celestial/PlateGeometry.swift` — `bodyPosition(altitudeDegrees:azimuthUnit:apexAltitudeDegrees:)`; positive altitude maps `altitude / apexAltitude` (clamped to 1) so the sun rides the arc and sits at `arcApex` at solar noon.
- Modify: `ihsan/Today/Components/CelestialPlateScene.swift` — computes `apexAltitude = SolarPosition.compute(at: solarEvents.solarNoon, …).altitude` once per scene eval; passes through for sun and moon.
- Modify: `Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/PlateGeometryTests.swift` — apex test: `bodyPosition(alt: apexAlt, azimuthUnit: 0.5, apex: apexAlt) == arcApex` (±0.5 pt); monotonicity below apex; below-horizon mapping unchanged.

- [ ] Failing test; implement; `swift test --package-path Packages/IhsanDesignSystem` PASS (fix any dependent tests).
- [ ] Commit.

### Task 6: Horizon band, ground plane, composition rebalance (Part B items 7, 8)

**Files:**
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Celestial/CelestialSkyView.swift` — `plateHeight` input; band = 8% of *plate* height (6–10% spec); wash opacities raised (top approach 0.55 → 0.70, below-chord echo 0.30 → 0.42); sun-proximity glow kept; ground fill unchanged mechanics but deeper value.
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Tokens/SkyPalette.swift` — `subterraneanValue` deepens: dark grounds ×0.72 → ×0.60; light grounds ×0.94 → ×0.88 (plate must visibly terminate).
- Modify: `ihsan/Today/TodayScreen.swift` + `CelestialPlateScene.swift` — horizonFraction 0.62 → 0.74 and inset math so the chord-to-card gap ≤ `FocusedPrayerCard.cardHeight`; extract `TodayCompositionMetrics` (pure, `ihsan/Today/Helpers/TodayCompositionMetrics.swift`) computing insets/horizon for a given size + safe areas.
- Create: `ihsanTests/TodayCompositionMetricsTests.swift` — for iPhone 17 Pro metrics (402×874, top 62, bottom 34): `cardTop − horizonY ≤ 140`; header zone respected; plate ≥ 160 pt tall.
- Modify: DS sky tests if they assert old constants.

- [ ] Failing metrics test; implement; PASS (app + DS suites).
- [ ] Commit.

### Task 7: Marker labels + presence (Part B item 9, Part C item 13)

**Files:**
- Modify: `ihsan/Today/Components/CelestialPlateScene.swift` — label block = prayer name in small caps (primary, `tokens.ink`) above time (secondary, `tokens.inkSecondary`), single formatter; `markerSize` 24 → 29, `currentMarkerSize` 34 → 41; `labelClearance` bumped to fit two lines.
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Ornaments/PrayerMarkerOrnament.swift` — current-state glow warm metal-toned: halo color `mix(glow, metal, 0.45)`; hit-target unchanged 44 pt.
- Modify: DS `PrayerMarkerTests` if size/glow asserted.

- [ ] Implement; DS tests PASS; a11y labels keep "name at time, state".
- [ ] Commit.

### Task 8: Sun as light, engraved filaments, almucantars (Part C items 10, 11, 12 + Part D 14 scene audit)

**Files:**
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Celestial/LuminousBody.swift` — sun: three-layer light (core disc ≈ 0.45× diameter, `#FFF9EC`→white radial fading to zero — no boundary; corona gold bloom overlapping core; rim stroke and offset-center shading REMOVED). Moon: keeps edge; earthshine kept; halo becomes cool (ink-toned on dark grounds, suppressed on light) instead of warm glow.
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Celestial/PlateGeometry.swift` — `taperedFilamentPath(along:thickness:)` generalization + `arcFilamentPath()`; `PlateGeometry+Night.swift` — `nightArcFilamentPath()`.
- Modify: `ihsan/Today/Components/CelestialPlateScene.swift` — day arc dashed stroke → filled tapered filament (metal, low opacity); night arc dash → filament; almucantar layer: 2 concentric altitude arcs at rise fractions ≈ 0.36 / 0.68, metal ≤ 0.10 opacity; **no dash/dot stroke style remains in the scene** (`grep dash` clean).
- Audit for flat+luminous (item 14): remove `celestialPanel` drop shadow (Task 9 does the panel proper), remove `MoonPhaseGlyph` object shadow → keep only text legibility inkHalo shadows (documented as glow); check `LoggedStatusIndicator` etc.
- Modify: DS `SunMoonOrnamentTests`/`CelestialSceneTests` as needed; add test: sun body view has no stroke overlay (structural), filament path is closed and tapered (endpoint width == 0).

- [ ] Implement; `swift test` DS suite PASS; grep `dash\[` in Today scene → none.
- [ ] Commit.

### Task 9: Focused card as illuminated panel (Part D items 15, 16, 17 + Part A item 3 UI)

**Files:**
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Celestial/Modifiers/CelestialPanel.swift` — new tokens-based API `celestialPanel(tokens:cornerRadius:isActive:)`: v2 `panelFill` + 1 pt `panelStroke` hairline + parchment texture overlay at `panelTextureOpacity` (≤ 0.08 enforced by tokens), NO drop shadow; active = faint glow lift only. Legacy palette-based variant kept for other call sites (deprecated comment).
- Modify: `ihsan/Today/Components/FocusedPrayerCard.swift`:
  - `PrayerSymbolBadge` → `PrayerMarkerOrnament(prayer:size:30:state:tokens:)` (state derived from moment/log).
  - Chevron killed; collapsed unlogged tap → expand; logged tap → edit sheet (onMoreOptions); expanded gains quiet "MORE OPTIONS" inscription link.
  - Active state hierarchy: name pair primary (serif + Arabic at matched optical size), secondary small caps `inkSecondary` "NOW · UNTIL 6:15 AM"; no giant numerals in-window.
  - Upcoming: primary numeral = prayer time (`title` monospaced), inscription countdown "OPENS IN · H:MM:SS".
  - Copy: "PRAYING NOW" → "NOW"; passed-unlogged: "WINDOW CLOSED h:mm"; logged uses real `loggedAt`.
  - All `IhsanCelestialPalette.current()` reads replaced by passed `tokens`.
- Modify: `ihsan/Today/TodayScreen.swift` — passes tokens + moment-derived state; `RepairPausedCard`/`DuhaQuietCard` call sites keep compiling (tokens already threaded for Repair card).
- Modify/Create: `ihsanTests/FocusedCardModelTests.swift` — extract pure `FocusedCardModel.resolve(...)` (phase, inscription copy, countdown target) and test: upcoming/active/logged/passed states; no "PRAYING" copy; countdown target strictly future; 0:00:00 never rendered.

- [ ] Failing tests; implement; app builds + tests PASS.
- [ ] Commit.

### Task 10: Global rule documentation + polish findings

**Files:**
- Modify: `Packages/IhsanDesignSystem/README.md` — add "Flat + luminous" global rendering rule verbatim-ish: no 3D shading, no speculars, no volume gradients, no drop shadows on celestial bodies/ornaments/panels; depth = glow, bloom, layered opacity only; text legibility inkHalo is the sanctioned exception.
- Modify: `POLISH_FINDINGS.md` — append device-verification items: 1 s full-scene tick power/thermal, sun edge-lessness on OLED at 2×, band/ground step visibility, marker label Dynamic Type, VoiceOver phrasing changes, Arabic optical size.
- [ ] Write; commit.

### Task 11: Debug verification hooks + simulator verification + push

**Files:**
- Modify: `ihsan/App/IhsanApp.swift` / `RootGate` — DEBUG-only launch args: `-IhsanDebugCompletedOnboarding` (marks onboarding complete at launch), `-IhsanDebugLogPrayer <prayer>:<status>` (routes through `LogPrayerWithStatusIntent` — single funnel preserved).
- Verification script: `scratchpad` Swift/python pixel sampler.

Steps:
- [ ] Full test pass: all touched packages via `swift test`; app suite via `xcodebuild test`.
- [ ] Boot iPhone 17 Pro sim; `simctl location set` (e.g. NYC 40.71,−74.01); grant location; install app.
- [ ] Screenshot × 4: real time; `-IhsanNowOverride` mid-morning (~10:30); 1 min before Maghrib (capture before AND ~90 s later to witness the atomic Asr→Maghrib transition, item 3); inside the last third (~04:00). Logged-state screenshot via debug log arg (item 18: upcoming/active/logged all captured).
- [ ] Pixel-sample screenshots: sky vs band vs ground values distinct; filament present; sun edge test (no detectable disc boundary: radial profile monotonic, no step > threshold); solar-noon apex spot-check with a noon override.
- [ ] Header NEXT text equals focused marker time (read from screenshots).
- [ ] Fix anything that fails; re-verify.
- [ ] Final commit; `git push origin main`.

## Self-review notes

- Spec coverage: items 1–18 map to Tasks 1–11 (1→T1/T4; 2→T2; 3→T2/T4/T9; 4→T4; 5→T5; 6→T3; 7→T6; 8→T6; 9→T7; 10→T8; 11→T8; 12→T8; 13→T7; 14→T8/T10; 15→T9; 16→T9; 17→T9; 18→T11).
- Watch app: untouched (mirrors old components; out of scope, still compiles because package changes are additive; `PrayerTimesProviding` gains only a protocol-extension method).
- Mocks: `NotificationSchedulerTests` mock conforms unchanged.
