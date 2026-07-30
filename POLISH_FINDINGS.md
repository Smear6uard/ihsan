# Polish Pass — Findings That Require Device Verification

This file collects items the source-only polish pass surfaced that
either need a real device to verify or sit just outside the scope of
the polish pass itself. Maintainer: please walk these with a device
in hand before App Store submission.

## Animation timing (Category 1)

- **Tab bar drag-commit feel**. Spring is at the spec'd 0.35/0.85,
  matching the rest of the app. Spec called out a comparison to
  Apple Music's tab swipe — please feel-check side-by-side on a
  device. CustomTabBar.swift:197.
- **Live Activity pre-adhan → adhan-window transition**. Not changed
  in this pass. ActivityKit's animation surface is constrained;
  changes need on-device verification of how the lock-screen and
  Dynamic Island animate the state flip. PrayerActivityWidget.swift.
- **Status pill keyframe beat**. New 0.95 → 1.0 scale + 0.65 → 1.0
  opacity beat fires on every status change. Verify it doesn't feel
  twitchy when changing through the confirmation dialog quickly.
  TodayPrayerList.swift StatusPillBeat.

## Dynamic Type (Category 2)

- **Hero countdown at .accessibility5 on iPhone 15 base**. Now
  shrinks via minimumScaleFactor(0.5). At the smallest supported
  phone width × largest text size, confirm the resulting size is
  still readable, not eye-strain small. TodayHeroSection.swift:42.
- **Tab bar labels at .accessibility5**. minimumScaleFactor(0.7)
  on lineLimit(1) — confirm "Trajectory" / "Reflection" still read
  at this scale on a phone-narrow tab.
- **PerPrayerRow trailing count column** (72pt fixed width). Holds
  shape via minimumScaleFactor(0.7); confirm the "30/30" string
  doesn't visually crowd at large sizes.

## VoiceOver (Category 3)

- **Pronunciation of religious terms**. iOS VoiceOver may mispronounce
  "qada" (qa-DAH not KAY-duh), "jama'ah" (ja-MAH-ah), "iftar",
  "suhoor", "Maghrib", "Isha". If these read wrong, they need
  `.accessibilitySpeechIPANotation` overrides at use sites — out of
  scope for this pass.
- **Heatmap dot rotor order**. Each dot is now its own VO stop. Confirm
  in Accessibility Inspector that the focus order is left-to-right,
  top-to-bottom (chronological), not the reverse.
- **Compass alignment value**. Now reads "Off by 12 degrees right.
  Turn right to align." The "right" / "left" interpretation assumes
  the user is looking at the screen face — verify this is intuitive
  with VoiceOver in actual use.
- **Reflection announcements**. "Recording started" / "Recording
  stopped" / "Transcribing audio" fire as accessibility announcements.
  iOS 17+ AccessibilityNotification.Announcement queues these;
  confirm they don't interrupt other speech mid-sentence.

## Reduce Motion (Category 4)

- **DaylightWallpaper bug fix**. Reduce Motion no longer freezes
  the wallpaper at first-render time — it now still updates every
  30 s but skips the cross-fade. Verify on device with Reduce Motion
  on at launch that the wallpaper appears at sunrise/maghrib as
  expected.

## Color contrast (Category 5)

The design system's mathematical contrast tests
(`Packages/IhsanDesignSystem/Tests/IhsanDesignSystemTests/ColorContrastTests.swift`)
pass:

- textPrimary on ground ≥ 7.0 (WCAG AAA).
- textSecondary on ground ≥ 4.5 (WCAG AA).
- textMuted on ground ≥ 3.0 (AA large text only — README documents
  this is not for body copy).
- atmospheric < 3.0 (intentionally non-text).

What the source pass cannot verify and needs device measurement:

