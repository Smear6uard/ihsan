# App Privacy

The answers to fill into App Store Connect's App Privacy section, and
the notes for App Review. Every line is drawn from what the code does,
not from what the app would like to say.

## Data collection

**Does this app collect data? No.**

Not "collects but does not link". Not "collects for app functionality".
There is no server. `NSPrivacyCollectedDataTypes` in
`ihsan/PrivacyInfo.xcprivacy` is an empty array, and it is empty
truthfully:

- No analytics SDK, no crash reporter, no attribution framework.
- No third-party SDK of any kind. The only external dependency is
  Adhan-Swift, which is pure solar arithmetic and opens no connection.
- Everything a person records lives in a SwiftData store inside the App
  Group container, mirrored to **their own** iCloud private database.
  Apple holds it; the developer cannot read it and has no account
  through which to try.

**Tracking: no.** `NSPrivacyTracking` is false and
`NSPrivacyTrackingDomains` is empty. Nothing is passed to a data broker
and no identifier is shared with anyone.

## The four network calls the app makes

Three are to Apple and one is to GitHub. None of them reaches a server
the developer runs, because there isn't one.

1. **Reverse geocoding**, to Apple, via MapKit's
   `MKReverseGeocodingRequest` — coordinates in, a city name out.
   Results are cached in memory only, keyed by coordinates rounded to
   roughly 100 m, with a 24-hour lifetime and a 100-entry cap.
2. **The nearby-masjid search**, to Apple Maps via `MKLocalSearch` —
   the current coordinate in, a list of places out, only while the
   Nearby sheet is open. Nothing from it is cached beyond the sheet;
   the one thing that can persist is a masjid the person adopts (see
   below).
3. **The weather reading**, to Apple Weather via WeatherKit — coordinates
   in, the current conditions out. It happens only while something is
   actually asking for weather: the Living sky toggle in Set → Display
   (off by default), or the weather duas in the remembrance layer. With
   both off, `WeatherInterest` reports no interested consumer and the
   request is never made.

   The coordinates are used to scope the one request and discarded with
   it — `WeatherKitSkyProvider` retains, persists, and logs nothing. What
   comes back is reduced immediately to a condition kind and three coarse
   bands (wind, cloud, precipitation), and only that reduction is cached.
   `SkyConditionsCacheStore` holds no coordinate, no place name, and
   nothing else that could locate the reading. Readings expire after
   three hours rather than painting stale weather.
4. **The fiqh configuration fetch** in `IhsanFiqhConfig` — a static
   JSON file of thresholds and reflection prompts, read from the
   developer's public repository on `raw.githubusercontent.com`. This is
   the one request that is not to Apple. It sends nothing but the
   request. A bundled copy ships with the app and a test guarantees it
   parses, so the app is fully functional with the network off.

## Permissions, and exactly what each is for

| Permission | Used for | Not used for |
| --- | --- | --- |
| **Location** (when in use) | Prayer times, the qibla bearing, and the nearby-masjid search. | Anything else. Your coordinates exist in memory for the length of a calculation and are never written to SwiftData, UserDefaults, or a file. Only the city name and country code persist, and the city name is `@Attribute(.allowsCloudEncryption)`. Three requests to Apple carry coordinates and keep nothing: reverse geocoding, the nearby-masjid search, and the weather reading when you have asked for weather — see the four network calls above. The one place a coordinate is stored is a masjid you deliberately set as your own — see below. |
| **Microphone** | Recording a voice reflection. | Nothing is uploaded. The `.m4a` stays in the App Group container and is deliberately excluded from CloudKit sync; only the transcript and metadata travel. `UserSettings.autoSyncAudioMemos` exists in the model for a later version but no control exposes it in 1.0, so audio never syncs. |
| **Speech recognition** | Transcribing a voice reflection, on device. | No audio leaves the phone during transcription. |
| **Motion** (no prompt — `CMMotionManager` attitude needs no usage description, and none is declared) | One thing: `DeviceTiltMonitor` reads device pitch so the qibla dial can say "lay the phone flat" when it is held near-vertical and magnetic heading stops being reliable. It publishes a single boolean. | Not parallax, not analytics, not activity or step data. |
| **Notifications** | One notification per prayer, at its time. Per-prayer sound and Focus behaviour are the person's choice, and every prayer can be silenced on its own. | Nothing is sent from a server; every notification is scheduled locally. |
| **Alarms (AlarmKit)** | The four optional wake anchors — the last third of the night, Fajr's start, sunrise, and Maghrib — every one off by default. Requested only when someone turns one on. | — |

