# IhsanFiqhConfig

IhsanFiqhConfig is the data layer for fiqh-sensitive content in Ihsan: reflection prompts, status framing copy, and threshold definitions. The principle is simple — **fiqh content lives as data, not code** — so a scholar's correction can ship to all users in hours rather than weeks.

## Architecture

- An actor (`FiqhConfigService`) is the single source of truth for the active config.
- A bundled `default-fiqh-config.json` ships with the app and is always available offline.
- On launch the service loads the most recent successful config (cache → bundle) and kicks off a background refresh from a CDN URL.
- A successful refresh writes to cache. The refreshed content is **applied on the next launch**, never mid-session — so users never see prompts or copy change while the app is open.
- The package has no dependencies on any other Ihsan package and no SwiftUI imports.

## Loading priority

1. **Cache** — most recent successful CDN fetch, written to `Library/Caches/fiqh-config-cached.json`.
2. **Bundle** — `default-fiqh-config.json` shipped with the app.
3. **Throw** — only if the bundle is missing entirely (which would indicate a build/packaging problem).

If a remote fetch returns an unparsable payload or a config with `schemaVersion > FiqhConfig.supportedSchemaVersion`, the fetch is rejected and the previous cached or bundled config continues to serve. This means new app versions can introduce new schema fields without breaking older clients still in the wild.

## Schema versioning

Two version fields:

- `schemaVersion: Int` — bump when the JSON shape changes in a way that older app code cannot decode. Requires an app update.
- `contentVersion: String` (e.g. `"2026-05-09.001"`) — bump every time the prompts, framing, or thresholds change. Pure content updates do not require an app update.

`FiqhConfig.supportedSchemaVersion` is the highest schema this build understands. Any fetched config with a higher schema is rejected without affecting cached/bundled state.

## Hosting the remote config

Point `FiqhConfigService.remoteConfigURL` at a publicly readable JSON file matching the `FiqhConfig` shape. Recommendations:

- v1 (acceptable): a JSON file in a public GitHub repo, served via `raw.githubusercontent.com`. Free, version-controlled, but rate-limited.
- v1.0.1+ (recommended): front the GitHub raw URL with Cloudflare or a similar CDN for caching, lower latency, and rate-limit protection.
- Long-term: a stable URL on your own domain (e.g. `https://fiqh.ihsan.app/config/v1/fiqh-config.json`).

To roll out a content update: edit the hosted JSON, bump `contentVersion`, push. All users pick it up on their next app launch.

## Citation rule

**Every prompt in the bundled or remote config MUST cite a verifiable classical source.** No "general hadith", no "Islamic tradition", no inspirational phrasing without provenance. If a citation cannot be verified, the prompt is omitted — better to ship eight well-cited prompts than twenty with vague attributions.

Acceptable source forms:

- Qur'an: surah and ayah (e.g. `"Qur'an 2:153"`).
- Hadith: collection and number, with the companion narrator named (e.g. `"Bukhari 6464, Muslim 782 — narrated by 'A'isha RA"`).
- Classical work: author, title, book/chapter (e.g. `"al-Ghazali, Ihya 'Ulum al-Din, Book 38 (Kitab al-Muraqaba wa al-Muhasaba)"`).
- Athar from a Companion: name them and identify the recording work where possible (e.g. `"Athar from 'Umar ibn al-Khattab (RA); cited by al-Ghazali in Ihya 'Ulum al-Din, Book 38"`).

When in doubt, omit the prompt and route it to a scholar for verification before adding it back.

## Workflow for scholar feedback

1. Scholar reviews the active set of prompts and framing copy.
2. They mark up a shared document (Google Doc, plain text — whatever fits the relationship).
3. Maintainer translates the changes into the JSON schema, validates locally by running this package's tests against a copy with the new payload, and pushes to the CDN URL.
4. All users receive the update on their next app launch.

For prompts pending scholar review, set `isActive: false` rather than deleting them — soft-deprecation preserves history and makes it easy to reinstate once corrections land.

## Usage

```swift
import IhsanFiqhConfig

// In SwiftUI:
.task {
    do {
        let prompt = try await FiqhConfigService.shared.prompt(for: .now, timeOfDay: .night)
        // prompt.promptEn, prompt.citationEn
    } catch {
        // Bundled fallback should make this unreachable in practice.
    }
}

// Get the full config (e.g. for framing copy in Settings):
let config = try await FiqhConfigService.shared.currentConfig()
let lateLabel = config.framing.lateLabel

// Manual refresh from a Settings screen "Check for updates" action.
// The new content applies on the next app launch.
_ = try await FiqhConfigService.shared.forceRefresh()
```

## Constraints

- All public API is `Sendable`.
- The service is an actor — single source of truth, thread-safe.
- Network fetches use an 8-second timeout. Failures are silent — bundled or cached config continues to serve.
- Force-refresh writes to cache but does **not** mutate the in-memory active config. The new version applies on next launch.
- No SwiftUI, UIKit, or AppKit imports.
- No third-party dependencies.

## Out of scope (v1)

- Localization beyond English. `promptAr` and `citationAr` are present as optional fields for future use.
- A user-facing Settings UI for triggering refresh — refresh runs in the background automatically.
- Versioned rollback. To recover from a bad config, push a fixed config with a higher `contentVersion`.