- **Hero countdown over the daylight wallpaper at peak intensity.**
  The hero card uses `.ihsanGlassHero()` (iOS 26 native glass +
  adaptive tint at 0.26 opacity). When the sunrise / maghrib photo
  is at full opacity (±0 min from the centre of the window), the
  brightest pixels of the photo are at the horizon band, which is
  near the top of the visible wallpaper area. The hero card sits
  below the header but above mid-screen, so it overlaps the upper
  part of the photo. iOS 26's Liquid Glass is engineered to handle
  this; please verify the white countdown digits still read clearly
  with Color Contrast Calculator app or Accessibility Inspector,
  shooting screenshots at exactly sunrise and maghrib local time.

- **Today header city + Hijri lines over the wallpaper.** These use
  textSecondary (0.70) and textMuted (0.40) WITHOUT a glass card
  underneath — they sit directly over whatever is behind. During
  the wallpaper window, that's the bright sky band of the photo.
  If contrast fails on device, the prescribed fix per spec is a
  subtle dark gradient scrim at the top of TodayScreen, sized to
  cover only the header band, fading to transparent below. Not
  applied in this pass because the wallpaper window is brief
  (< 30 minutes total per day) and the visual impact of a scrim
  during the wallpaper moment may compromise the time-of-day
  identity. Maintainer call.

- **StatusPill "Missed" state.** Text colour is white at 0.30
  opacity by design — the README explicitly documents that no
  status uses punitive treatment, and Missed is intentionally
  faded. The text is small caps so it falls under "small text" in
  WCAG terms, where 0.30 white on a light glass background is
  below AA. This is a design-intent choice, not a bug; flag here
  so the maintainer can decide whether to keep the design or
  raise the opacity. StatusPill is in IhsanDesignSystem (off-limits
  to this pass).

- **Tab bar unselected labels.** Use textMuted (0.40) on the glass
  surface. This is intentionally subdued so the selected tab reads
  as the focal point. Same call as above — design intent vs pure
  WCAG.

## Edge cases (Category 6)

Items added in this pass (need device verification):

- **iOS Qibla compass-unavailable state**. New
  `QiblaState.compassUnavailable(snapshot)` triggered when
  `CLLocationManager.headingAvailable()` is false. Renders bearing
  + distance + a one-line explanation, no dial. Walks through on
  iPad Pro M-series (no compass) — confirm the state appears, not
  the regular dial frozen at North.
- **Orphan voice-memo cleanup at launch**. New
  `ReflectionAudioPaths.cleanupOrphans(knownMemoIDs:)` invoked from
  RootGate.task on every cold launch. Best-effort; minAge guard of
  5 min so an in-flight recording from a previous session can't be
  swept on relaunch. Verify by:
  1. Start recording (file appears in App Group container).
  2. Force-quit while still recording.
  3. Wait > 5 min.
  4. Cold launch the app.
  5. Confirm the orphan .m4a is gone.
  Then verify the inverse: a saved Reflection's audio is NOT
  swept (its UUID is in the known set).

Items already correct, audited but unchanged:

- **First launch with no location permission** — TodayState /
  MasjidFinderState / QiblaState all carry a
  `.needsLocationPermission` case with a permission-prompting view
  (TodayScreen.swift:51, MasjidFinderScreen.swift:62,
  QiblaScreen.swift:41). Onboarding owns the initial prompt;
  these states catch the post-onboarding "settings → off" case.
- **Apple Intelligence absence** — InsightCard checks
  `SystemLanguageModel.default.availability` under
  `canImport(FoundationModels)` and renders nothing when the model
  isn't available (InsightCard.swift:51-60). No greyed state, no
  upgrade prompt — exactly the spec'd silent-hide behaviour.
- **No Dynamic Island (iPhone 14 base, etc.)** — handled by
  ActivityConfiguration's automatic fallback to lock-screen-only
  rendering. Verify on a real iPhone 14 base.
- **Apple Watch without compass** — `ihsanWatch/Qibla/QiblaView`
  already has a `compassUnavailable` state with bearing + distance
  fallback (QiblaView.swift:121-139). The iOS-side change above
  brings parity.
- **AudioRecordingService interruption** — phone calls / Siri /
  alarms post `AVAudioSession.interruptionNotification`; the
  service's `handleInterruption` finalises the recording so the
  user sees what was captured rather than a stuck "Recording…"
  state (AudioRecordingService.swift:212-226).
