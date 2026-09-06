# SHIP

Ihsan 1.0.0 (1). The code is done. What follows is the part that needs
a person.

## Human-only, before submission

### 1. The muezzin's recording

Everything about sound is built and tested; the two chimes that ship
are synthesised from sine partials by
`docs/audio/generate-placeholders.py` — no sample, no recording, no
license question. The muezzin's two files are not in the build, and
**the build is complete without them**: nothing in the interface
points at a recording that is absent.

- Set → Adhan offers Chime, Chime rising (Fajr), and Silent. The
  Takbīrāt row does not exist until its file does.
- "The full call" section, and the notification's "Play the adhan"
  action, do not exist until the full recording does.
- The About → "Audio credits" row naming the muezzin is hidden until
  one of his files ships.

To add them, drop the files into `ihsan/Resources/Adhans/` under the
names `AdhanAsset` expects
(`Packages/IhsanNotifications/Sources/IhsanNotifications/AdhanSoundCatalog.swift`),
or rename the constant. No call site anywhere refers to a file name,
and every surface above appears on its own once the file is present.

| Constant | File it expects | Hard limit |
| --- | --- | --- |
| `chime` | `ihsan-chime.caf` (ships, synthesised) | `.caf`, **≤ 30 s** |
| `chimeDawn` | `ihsan-chime-dawn.caf` (ships, synthesised) | `.caf`, **≤ 30 s** |
| `takbirat` | `ihsan-takbirat.caf` — **absent** | `.caf`, **≤ 30 s** |
| `fullAdhan` | `ihsan-adhan-full.m4a` — **absent** | any length |

The 30-second ceiling is not advisory: iOS silently ignores a longer
tone and the notification arrives with no sound at all.
`AdhanAssetTests` measures every bundled file and fails on a long one,
which is the only way this gets caught.

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

0. **Privacy policy URL.** Host `docs/privacy-policy.md` (as-is or as
   HTML) anywhere stable and paste the URL into the App Privacy Policy
   field. The same text is inside the app at Set → About → Privacy
   policy, so the in-app requirement is already met; only the metadata
   field needs the link. The old `sameerstudios.github.io/ihsan/privacy`
   address does not resolve — do not reuse it.
1. **Version.** `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 1`.
2. **Archive.** `xcodebuild archive -scheme ihsan -destination
   'generic/platform=iOS'` succeeds. Re-run with real signing, and
   confirm Organizer shows an **iOS App** archive, not a "Generic Xcode
   Archive": the embedded watch app used to build with
   `SKIP_INSTALL = NO`, which puts a second product at the archive's
   top level and makes it undistributable. It is `YES` now, and an
   unsigned archive verified `Products/Applications/` holds only
   `ihsan.app` with the watch app inside it.
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
   `iCloud.com.sameerstudios.ihsan`, Push Notifications, WeatherKit,
   background `fetch` + `remote-notification`, and the BGTaskScheduler
   identifier `com.sameerstudios.ihsan.refresh-notifications`. Sign in
   with Apple is intentionally not used.
7. **Platforms.** The app targets iPhone only
   (`TARGETED_DEVICE_FAMILY = 1`, portrait). On iPad, Mac, and Vision
   Pro it runs in iPhone-compatibility mode; if any of those should not
   be listed, untick them under Pricing and Availability → Apple
   Silicon / visionOS.
8. **Export compliance.** `ITSAppUsesNonExemptEncryption` is `false` in
   both app Info.plists (Apple HTTPS only), so the upload will not ask.
9. **App icon.** `ihsan/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
   and the watch equivalent are rendered from the plate's own motif by
   `docs/app-icon/generate-icon.swift` (`swiftc -O` it and run with an
   output directory). iOS derives the dark and tinted variants. Check
   it on a device home screen before submission; it has only been
   seen at 120 px in a viewer.

## What the machine already checked

| | |
| --- | --- |
| Package tests | Launch sweep: IhsanNotifications 45, IhsanLocation 18, IhsanFiqhConfig 27, IhsanIntents 44 passed; other package totals are not recertified by this sweep |
| App tests | 312 tests in 51 suites passed on the final handoff tree, 6 Sep 2026 |
| UI tests | Granted-location comparison: all three RetroactiveLog tests passed on baseline and changed trees; both PrayerLogCommit tests failed with identical assertions on both. Onboarding and sound-delivery failures also reproduced on baseline. Device acceptance remains open. |
| Archive | Unsigned archive layout verified: one top-level ihsan.app with embedded watch app. Existing actor-isolation warnings remain; signing and upload require the developer account. |
| Migration chain | V1 → V11 migration chain; seeded migration tests cover frozen V1 through V10 stores (not rerun in this sweep) |
| Time fixtures | no surface enters a prayer early, across 50 random locations and dates; countdown target strictly future at every boundary; window closed at the exact instant of sunrise |
| Contrast | every canonical SkyPhase including dawn, for the page, the worship surfaces, and everything this pass added |
| Dynamic Type | no cap, no shrink below 0.6, no bridged UIFont, outside two named data-matrix exemptions |
| Haptics | every worship commit settles; success notifications confined to an allowlist; no file builds its own generator |
| Language | banned-language sweep over every user-facing source |
| Watch build | ihsanWatch simulator build passed after the permission and complication fixes, 6 Sep 2026 |
| Launch sweep (6 Sep 2026) | privacy manifest in every bundle incl. file-timestamp reason; when-in-use location only; no placeholder copy; every in-app link resolves; icons present |

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
