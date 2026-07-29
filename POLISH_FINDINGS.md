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