- **App-Group container missing** — `IhsanModelContainerFactory`
  falls back to in-memory if the shared store fails
  (IhsanApp.swift:15-24). Same pattern handles the iCloud-signed-
  out edge: SwiftData's CloudKit sync degrades to local-only
  silently.
- **IhsanFiqhConfig fetch failure** — `FiqhConfigService` ships a
  bundled config and falls back to it on network failure (see the
  package's `BundledConfigParsingTests`).
- **Reinstall** — bundled fiqh config covers the cold-start
  prompts; CloudKit-synced PrayerLogs and Reflections restore from
  the user's iCloud once auth completes. Audio memos do NOT sync
  by design (privacy; raw audio stays on the device that recorded
  it) — verify a reinstalled app shows feed cards in
  `voiceMissing` shape for memos whose audio doesn't exist locally.

Items needing pure device verification (no source change possible):

- **Force-quit during prayer logging**. SwiftData persists on
  every `setStatus` / `toggleJamaah` call; relaunch should show
  the last persisted state. There's no in-flight transaction state
  in TodayViewModel that could be lost. Confirm on device by
  force-quitting mid-tap.

## Pre-existing build warnings (out of scope, flagging)

- `ihsanWidgets/LiveActivities/PrayerActivityWidget.swift:282 / :286`
  — `@available` on @Parameter properties of DismissPrayerActivityIntent
  emits "setter cannot be more available than enclosing scope". The
  inner `@available(iOSApplicationExtension 16.2, *)` annotations are
  redundant with the enclosing struct's annotation and can likely be
  removed. Touching them risks the LiveActivityIntent macro behaviour;
  a separate cleanup commit with device verification.

- `ihsan/Reflection/Services/AudioRecordingService.swift:33`
  — `'nonisolated(unsafe)' has no effect on property
  'interruptionObserver'`. Compiler suggests `nonisolated`. Pre-existing,
  unrelated to this polish pass.

## Repair feature (feat/repair) — device verification needed

- **Haptic-to-tap latency on "+1 made up"**. `Haptics.impact(.soft)` is
  the first statement in `RepairViewModel.logMadeUp` — before any
  SwiftData write — so the <50ms budget holds by construction, but the
  acceptance criterion is a screen recording. This Mac cannot build the
  app scheme (watchOS platform unavailable); record on device.
- **Dynamic Type .accessibility3 on every setup screen and
  .accessibility5 on the Repair detail screen**. All Repair text is
  multiline-friendly (`fixedSize(horizontal: false, vertical: true)`,
  no fixed text frames), but `IhsanFont` tokens are fixed-size by
  design — confirm legibility on device like the rest of the app.
- **Reduce Motion on the thread**. `RepairThreadView` gates its growth
  animation on `accessibilityReduceMotion`; the `withAnimation` wrap
  around row collapse in `RepairDetailScreen` should also be spot-checked
  with Reduce Motion on.
- **VoiceOver order** on the Repair detail screen (thread → quiet counts
  → pace line → category rows) and the zero moment's single line.
- **Control Center glyph**: controls only accept symbol images, so the
  control ships with `arrow.uturn.backward` (the app's canonical qadā
  mark per `StatusPill`). If a bespoke ornament is wanted there, author
  a custom SF Symbol asset from the Lawzina outline in a follow-up.
- **Excused-pause serene state**: confirm on device that the paused
  Today card reads as rest (marker outlines, no glow) across all four
  palette states, and that beginning/ending a pause from the log sheet
  droplet suppresses/restores scheduled notifications (inspect Pending
  Notifications in Console or the debug scheduler dump).

## Night intelligence (phase 3, divided night) — device verification needed

- **Screenshots at the three night moments**. The acceptance criteria
  are device captures at post-Isha, at nisf al-layl, and inside the
  last third. This Mac cannot build the app scheme (watchOS platform
  unavailable); capture on device. The last-third capture should show
  the luminance lift, the brighter cursor halo, and both small-caps
  inscriptions clear of the sinking sun/moon traces.
- **Daytime pixel diff**. The night layer is compiled behind
  `if let night, night.contains(date)` in `CelestialPlateScene.scene(at:)`
  and no daytime drawing path changed (verify with `git diff 8774eba..`
  on the scene: additions only). The acceptance criterion is still a
  screenshot diff of a daytime capture against a pre-phase build —
  take both on device at a fixed `timeOverride`.
- **Luminance lift subtlety on OLED**. The last-third region fills with
  `groundBottom.scalingLightness(by: 0.82)` against the subterranean
  plane at `0.72` — one lightness step apart, same hue. Whether the
  step reads as "barely brighter" or as a hard contour at night-time
  brightness is an OLED question; check at minimum screen brightness
  with True Tone off.
- **Night inscriptions at Dynamic Type .accessibility5**. "Midnight"
  and "Last third" are engraved at the plate's fixed 10 pt small-caps
  size (matching the marker time labels, which are also fixed) and are
  `accessibilityHidden`; the information is carried by a VoiceOver
  summary element ("Night. Islamic midnight 12:58 AM; the last third
  begins 2:52 AM."). Confirm VoiceOver reads the summary once, and
  that the fixed-size engravings stay legible on device.
- **Reduce Motion / Reduce Transparency at night**. The night layer is
  static per evaluation (no new animation; the cursor halo is a fixed
  radial, not a pulse). Under Reduce Transparency the halo collapses to
  a flat disc. Spot-check both toggles during the last third.

## Sunnah layer (phase 4) — device verification needed

- **Off-state pixel parity**. Every sunnah surface is gated on
  `sunnahLayerEnabled` (default false): the focused card's rawatib
  strip and night row take `nil` models, the duha card and Path toggle
  render nothing, and Set shows only the single opt-in row with its
  quiet description. The acceptance criterion is a walkthrough of a
  fresh install against a pre-phase build — screens must be
  indistinguishable. Verify on device.
- **Focused card fixed bound with the strip revealed**. The expanded
  state adds a 20 pt rawatib row inside the fixed 140 pt card; layout
  compresses the spacer, but the jamaʿah pill + commit buttons must
  stay fully visible with the strip revealed at default type size —
  and degrade gracefully at Dynamic Type .accessibility5 (fixed-size
  IhsanFont inscriptions, same standing caveat as the rest of the
  card).
- **Chip haptic latency**. `Haptics.impact(.soft)` is the first
  statement in every nafl chip tap (card chips, duha card) before the
  intent Task — <50 ms by construction; confirm by recording.
- **Duha card and the plate**. When the duha window is open the plate's
  bottom inset grows by 54 pt; confirm no marker or label slips behind
  the card during the window, across all four palette states.
- **Rak'ah dialog**. Only appears when "Ask for rak'ah counts" is on
  and the tap would record (never on removal). Confirm VoiceOver reads
  the chip value change after the dialog commits.
- **Path overlay row alignment**. The sixth row's outlined stars must
  sit exactly under their columns at 7D/30D/90D/YEAR on device widths
  where the grid squeezes (mini-width iPhones, 90 columns).

## Gentle wake (phase 5) — device verification needed

- **Timed alarm test at a simulated last third**. The acceptance
  criterion is a device run: set the device clock (or a debug offset)
  so the last third begins minutes away, enable the wake in Set, lock
  the device, and confirm the AlarmKit alarm fires with the bundled
  chime and the "Rise" stop button. This Mac cannot build the app
  scheme; the planner/coordinator logic (pause suppression, offset,
  reschedule-on-location, tonight→tomorrow fallover) is covered by
  unit tests in IhsanNotifications.
- **Fallback path on device**. Deny alarm permission, re-enable the
  wake, and confirm (a) Set shows the plain fallback note, (b) a
  time-sensitive notification `ihsan.nightwake` is pending instead of
  an alarm, and (c) it survives a prayer-notification rebuild (its
  identifier sits outside the `ihsan.prayer.` prefix).
- **Time-sensitive entitlement**. `com.apple.developer.usernotifications.time-sensitive`
  was added to ihsan.entitlements; the App ID in the Developer Portal
  must have Time-Sensitive Notifications enabled before archiving.
- **Placeholder chime quality**. `ihsan/Night/night-wake-chime.caf` is
  a synthesized 12-second bell (soft strikes, gently rising) meant as
  a stand-in. Confirm it plays for both AlarmKit (`.named`) and
  UNNotificationSound on device — asset-name resolution for AlarmKit
  sounds is undocumented territory; if the alarm falls back to the
  default tone, try the name without the `.caf` extension in
  `NightWakeSound.assetName`. Replace with the final asset at the
  same constant.
- **Cross-midnight wake**. Enable the wake in the evening, keep the
  device untouched past midnight, and confirm the alarm still fires at
  the last third computed from *yesterday's* Maghrib (the
  candidate-nights logic covers it; verify end-to-end on device).


## Today corrective — state integrity + composition (2026-07-29)

Source-side work is unit-tested and simulator-screenshot-verified;
these need a device:

- **One-second full-scene tick.** TodayReadyView now drives the whole
  page (sky canvas, markers, card) from a single 1 s TimelineView.
  Simulator profiling shows nothing alarming, but verify power/thermal
  behavior and scroll-adjacent jank on device, especially with the
  always-animating horizon-glow band near sunset.
- **Sun edge-lessness on OLED.** The rebuilt sun (core dissolving into
  corona, plusLighter on jewel grounds) must show no detectable disc
  edge at 2× zoom on a real OLED — the acceptance test in the spec.
  Screenshot analysis passes in the simulator's sRGB pipeline; OLED
  gamma may differ.
- **Horizon band + ground step visibility.** Wash opacities were
  raised (0.70/0.42) and the subterranean step deepened (×0.60 dark /
  ×0.88 light). Confirm the band reads as atmosphere, not banding, on
  device — and that the deepened night ground doesn't posterize.
- **Marker two-line labels at large Dynamic Type.** Name-over-time
  labels are fixed 10 pt engravings (decorative, VoiceOver-hidden);
  confirm the ornament + label block doesn't collide with the card at
  accessibility sizes on compact devices.
- **VoiceOver phrasing changes.** Card now says "in its window until
  6:15 PM" (copy rule: describe the window); markers unchanged.
  Verify pronunciation of "Jamā'ah" and "Qadā" clauses in the logged
  card inscription.
- **Arabic optical size on the card.** The Latin+Arabic name pair uses
  IhsanFont.heroPrayerName + bodyArabic (system Arabic, +2 pt optical
  match). Verify the pair reads balanced on device; a dedicated Naskh
  face is a future asset decision, not a source change.
- **Cold-launch after iCloud sign-out.** CloudAccountGate runs
  local-only from the launch *after* the account disappears (cache is
  one launch behind by design). Sign out of iCloud on a device,
  launch twice, and confirm exactly one gate log line and no
  NSCloudKitMirroringDelegate retry spam on the second launch.


## Corrective E — ornament, engraving, ground plane (2026-07-29)

Source-side work is unit-tested and simulator-screenshot-verified
(silhouette grid, knockout close-ups, three-time gilding, all four
grounds, tab bar on all four grounds); these need a device:

- **Five-second test.** The corrective's closing acceptance is the
  maintainer's own device read of the reworked page — warm ivory
  ground, 65:35 chord, gilded passage — across the four states.
- **Gilded-arc warmth on OLED.** The traversed arc is metalHighlight
  at 0.62 over base metal 0.34. Confirm the gild reads as light on
  the line (not a second, thicker line) on OLED gamma, especially in
  the sunset state where the highlight pole is brightest.
- **Chrome tint under refraction.** The tab bar's new warm backing
  (panelFill→horizonWash mix at 0.72 behind the glass) reads warm and
  quiet in the simulator's glass rendering; verify no olive cast
  returns under real-device Liquid Glass refraction while scrolling
  content behind the bar.
- **Compact night bowl legibility.** With the 65:35 ground the
  divided-night bowl renders in its compact form (arc + midnight
  mark + cursor, no region fill, labels hidden). Confirm the
  miniature still communicates nisf al-layl and the cursor's travel
  at arm's length, and that the full bowl (with labels) still
  appears in layouts that leave it ≥60 pt of depth (paused card,
  larger devices).


## Corrective F — the illumination pass (2026-07-29)

Source-side work is token-tested and simulator-verified (gilded
close-ups, morning before/after, grayscale gate PASS at 0.0165 min /
0.9994 max relative luminance, entrance + ambient + Reduce Motion
recordings, host frame-time probe at 0.038 ms avg); these need a
device:

- **Five-second test, all four SkyPhases.** The pass's whole point:
  does the day state now read as the manuscript itself rather than a
  drawing of one — solid leaf with dark keylines, lapis chord,
  stretched value range, living scene.
- **Log-materialization in hand.** The outline→gold pour (~300 ms,
  scaling mask) is implemented as a state-change animation and plays
  wherever a marker or chip flips logged; simulator runs can only
  seed logs at launch, so verify the tap-synchronized feel (haptic +
  pour together, undo reversing) interactively.
- **Entrance and ambient at device refresh.** Host probe puts the
  draw closure at 0.038 ms avg / 0.337 ms max (budget 4 ms), and the
  ambient breaths modulate one layer's opacity at ≤30 Hz — but 60 fps
  under ProMotion with the breathing glow + corona must be confirmed
  with Instruments on hardware.
- **Breathing perceptibility.** The current ornament's ±10% / 5 s
  glow breath and the corona's ±3% / 7 s variation are tuned to be
  felt, not seen, at arm's length on OLED — check they neither vanish
  nor read as pulsing.
- **Vellum grain at 4.5% on OLED.** Raised to the threshold of
  visibility at arm's length in the day states; confirm it reads as
  material, not noise, and that night grain (unchanged 3%) still
  masks gradient banding.


## Qibla instrument rebuild — phases 1–4 (2026-07-29)

Source-side work is unit-tested (63 engine/choreography/guidance tests
in IhsanCore) and simulator-verified (day + night grounds, all approach
stages, aligned + settled, calibration, hold-flat, denied, no-compass,
AX5 Dynamic Type, Reduce Motion discrete states, ~62 fps sim recording,
6/6 single-fire alignment haptics in the event log); these need a
device:

- **The outdoor turn.** The whole acceptance bar: standing up,
  turning in place, does the approach choreography read as a gradient
  of arrival and the alignment moment feel like a fine instrument
  seating. τ = 0.18 s EMA tuned for weighted-not-laggy — judge on
  hardware, outdoors, away from interference.
- **Haptic balance.** Detents are `.light`, the alignment seat is
  `.soft`; single-fire is guaranteed by the tested latches, but the
  intensity balance (two ticks + one seat) needs the hand.
- **Smoothed-vs-raw field capture.** Launch with
  `-IhsanQiblaHeadingLog` and turn: QIBLA-TRACE lines carry raw vs
  smoothed vs delta for filter verification against the synthetic
  trace in `HeadingFilterTraceTests`.
- **VoiceOver walk with screen curtain.** The guidance script
  (entry orientation → banded updates → "Facing qibla") is
  unit-tested and log-verified; the end-to-end find-the-qibla-by-ear
  walk needs VoiceOver on hardware with the compass live.
- **True-heading fallback.** In areas of high declination, confirm
  the automatic magnetic fallback shows the MAGNETIC NORTH maker's
  mark and the dial remains honest.
- **Calibration + tilt thresholds.** Poor-accuracy entry/exit
  (>20°) near magnetic interference, and the hold-flat hysteresis
  (tilt in below |g.z| 0.45, recover above 0.60) — verify neither
  flickers in normal handling.
- **OLED glow floors.** The lancet's standing glow (0.22) and the
  bloom's single breath were tuned in the simulator; confirm the
  standing glow neither vanishes nor hums on OLED, and the bloom
  reads as one calm breath, not a flash.

## Corrective G — night integrity, painted horizon, sheet finish (2026-07-29)

Source-level work is tested (contrast math, property tests, geometry
tests); these need eyes on hardware:

- **Timing tiles at 50% brightness.** All four tile ornaments (On
  Time / Late / Qadā / Missed) pass ≥3:1 silhouette contrast against
  their tile mathematically in all four palettes
  (`PrayerLogSheetContrastTests`). Confirm on OLED at ~50% brightness,
  day and night grounds, that the qadā lapis+gold roundel and the
  deepened late outline read at arm's length.
- **Ground filaments on OLED.** The engraved ground echoes were
  lifted to 0.46/0.30/0.18 metal on the jewel grounds — confirm
  visible-at-arm's-length at sunset and night without reading as
  ruled lines.
- **Night-bowl gilding.** The traversed night filament
  (metalHighlight 0.60, taper dissolving at the cursor) was tuned in
  the simulator; confirm the gilded passage reads as one line burning
  to "now" on OLED, and that the day arc's heavier gild ribbon (2.6pt
  over 1.6pt base) reads as weight, not blur.