## The one coordinate the app stores

Your own position is never written down. A masjid you choose is.

When you set a masjid as yours — from the nearby sheet, or by typing its
name — the app keeps its name, its street label, and, if it came from a
search, its coordinate. That is a place you picked and entered prayer
times for, not a record of where you have been, and it is the only
coordinate in the store. It is encrypted at rest, lives in your private
iCloud database, and is written in exactly one place in the code: the
moment you adopt a masjid.

The times themselves are yours too. Nothing fetches iqamah times from any
service — there is no masjid-times server behind this feature, and no
request leaves the phone when you enter or read them.

Removing your masjid removes all of it.

## Background modes

`fetch` and `remote-notification`, plus the BGTaskScheduler identifier
`com.sameerstudios.ihsan.refresh-notifications`.

`fetch` exists to rebuild the rolling notification window: prayer times
move every day, and iOS caps pending local notifications at 64. The
background refresh recomputes the next window from the same schedule
the plate draws. `remote-notification` is CloudKit's: it lets SwiftData's
mirror wake when a record changes on another of the person's devices.
Neither performs any networking of the app's own.

**Background location: not used.** The app requests *when in use* only
— there is no `NSLocationAlwaysAndWhenInUseUsageDescription` in the
Info.plist and no code path calls `requestAlwaysAuthorization`. The
"Update as I travel" switch in Set → Location runs
`startMonitoringSignificantLocationChanges` on that same when-in-use
grant, so a traveller's times follow them while the app is open; the
app holds no background location mode on iPhone or on the watch and
does not track anyone between sessions.

## Accessed API reasons

Every bundle carries its own `PrivacyInfo.xcprivacy` — the app, the
widget extension, the watch app, and the watch complications — because
each reads the shared App Group defaults through `IhsanCore`:

- `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` (all four
  bundles): access limited to the app group they share.
- `NSPrivacyAccessedAPICategoryFileTimestamp`, reason `C617.1` (app
  only): `ReflectionAudioPaths.cleanupOrphans` reads the modification
  date of `.m4a` files inside the App Group container to avoid deleting
  a memo that is still being written. It never reads a timestamp
  outside the container.

No disk-space or system-boot-time APIs are used.

## Notes for App Review

**Religious content and where it comes from.** Every religious statement
in the app is either a curated static fact or a classical citation
shipped in the bundle:

- Prayer times are computed from published astronomical parameters
  (Adhan-Swift). Every calculation method's angles are shown on its own
  row so a person can verify against their masjid's timetable.
- The Hijri calendar's significant days are a static curated list.
- Reflection prompts carry their citations (al-Ghazali, *Ihyā' 'Ulūm
  al-Dīn*, and similar) and ship in `IhsanFiqhConfig`.
- Where schools differ — madhab for Asr, rawatib counts, the duha
  window's edges — the app states that they differ and makes the value
  editable. It never rules.

**The on-device model generates no religious content.** `IhsanInsights`
uses Apple's FoundationModels to summarise *the person's own logged
data* ("you prayed Fajr in congregation more often this month"). It is
given no scripture, issues no rulings, and answers no questions. A
content filter rejects prohibited terms, and when Apple Intelligence is
unavailable the feature renders nothing at all — no greyed state, no
upgrade prompt.

**AlarmKit** is used only for the optional wake anchors — the last third
of the night, Fajr's start, sunrise, and Maghrib. Every one is off by
default, the permission is requested at the moment someone enables one,
and when alarms are unavailable or declined the app falls back to a
time-sensitive notification and says so plainly in Settings.

**Audio provenance.** The two bundled chimes are synthesised from sine
partials — see `docs/audio/generate-placeholders.py`, which is the
complete source of every audio file in the build. No recording,
sampled or otherwise, ships today, and the interface offers none: the
takbīrāt option, the in-app player, and the muezzin's credit line each
appear only when their file is in the bundle. When a recording is added
its license must be recorded in `docs/audio/LICENSES.txt` before
submission.

**Platforms.** iPhone only, portrait. The build runs in compatibility
mode on iPad, Mac, and Vision Pro if those are left enabled in App
Store Connect; nothing in the app is iPad-specific.

**The privacy policy** is inside the app at Set → About → Privacy
policy (`PrivacyPolicyScreen`), and the same text is in
`docs/privacy-policy.md` for the App Store Connect field.
