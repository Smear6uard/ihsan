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

## Ship pass — device verification

Items the simulator cannot settle. Each was left as found and needs a
device to judge.

- **Scroll edge under the floating tab bar.** Secondary pages now carry
  `.scrollEdgeEffectStyle(.soft, for: .all)` and 96 pt of bottom
  clearance, which is the system treatment. In the simulator a row at
  the foot of a long list still reads through the bar's material more
  than it should; the simulator renders `.glassEffect` materials
  differently from hardware, so this needs a device before deciding
  whether anything further is warranted.
- **The settle haptic's physical character.** `Haptics.settle()` is one
  soft impact at 0.85 intensity, chosen for a weight coming to rest
  rather than a click. The simulator has no Taptic Engine; the feel
  across all seven commit sites (prayer, fast, nafl, dhikr boundary,
  qibla alignment, reflection save, yesterday's sheet) needs a hand.
- **StandBy on hardware.** The nightstand face is measured against a
  red-only worst case in `ShipPassContrastTests` and holds AA, but
  Night Mode's actual tint and the display's low-brightness behaviour
  are not reproducible in a simulator.
- **Entrance choreography at 60 fps.** The draw loop is inside its 4 ms
  CPU budget per `RenderPerformanceTests`, and the choreography's order
  and timings are pinned by `EntranceChoreographyTests`. Whether the
  0.9 s sequence *feels* right, and holds 60 fps on the oldest
  supported device, is a device judgement.
- **VoiceOver pronunciation.** The walk asserts every interactive
  element has a label and that markers voice prayer, time, and state.
  How the speech synthesiser says "Qadā", "jamāʿah", and "takbīrāt" —
  and the Arabic prayer names — needs listening to.

## Adhkar — Arabic typography (phase 1)

The typography gate can be opened on device with:

```
xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large
xcrun simctl launch <udid> com.sameerstudios.ihsan \
    -IhsanDebugCompletedOnboarding -IhsanDebugAdhkarTypeGallery \
    -IhsanDebugAdhkarGround night
```

The ground buttons across the top switch between the five SkyPhases;
the type size comes from the device's own setting.

- **Arabic at arm's length.** `ArabicTypographyTests` shapes every
  shipped text through CoreText and proves the ink of a line fits its
  line box at every register and every Dynamic Type scale — but it
  measures the macOS build of SF Arabic, and it cannot judge colour,
  weight, or how the page reads. The gallery is the other half of the
  gate and it needs eyes on a real display.
- **SF Arabic versus a bundled Naskh.** iOS 26 always ships SF Arabic
  and Geeza Pro; Mishafi, Damascus, Al Nile and Farah are optional app
  fonts. SF Arabic was chosen on mark positioning and Dynamic Type
  support, and nothing is bundled. If the maintainer's eye disagrees
  at reading size, the decision is one token
  (`IhsanArabicType.font`) and a licensing question, not a rewrite.
- **The three reading registers.** 32 / 25 / 21 pt, chosen from the
  actual length distribution of the content file and pinned by a
  CoreText typesetting test against a phone-width column. Whether the
  step from 32 to 21 pt reads as one system or as three is a device
  judgement.
- **`.environment(\.dynamicTypeSize, …)` does not drive font
  resolution.** Setting the environment key in a capture harness
  changes what `@Environment(\.dynamicTypeSize)` reports without
  changing the size `Font.system(size:)` resolves to, which makes for
  a convincing screenshot of something that never happens. Use
  `simctl ui <udid> content_size <category>` — the launch argument
  `-UIPreferredContentSizeCategoryName` is also ignored. Verified by
  capturing the same screen both ways.

## Adhkar — device verification (phases 2–4)

Repro recipe for every frame below:

```
xcrun simctl location <udid> set 41.8781,-87.6298     # do this FIRST
xcrun simctl ui <udid> content_size large             # or accessibility-*
xcrun simctl launch <udid> com.sameerstudios.ihsan \
    -IhsanDebugCompletedOnboarding -IhsanDebugEnableAdhkar \
    -IhsanDebugPresentAdhkar morning|evening|postPrayer|sleep \
    -IhsanNowOverride 2026-08-02T06:10:00
```

- **The settle at an item boundary.** Each tap is a light impact and
  each item's transmitted count closes on `Haptics.settle()` — the
  same weight-coming-to-rest every other commit in the app wears. On a
  hundred-count item that is ninety-nine light taps and one settle,
  which is a rhythm the simulator cannot render. It needs a hand.
- **The gilding at speed.** A tap arriving inside the 450 ms a
  completed item rests gilded now advances the set and counts, so
  nothing is lost at a steady rhythm. Whether the advance still reads
  as an arrival rather than a jump, at a real tapping speed, is a
  device judgement.
- **The ungilded mark's new colour.** Pending marks moved from `metal`
  to `inkSecondary` at 70% because metal measures 2.58:1 at worst
  against the day grounds — an uncounted mark nobody can see on a
  bright morning. The composited stroke measures 3.48:1 at worst. This
  also changes the tasbīḥ instrument's ring, which shares the
  component. It is more legible and less brassy; whether the trade is
  right at arm's length is the maintainer's call, and it is one token
  (`RemembranceRingPending.stroke`).
- **The divided ring at small counts.** Counts of three, seven and ten
  draw as arc segments rather than ticks. Verified in the simulator at
  every transmitted count; how the arcs read against the plate's own
  curves on hardware is worth a look.
- **XCUITest sees the steppers, VoiceOver does not.** The ± glyphs in
  `miniCountControl` are `accessibilityHidden` and the control speaks
  as one labelled adjustable element — the correct design. XCUITest
  enumerates the drawn glyphs anyway; verified identically against the
  pre-existing duha-window picker, so this is a query artifact rather
  than a defect, and the adhkar walk excludes them by size. Worth
  confirming with VoiceOver actually running.
- **Simulator location lapses between runs.** Four VoiceOver tests
  failed with "the set did not present" purely because the simulator
  had lost its location fix and the app was still resolving the day.
  Re-issue `simctl location set` before any adhkar run; it is not
  sticky across a long session.
- **Three UI tests fail, and they were failing before this work.**
  `OnboardingUITests.testFirstRunReachesTheLiveAppInUnderAMinute`,
  `PrayerLogCommitUITests.testFreshCommitLogsPrayerAndUpdatesCard`,
  and `PrayerLogCommitUITests.testEditingExistingLogSavesChanges`.
  Verified by running the same two classes from a worktree at
  `7606982` — the last commit before the adhkar work — where they fail
  identically, with the same assertions ("Tapping the question must be
  what raises the dialog", "Choosing a timing must enable the
  commit"). They are not caused by the remembrance layer and were not
  fixed by it. Someone should look at them.


## Corrective H — the illuminated day (2026-08-02)

Source-side work is token-tested, render-tested, and
simulator-verified at all three requested overrides (mid-morning
09:30, 14:00, late-afternoon 17:30, plus a Reduce Transparency pass).
Measured on the host: ramp banding worst row-to-row step 0.0049
(morning) / 0.0054 (afternoon) against a 0.015 bound; gold-dust ink
budget 18% of the vellum grain's; sky speckle mean deviation 0.00335,
peak 0.0797; nothing in the sky field clips at either end; celestial
draw closure 0.060 ms avg / 0.145 ms max against a 4 ms device
budget. These need a device:

- **Five-second test, both day states.** The whole point of the pass:
  at mid-morning and mid-afternoon, does the plate now read as an
  illuminated page in daylight — deep sky overhead grading to a pale
  luminous horizon, engraved field visible, worked ground — while the
  five ornaments and the focused card remain the only things the eye
  goes to first. If the sky competes, the zenith is too deep.
- **Zenith depth on OLED.** The day zeniths moved from a near-white
  tint (Y ≈ 0.67) to a real blue (morning #94BFFB, afternoon
  #A9BEF5, Y ≈ 0.50). The ramp is 17 OKLCH stops and measures clean
  on the host, but a long blue→near-white gradient is the classic
  banding case on OLED gamma. Look for contouring in the upper third,
  especially at low display brightness where dithering has least to
  work with.
- **Secondary ink on the deepened sky.** `inkSecondary` went one
  value step darker on both day states (morning #4A5378 → #3E476B,
  afternoon #4C4668 → #494365) to hold AA against the new zenith —
  it measures 4.79:1 (morning) and 5.00:1 (afternoon) against the
  zenith itself, and ≥ 8:1 everywhere else on the day surfaces.
  Confirm the header's inscription line and the marker times read
  comfortably outdoors, which is the condition this pair exists for.
- **The sun's engraved ray collar.** Twelve ticks at 0.68–0.88 solar
  diameters, `metal` at 0.20. On a phone in sunlight this may fall
  below the threshold of visibility entirely; the brief's bar is
  "found by someone who looks at the sun, never noticed by someone
  reading the card". Check both halves of that. Also confirm the
  collar reads as engraving rather than as a starburst at arm's
  length — the first pass at 0.60–1.05 diameters and 0.34 opacity
  read unmistakably as a lens artifact in the simulator.
- **Gold dust at the threshold.** ~44 flecks over a phone-width sky,
  peak alpha 0.13, versus the vellum grain's ~560 marks at ≤0.045.
  It should read as light barely caught on leaf, never as texture.
  This is the item most likely to disappear on a real display or,
  worse, to read as dust on the screen — check both failure modes.
- **Ground band value range.** The day band's gradient was
  front-loaded (groundPlane → ×0.925 by 22% depth → ×0.86 at the
  bottom) because the focused card covers most of the band and the
  old full-height ramp spent its range where nobody sees it. Confirm
  the exposed ~24 pt strip below the chord now reads as modelled
  earth, and that the deeper floor behind the card and tab bar does
  not muddy the Liquid Glass sampling it.
- **Engraving raised for daylight.** Almucantars ramp 0.10 → 0.22
  with `daylightPresence`, and the three ground filaments now sit
  slightly above their night weights (0.52 / 0.34 / 0.21). Confirm
  they read at arm's length in daylight without the field starting to
  look busy.

### Found, not fixed — out of this corrective's scope

- **The daytime moon renders as a flat gray disc.** Visible on the
  day plate whenever the moon is above the horizon in daylight (see
  it at mid-morning). `lunarDaylightPresence` floors at 0.28 and
  `moonCore`'s lit limb is `mix(ink, metalHighlight, 0.35)` — a dark
  slate — so on a near-white sky the moon reads as a gray coin rather
  than the pale ghost a daytime moon actually is. **This is
  pre-existing**: verified by rebuilding at the pre-corrective-H
  working tree and capturing the same instant, where it is identical.
  It is the single element on the day plate that most competes with
  the five ornaments. Left alone because retuning the moon is not one
  of corrective H's six items and `MoonTreatmentTests` pins the
  treatment deliberately; it wants its own decision.

## Corrective I — the crossing keyline

- **How long the keyline stays fully drawn.** `inkOutlineStrength`
  holds at ≥ 0.99 for about **85 minutes a day** — 48 min around
  sunrise, 37 min around maghrib — computed for Chicago on
  2026-08-02 (ISNA 15°/15°, CDT: fajr 04:13, sunrise 05:44, maghrib
  20:08). That span is *correct* by the contract: it is exactly where
  some ink/ground pair sits under 3:1, and text there would otherwise
  be illegible. But an hour and a half of visible hard outline is a
  long time, and whether it reads as engraving or as clutter is a
  judgement only hardware can settle. Watch the plate's marker labels
  and the focused card through a full sunrise and a full maghrib.
  If it reads as clutter, the lever is the multiplier in
  `SkyPhase.inkOutlineStrength`: the smallest value still satisfying
  `theOutlineIsFullyDrawnWhereverContrastCollapses` is **1.31**, which
  would roughly halve the span to ~44 min/day (25 + 19). 3.0 ships
  because it keeps a 2.3× margin over a palette Task 2 rewrites — the
  span is the cost of that margin, not an accident.

  Judge the cost against the right duration: fully drawn is 85 min, but
  the modifier is **live for ~2.7 h/day** (13.35% of the cycle; ring at
  half strength or more for 8.55%, untouched 86.65%). Over that whole
  window the text is rendered twice and eight `radius: 0` shadow layers
  are drawn per label, and no performance test exercises it — so the
  question is not only whether the outline looks right at its peak but
  whether the plate stays smooth across the ramp. Watch for dropped
  frames on the marker labels through a full sunrise, not just at it.

- **Translucent text under the keyline.** The modifier draws its content
  twice, once per ring, so `.opacity(…)` on a `foregroundStyle` would
  composite with itself *and* take a near-black wash from the upper
  copy's ring. Two sites carried translucent ink and have been changed
  to fade the finished mark instead — the plate's `SUNRISE ·` inscription
  (was `inkSecondary.opacity(0.9)`) and the focused card's Arabic prayer
  name (was `ink.opacity(0.72)`, the worse of the two: ~28% of its area
  would have taken the wash). Both now apply `.opacity(…)` outside
  `.inkKeyline(…)`. Source-only reasoning; confirm on device through a
  sunrise and a maghrib that the Arabic name still reads as a quieter
  companion to the English rather than a differently-weighted one.
- **Numeric transitions on the focused card.** `.contentTransition(.numericText())`
  on the `.upcoming` time and inscription now sits outside
  `.inkKeyline(…)`. Correcting an earlier claim here: this is
  **cosmetic, not a fix** — `contentTransition` is an environment value,
  so it reaches both of the keyline's copies wherever it is applied.
  Still worth a look during a crossing: confirm the minute rollover
  animates as one numeral, with no doubled or ghosted digit, since the
  glyph genuinely is drawn twice while the outline is up.
- **Baseline alignment — RESOLVED, and the original worry was
  overstated.** Keylining the two `Text`s of `prayerNameRow` individually
  (needed for the opacity fix) meant `HStack(alignment: .firstTextBaseline)`
  was aligning two composed subtrees mid-crossing, and I flagged that as
  a possible abrupt jump. **Measurement says it was not happening.**
  `CrossingLegibilityRenderTests.keylinedTextKeepsItsBaselineInAnAlignedRow`
  now renders a baseline-aligned row at an active crossing phase and
  compares the small glyph's rows against the same row with bare text —
  and the original `ZStack` composition passes it just as the current
  `.background` one does. The test is not toothless: a deliberate 4 pt
  inset inside the modifier moves the glyph from rows 158…175 to
  152…175 and fails it.

  So: no device check remains here, and the `.background` composition is
  kept as defence-in-depth — layout-neutral by documented semantics
  rather than by luck — not as the repair of an observed defect. Note
  also that the `alignmentGuide` remedy an earlier version of this entry
  suggested would not have worked anyway: a call-site guide just
  re-queries the container's own baseline.

- **Numeric transitions on the focused card.** `.contentTransition(.numericText())`
  on the `.upcoming` time and inscription now sits outside
  `.inkKeyline(…)`. Correcting an earlier claim here: this is
  **cosmetic, not a fix** — `contentTransition` is an environment value,
  so it reaches both of the keyline's copies wherever it is applied.
  Still worth a look during a crossing: confirm the minute rollover
  animates as one numeral, with no doubled or ghosted digit, since the
  glyph genuinely is drawn twice while the outline is up.
- **Baseline alignment — FIXED in source, no longer a device check.**
  Keylining the two `Text`s of `prayerNameRow` individually (needed for
  the opacity fix) briefly meant `HStack(alignment: .firstTextBaseline)`
  was aligning two `ZStack`s mid-crossing. That would have been a *step*,
  not a drift — the modifier is gated on `strength`, so any mismatch
  appears and vanishes abruptly, three times per crossing on the hero
  row. `InkKeyline` now composes its two copies with `.background`
  instead of a `ZStack`, so the near copy stays the layout-defining view
  and its alignment guides propagate normally.

  Be precise about what is and isn't established. The fix rests on
  `.background` being layout-neutral by documented semantics — firmer
  ground than the `ZStack` question ever was. It does **not** rest on the
  render checks I first cited: comparing the plateau render to bare text
  is a tautology, because at `strength <= 0.001` the modifier returns its
  content and the rewritten branch never executes at all; and "the
  crossing render still differs" would pass identically under a `ZStack`,
  since it only shows that rings are drawn. Neither involves a
  baseline-aligned container, which is the property at issue. What the
  suite does pin is the far ring's geometry and contrast — the full
  render sweep (60 phases × 2 inks × 3 heights), the band-equivalence
  test and the canary all pass unchanged.

  So one device line remains, and it is the only one: **glance at the
  prayer-name row through a crossing** and confirm the English and Arabic
  sit on one baseline as the outline engages and disengages. Nothing in
  the suite pins that. And do not "simplify" the modifier back to a
  `ZStack` — note that the `alignmentGuide` remedy this entry used to
  suggest would NOT have worked, since a call-site guide just re-queries
  the `ZStack`'s own baseline.

### Found, not fixed — corrective I

- **Tripwire for Task 2: `inkHaloLightValue` is the only lever on a very
  thin margin.** `CrossingLegibilityRenderTests.theAchievableBoundHoldsAtEveryPhase`
  holds the outline's achievable separation to a floor of **4.40**.
  Two anchors sit above it, and the distance differs a lot:
  - **4.4785** — what the sweep measures over the ink path the palette
    really takes. The floor is 1.8% under this.
  - **4.4058** — `√((far + 0.05) / (near + 0.05))`, the worst the ring
    pair could give for *any* ink luminance. The floor is only **0.13%**
    under this, and the gap between the two anchors is luck: today's ink
    path does not quite reach the crossover value. A palette that moves
    the ink path can close it without touching either ring.

  **`inkHaloLightValue` is the only palette lever here.** The near ring
  is not a palette quantity at all — `InkKeyline.nearCeiling` pins it at
  L = 0.0010, structurally out of the palette's reach — so it cannot
  drift and cannot be blamed. Measured: darkening `inkHaloLightValue` by
  **1.85%** lands the bound exactly on 4.40; 3% puts it at 4.3509.
  Task 2 rewrites the unit table and inserts a sixth state, so if that
  token moves this is the test that notices. **A failure there is a real
  signal about the far pole, not noise to tune away** — the correct
  response is to look at what happened to `inkHaloLightValue`, not to
  lower the floor.

- **Text on panels drops below 3:1, with no mechanism to catch it.**
  Sweeping 4,000 phases, `ink` or `inkSecondary` against `panelFill`
  falls under 3:1 at **23 phases** of the cycle. The crossing keyline is
  not the remedy and cannot become one: it is applied only to text
  standing on the sky or the ground, which is why the 26
  `.shadow(color: tokens.inkHalo, radius: 2)` sites in `ihsan/Repair/**`
  were deliberately left alone. `panelFill` was removed from
  `theOutlineIsFullyDrawnWhereverContrastCollapses`'s trigger set for
  that reason — a failure naming a panel pair would point at a constant
  that cannot help it.
  **This is a gap, not a non-issue.** At present nothing in the app
  guarantees panel text stays legible at those phases. It wants its own
  contract with its own remedy — most likely a panel-side treatment or a
  `panelFill`/ink pairing that never crosses — and that is a decision
  beyond corrective I. Worth noting the dip is currently masked: at
  every one of those 23 phases a ground pair is *also* under 3:1, so no
  phase is panel-only today. A palette change could separate them.