- **Moon earthshine.** Earthshine dropped to 0.30 over the dark limb
  with a 0.75pt limb rim; confirm the dark limb neither vanishes on
  OLED black nor reads as a full disc at 50% brightness.
- **Sun bloom locality.** The horizon filament brightening dies
  within 35% of screen width of the sun — confirm at sunset that the
  falloff reads as painted light, with the far side of the chord
  staying quiet gold + lapis.
- **Sheet detent fit.** The log sheet's content-sized detent was
  verified at standard type; walk the accessibility type sizes and
  confirm the clamp + scroll handoff has no jump.

## House phase 0 — the commit path (2026-07-30)

The log sheet's dead commit was a process-level container split: the
intent funnel lazily built a second CloudKit-mirrored ModelContainer
over the store the app was already mirroring (CoreData 134422
"another instance of this persistent store is actively syncing"),
so sheet commits never reached the container the UI's @Querys
observe on an account-active device. Fixed by registering the app's
container as the process-wide shared instance
(`IhsanSharedModelContainer`); pinned by `PrayerLogCommitUITests`
(fresh + edit paths) and `LogPrayerWithStatusIntentTests`. Verified
in the simulator (no iCloud account there — the 134422 conflict is
account-gated); these need eyes on signed-in hardware:

- **Commit on an account-active device.** Tap commit on the sheet:
  the sheet dismisses, the focused card and plate ornament gild, and
  Path reflects the entry — with an iCloud account signed in and
  CloudKit mirroring live. Console should show no CoreData 134422.
