# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Ihsan — a privacy-first Islamic prayer tracking, qibla, masjid finder, and reflection app for iOS / watchOS / iOS widgets. Local-first SwiftData with CloudKit private-database sync. No analytics, no servers, no third-party SDKs except Adhan-Swift.

## Platform requirements

- **iOS 26, watchOS 26, visionOS 26, macOS 26 minimum.** All `Package.swift` files pin `.v26`; the app `Info.plist` declares `MinimumOSVersion = 26.0`. Liquid Glass, FoundationModels (on-device AI), and other iOS 26 APIs are used directly — do not add availability guards back to older OSes.
- **Swift 6.2 toolchain, Swift 6 language mode** (`swiftLanguageMode(.v6)` is set on every package target). Strict concurrency applies; new code must be `Sendable`-correct.
- No Cocoapods / Carthage. Adhan-Swift is the only external SPM dependency, pulled from GitHub by `IhsanPrayerTimes`.

## Build, run, test

The Xcode project lives at `ihsan.xcodeproj`. Four shared schemes: `ihsan`, `ihsanWidgets`, `ihsanWatch`, `ihsanWatchWidgets`.

App + extension targets — open in Xcode, or:

```bash
# Build the iOS app for a simulator
xcodebuild -project ihsan.xcodeproj -scheme ihsan \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Run the app-level unit tests (XCTest in ihsanTests/)
xcodebuild -project ihsan.xcodeproj -scheme ihsan \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

Swift Package tests run via SwiftPM directly — much faster than going through xcodebuild:

```bash
swift test --package-path Packages/IhsanCore
swift test --package-path Packages/IhsanDesignSystem
swift test --package-path Packages/IhsanFiqhConfig
# ... one per package; all eight packages have a *Tests target.

# Single test (Swift Testing — used by FiqhConfig, DesignSystem, Insights):
swift test --package-path Packages/IhsanDesignSystem --filter ColorContrastTests

# Single test (XCTest — used by some of the older packages):
swift test --package-path Packages/IhsanCore --filter testFetchOrCreateUserSettings
```

There is no Fastlane, Makefile, lint config, or formatter committed. `.swiftpm/`, `build/`, `DerivedData/`, and `xcuserdata/` are gitignored.

## Architecture

### Target graph

The Xcode project contains six native targets:

- **`ihsan`** — main iOS app
- **`ihsanWidgets`** — iOS widget extension + Live Activities (`PrayerActivityWidget`)
- **`ihsanWatch`** — watchOS app
- **`ihsanWatchWidgets`** — watchOS complications
- **`ihsanTests`** — app-level unit tests (`MoonPhaseTests`, `PrayerActivitySchedulerTests`)
- **`ihsanUITests`** — UI tests

All five app/extension targets link the eight local packages under `Packages/`.

### Package dependency graph

Each `Packages/Ihsan*` is a separate SwiftPM library. Dependencies fan out from `IhsanCore`:

```
IhsanCore  ──┬── IhsanDesignSystem
             ├── IhsanFiqhConfig
             ├── IhsanInsights        (iOS/macOS/visionOS only — uses FoundationModels)
             ├── IhsanPrayerTimes  ── IhsanLocation ── IhsanNotifications
             └── IhsanIntents     ─── IhsanPrayerTimes
