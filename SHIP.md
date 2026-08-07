# SHIP

Ihsan 1.0.0 (1). The code is done. What follows is the part that needs
a person.

## Human-only, before submission

### 1. The muezzin's recording

Everything about sound is built and tested; only the audio is
synthetic. Three placeholder files ship, generated from sine partials
by `docs/audio/generate-placeholders.py` — no sample, no recording, no
license question.

To replace them, drop the real files into `ihsan/Resources/Adhans/` and
change the matching line in `AdhanAsset`
(`Packages/IhsanNotifications/Sources/IhsanNotifications/AdhanSoundCatalog.swift`).
No call site anywhere refers to a file name.

| Constant | Needs | Hard limit |
| --- | --- | --- |
| `chime` | a real tone, or keep the synthesised one | `.caf`, **≤ 30 s** |
| `chimeDawn` | Fajr's rising variant | `.caf`, **≤ 30 s** |
| `takbirat` | **the muezzin's opening lines — absent today** | `.caf`, **≤ 30 s** |
| `fullAdhan` | the complete call, played in-app | any length |

The 30-second ceiling is not advisory: iOS silently ignores a longer
tone and the notification arrives with no sound at all.
`AdhanAssetTests` measures every bundled file and fails on a long one,
which is the only way this gets caught.

`takbirat` deliberately names a file that does not exist. Set → Adhan
reads "Recording not in this build yet — plays the chime" on that row
until it does. Nothing needs deleting when it lands.

**Before shipping any real recording**, record its source and license in
`docs/audio/LICENSES.txt`. The license must cover redistribution inside
an app, not just personal use. App Review spot-checks audio provenance.

### 2. The scholar's eyes

The app never rules, and the places it comes closest to a ruling want a
second reading:

- **Calculation methods.** Each row now shows the angles it computes
  with, read off the parameters the solar math is handed. Check the
  provenance strings in `CalculationMethodDisplay.swift` name the right
  bodies, and that the Advanced section's framing ("Set your own angles
  when a local timetable uses figures no listed method matches") reads
  as description rather than encouragement.
- **The madhab copy on the onboarding calculation screen** — two
  sentences about when Asr begins.
- **The rawatib defaults** in `UserSettings.defaultRawatibConfigJSON`,
  which the app calls "a commonly kept set, not a ruling".
- **The duha window's default edges** (20 min after sunrise, 15 min
  before Dhuhr).
- **The reflection prompts and their citations** in
  `Packages/IhsanFiqhConfig`.
- **The Path insight framing and its citations** in
  `Packages/IhsanFiqhConfig`, especially the distinction the app draws
  between its in-window “Delayed” label and a later qadāʾ record.
- **The morning/evening adhkār windows and reminder timing.** The
  reminder is silent and device-local; it follows the same reviewed
  window policy as the in-app suggestion.
- **Qadā framing throughout Repair**, which is the most theologically
  loaded surface in the app.

`BannedLanguageSweepTests` guards the vocabulary — no streaks, no
scores, no celebration or blame — but it cannot judge whether a fiqh
statement is correct.

### 3. Maintainer decisions left open

- **The all-five shortcut** in yesterday's sheet ("All five · On Time").
  Built and tested; it appears only when nothing at all was logged and
  withdraws once the day has answers. Cut it by deleting the
  `onCommitAllOnTime` argument at its one call site in `TodayScreen`;
  the per-row flow stands unchanged.
- **The sunnah invitation's copy**, submitted for approval:

  > **IF YOU WANT IT** — There is more to the day than the five — the
  > rawatib, duha, the night. It waits in Set, and stays off until you
  > turn it on.

  One string in `SunnahInviteCard.swift`. Deleting that file and
  `SunnahInviteTests.swift` removes the feature entirely.

### 4. Device verification

`POLISH_FINDINGS.md` lists what a simulator cannot settle: the settle
haptic's physical character across all seven commit sites, StandBy
under real Night Mode, the scroll-edge material over the floating tab
bar, 60 fps on the oldest supported device, and VoiceOver's
pronunciation of "Qadā", "jamāʿah", "takbīrāt", and the Arabic prayer
names.

### 5. App Store Connect

1. **Version.** `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 1`.
2. **Archive.** `xcodebuild archive -scheme ihsan -destination
   'generic/platform=iOS'` succeeds with zero warnings across every
   target. Re-run with real signing.
3. **App Privacy.** Answer from `docs/app-privacy.md`. The short
   version: **no data collected**, no tracking, no third-party SDKs.
   That answer is true, and the manifest says the same.
4. **Screenshots.** Six frames in `docs/app-store/`, captions in
   `docs/app-store-captions.md`. Regenerate at 6.9" against an
   iPhone 17 Pro Max destination before uploading.
5. **Review notes.** The "Notes for App Review" section of
   `docs/app-privacy.md` covers religious-content provenance, the
   on-device model's scope, AlarmKit, and why there is no background
   location entitlement.
6. **Capabilities**, provisioned against the App ID: App Group
   `group.com.sameerstudios.ihsan`, iCloud container
   `iCloud.com.sameerstudios.ihsan`, Push Notifications, background
   `fetch` + `remote-notification`, and the BGTaskScheduler identifier
   `com.sameerstudios.ihsan.refresh-notifications`. Sign in with Apple
   is intentionally not used.

## What the machine already checked

| | |
| --- | --- |
| Package tests | 418 across eight packages |
| App tests | 129 in 22 suites |
| UI tests | onboarding (timed), calculation depth, yesterday's account, sound delivery (timed), VoiceOver walk, gallery capture |
| Archive | clean, zero warnings, every target |
| Migration chain | V1 → V6, every hop, each from a store seeded with that version's own frozen types |
| Time fixtures | no surface enters a prayer early, across 50 random locations and dates; countdown target strictly future at every boundary; window closed at the exact instant of sunrise |
| Contrast | every canonical SkyPhase including dawn, for the page, the worship surfaces, and everything this pass added |
| Dynamic Type | no cap, no shrink below 0.6, no bridged UIFont, outside two named data-matrix exemptions |
| Haptics | every worship commit settles; success notifications confined to an allowlist; no file builds its own generator |
| Language | banned-language sweep over every user-facing source |

## The one thing to re-check after any change to prayer times

`PrayerStateResolver` is the single state machine every surface reads —
plate, card, widgets, watch, notifications, Live Activity. It has no
tolerance and no lead by design. The only lead time in the app is
`LiveActivityWindow.preAdhanLead`, thirty minutes, and it belongs to
the Live Activity alone. It was previously two private copies in two
modules, both drifted to an hour; a test now pins the boundary from
either side.

If a surface ever appears to enter a prayer early again, start at
`PrayerMomentNeverEarlyTests` and `theLiveActivityAppearsExactlyThirtyMinutesAheadAndNotSooner`.