- **Materialize + haptic fire once.** The ornament-materialize
  animation and the success haptic on commit fire exactly once per
  commit (haptics are untestable in the simulator).

## House phase 0.25 — sheet truth pass + retroactive logging (2026-07-30)

Availability math, commit copy, and both retroactive entry points are
pinned by tests (TimingAvailabilityTests property sweep,
PrayerLogCommitUITests, RetroactiveLogUITests); these need hardware:

- **Dimmed tiles at 50% brightness.** Unavailable timing tiles render
  at 0.5 opacity — mathematically ≥1.9:1 in all four palettes
  (`unavailableTilesStayPerceptibleInEveryPhase`). Confirm on OLED at
  ~50% brightness that a disabled tile still reads as present-but-
  quiet, day and night, and that the qadā roundel specifically
  survives the dimming.
- **Retro sheet from Path.** The ledger sheet rides the clock-derived
  approximate SkyPhase (no solar schedule on Path yet). Confirm the
  sheet's backing doesn't clash against the Today plate when
  switching tabs at sunset (the approximation can lag the real sky
  by tens of minutes).

## House phases 0.5–4 — chrome, pages, sweep (2026-07-30)

Source-level work is pinned by tests (PageChromeContrastTests across
all four phases, TimingAvailability property sweep, six UI tests);
these need eyes on hardware:

- **Native bar minimize feel.** `.tabBarMinimizeBehavior(.onScrollDown)`
  verified in the simulator; confirm the recede/return timing and the
  content lensing read well on device, on all four tabs.
- **Path glance test (the maintainer's own gate).** From arm's
  length, a month of mixed states should read as a texture before
  any dot is inspected — morning, sunset, and night grounds.
- **VoiceOver walk of the Path pattern.** The gestalt grid is ONE
  element with a per-period summary; day rows and day×prayer cells
  announce per-day summaries ("Dhuhr, Saturday, August 15, qadā").
  Confirm the rotor order feels like days, not dot noise, on device.
- **Dynamic Type at accessibility sizes.** Body copy scales; the
  day×prayer ledger and the feed-card date are deliberately capped
  (xxxLarge / accessibility1) so dates don't wrap per-glyph. The
  serif page titles and small-caps inscriptions are fixed-size
  registers (IhsanFont) — decide on-device whether the titles should
  adopt scaled metrics in the polish pass.
- **Approximate-phase seams.** Secondary pages ride the clock-derived
  SkyPhase.approximate (fixed 6:00/13:00/19:00/20:30 anchors), not
  the solar schedule; near sunset the Today plate and the page
  grounds can disagree by tens of minutes. Confirm tab switches near
  maghrib don't jar; if they do, the fix is feeding the real solar
  events into the page chrome.
- **Legacy note.** The v1 celestial palette (parchment family)
  survives only under the Today screen's Duha card and the no-token
  celestialPanel variant — untouched here (celestial plate is out of
  scope); fold into the celestial polish pass.

## Wider-worship pass (dawn, Hijri, fasting, dhikr) — device items

Source-level work is pinned by tests (dawn in every contrast suite,
Fajr-window and closed-tense properties, DST countdown anchors, the
V3→V4 seeded migration, the banned-language sweep, a driven 33-count
UI cycle); these need eyes and hands on hardware:

- **Dawn on OLED.** The fajr→sunrise progression (indigo lightening,
  stars thinning, the growing east wash, the sunrise crest) was tuned
  on simulator captures at 20-min-post-Fajr / 5-min-pre-sunrise /
  10-min-post-sunrise. Confirm the pre-sunrise mid-crossing (the
  deliberate "lamps come on" passage) doesn't read gray on device,
  and that the below-horizon sun truly renders no disc to the eye.
- **The wall-time override habit.** `-IhsanNowOverride` now accepts
  local wall time ("2026-07-30T05:27:00", no suffix) — DST-proof.
  Explicit-offset forms are honored as written; review recipes
  should prefer the suffix-less form from here on.
- **Dhikr haptic signature.** Soft tap per count, one distinct
  success at 33 — felt right in code review; the rhythm's
  count-without-looking quality is a hand test. VoiceOver speaks
  only 11/22/33 by design (chatty per-tap counts defeat the rhythm);
  confirm with a VO user that the waypoints suffice.
- **VoiceOver walk of the new surfaces.** Hijri sheet cells announce
  "Safar 14, today, white day"; the significant-day line hints
  dismiss vs. record-intention; the fasting inscriptions and the
  Ramadan offer are labeled buttons; the tasbīḥ ring is one element
  with a custom count action. Confirm rotor order on device.
- **Fixed inscriptions at accessibility sizes.** New surfaces use
  scaled text styles (the Hijri sheet grid scales, numerals fit
  their cells at accessibility5); the fasting/sunrise inscriptions
  and plate labels remain the app's fixed small-caps register —
  fold into the app-wide functional-text rule in the polish pass.
- **Tab bar linework glyphs.** The bar now draws the app's own set
  (day arc, gestalt dots, book, engraved dial) as template images —
  confirm optical weight against the system glass at both sizes,
  and that selected-state tinting reads on the day grounds.
- **Approximate-phase seams — CLOSED.** Page chrome now rides the
  published real solar events (IhsanPageChrome.publish) with the
  clock anchors only as the cold-launch fallback; the earlier
  tens-of-minutes disagreement near maghrib no longer exists.