```

**`IhsanCore`** is the SwiftData layer. It defines the seven `@Model` types (`PrayerLog`, `Reflection`, `DayRecord`, `PauseInterval`, `TravelInterval`, `PeriodSummary`, `UserSettings`), the versioned schema (`IhsanSchemaV1`), the migration plan (`IhsanMigrationPlan`), and the `IhsanModelContainerFactory`. **No SwiftUI/UIKit/AppKit imports** — keep it that way.

**`IhsanPrayerTimes`** is pure calculation around Adhan-Swift. All returned `Date`s are absolute UTC instants — format at the UI layer using the user's timezone. `nextPrayer(...)` handles post-Isha rollover by returning tomorrow's Fajr.

**`IhsanLocation`** is the CoreLocation wrapper. **`CoreLocationCoordinator.swift` is the only file in the project allowed to import CoreLocation directly** — every consumer depends on the `LocationProviding` protocol. See the privacy invariants below.

**`IhsanIntents`** is the App Intents layer. **All prayer-logging paths** (Today screen, iOS widgets, watch app, Siri, Shortcuts, Spotlight) go through `LogPrayerIntent`, `LogPrayerWithStatusIntent`, `ToggleJamaahIntent`, `MarkAsQadaIntent`. Keep that single-funnel pattern when adding new surfaces, so dedup (via `PrayerLog.dedupKey`) and idempotency hold.

**`IhsanInsights`** generates on-device summaries via FoundationModels. `InsightAvailability` checks `SystemLanguageModel.default.availability` under `canImport(FoundationModels)` and silently renders nothing when Apple Intelligence is unavailable — no greyed state, no upgrade prompt.

**`IhsanFiqhConfig`** ships a bundled JSON config of fiqh thresholds and reflection prompts. Tries a network fetch, but `BundledConfigParsingTests` guarantees the bundled copy is always parseable as a fallback.

**`IhsanDesignSystem`** is tokens (`IhsanColor`, `IhsanFont`, `IhsanSpacing`, `IhsanMaterial`, `IhsanIridescence`, `TimeOfDay`) + reusable components + the `Celestial/` subsystem (qibla compass, sun/moon ornaments) used by `CelestialReferenceView`. Mathematical color-contrast tests live in `ColorContrastTests`.

### Persistence

- Schema is **`IhsanSchemaV1`**; any new `@Model` type must be added to `IhsanSchemaV1.models` and a migration stage appended to `IhsanMigrationPlan` if the schema changes.
- Store is shared via the App Group **`group.com.sameerstudios.ihsan`** so widgets, watch, and main app see the same SQLite file (`Ihsan.sqlite`).
- CloudKit private database **`iCloud.com.sameerstudios.ihsan`** syncs eligible records. Several string fields are marked `@Attribute(.allowsCloudEncryption)` (notes, transcripts, prompts, city names) — preserve that when editing the models.
- Reflection audio (`.m4a` files in the App Group container) is **not** CloudKit-synced by design. Raw audio stays on the device that recorded it; only the transcript + metadata travel.
- On launch, `IhsanApp.init` calls `IhsanModelContainerFactory.makeContainer()` and falls back to `inMemory: true` if the App Group container isn't available (early dev / entitlement misconfig). Don't remove the fallback.

### App-side composition

The iOS app lives under `ihsan/` and is organised by feature:

- `App/` — `IhsanApp` (`@main`), `RootGate` (gates onboarding vs. tabs based on `UserSettings.hasCompletedOnboarding`), `RootTabView`, `CustomTabBar`.
- `Today/`, `Trajectory/`, `Reflection/`, `MasjidFinder/`, `Qibla/`, `Onboarding/`, `Settings/`, `LiveActivity/`, `Ramadan/` — each feature uses an MVVM split: `ViewModel/` (`*State.swift` + `*ViewModel.swift`), `Components/`, `Helpers/`, optionally `Services/` and `Models/`.
- The watch app under `ihsanWatch/` mirrors the same feature/MVVM layout.

### Live Activities

`PrayerActivityScheduler` (in `ihsan/LiveActivity/`) is registered onto `NotificationScheduler.shared` from `IhsanApp.init`. `RootGate` watches `prayerLogs` and ends matching activities when a prayer is logged. The lock-screen / Dynamic Island UI lives in `ihsanWidgets/LiveActivities/PrayerActivityWidget.swift`.

## Privacy invariants — do not violate

These are explicit project-wide rules baked into entitlements, code, and Info.plist usage strings. Treat them as guardrails when modifying anything in `IhsanLocation`, `IhsanCore`, or features that touch location/audio:

1. **Coordinates are transient.** `LocatedPlace.coordinates` exists only in memory for prayer-time / qibla / masjid-search work. Never write coordinates to SwiftData, UserDefaults, files, or any external storage. Only `cityName` and `countryCode` are safe to persist (and `UserSettings.lastResolvedCityName` is `.allowsCloudEncryption`'d).
2. **Reverse-geocoding cache stays in memory only**, keyed by rounded coordinates (~100m), 24-hour TTL, 100-entry cap.
3. **Voice memo audio never leaves the device** by default. Optional iCloud sync of audio is gated behind `UserSettings.autoSyncAudioMemos`; reinstalled apps show feed cards in `voiceMissing` shape rather than re-fetching audio.
4. **No analytics, no servers, no third-party SDKs.** The only network calls are CoreLocation reverse-geocoding (Apple) and the optional `IhsanFiqhConfig` fetch (with bundled fallback).

## App identifiers / capabilities

The `ihsan` target needs the following provisioned in Apple Developer Portal under the App ID:

- App Group: `group.com.sameerstudios.ihsan`
- iCloud container: `iCloud.com.sameerstudios.ihsan` (CloudKit)
- Push Notifications
- Background mode `fetch` + `remote-notification` (the watch / iOS widgets also need the appropriate flags in their own entitlements)
- `BGTaskSchedulerPermittedIdentifiers`: `com.sameerstudios.ihsan.refresh-notifications`

Sign in with Apple is intentionally disabled for v1.

## POLISH_FINDINGS.md

`POLISH_FINDINGS.md` at the repo root is the maintainer's device-verification checklist (animation timing, Dynamic Type, VoiceOver pronunciation, Reduce Motion, on-device color contrast). Items there are out-of-scope for source-only changes; when work touches one of those areas, append a finding rather than asserting it's been verified.
