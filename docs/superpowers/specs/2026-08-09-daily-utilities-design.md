# Daily utilities — My Masjid iqamah + the wake anchors

Date: 2026-08-09
Status: approved

Two small features, both extending machinery that already exists. My
Masjid puts the user's own congregation times beside the calculated
ones. The wake anchors generalise the single last-third alarm into the
four moments a person actually asks to be woken for.

Neither feature adds a server, a fetch, or a third-party dependency.

---

## A. My Masjid

### A1. The model

`MyMasjid` — a singleton `@Model` in `IhsanCore`, addressed by a fixed
UUID exactly as `UserSettings` is, with `fetchOrCreate` alongside a
`fetchExisting` that returns `nil` rather than conjuring a record (the
display surfaces must be able to ask "is one set?" without creating
one as a side effect).

```swift
@Model public final class MyMasjid {
    public static let singletonID: UUID           // fixed
    public var id: UUID

    @Attribute(.allowsCloudEncryption) public var name: String?
    @Attribute(.allowsCloudEncryption) public var streetLabel: String?
    @Attribute(.allowsCloudEncryption) public var latitude: Double?
    @Attribute(.allowsCloudEncryption) public var longitude: Double?

    public var iqamahConfigJSON: String           // [IqamahEntry]
    public var jumuahKhutbahMinutesFromMidnight: Int?
    public var reminderLeadMinutes: Int           // shared, default 10

    public var createdAt: Date
    public var modifiedAt: Date
}
```

### A2. Wall-clock, not instants

A fixed iqamah is stored as **minutes from local midnight**
(`0..<1440`), never as a `Date`.

A board on a masjid wall that reads 1:30 PM means 1:30 PM — it is a
civil wall-clock time, not an instant. Storing an instant would drift
the moment the user travels or the region's DST shifts, and would need
a stored timezone to interpret. Minutes-from-midnight needs nothing
and cannot drift.

```swift
public struct IqamahEntry: Codable, Sendable, Equatable {
    public enum Mode: String, Codable, Sendable { case none, fixed, offset }
    public var prayer: Prayer
    public var mode: Mode
    public var fixedMinutesFromMidnight: Int?   // 0..<1440
    public var offsetMinutes: Int?              // minutes after that day's adhan
    public var reminderEnabled: Bool
}
```

Encoded to `iqamahConfigJSON` with `.sortedKeys`, decoded leniently
(unknown/missing keys fall back per-field), following the established
`rawatibConfigJSON` / `prayerNotificationsConfigJSON` pattern. Tests
compare **decoded values, never encoded strings** — `JSONEncoder`
output ordering is not stable across processes.

### A3. Resolution — one pure function

```swift
IqamahSchedule.resolve(entry:adhan:timeZone:) -> Date?
```

- `.none` → `nil`.
- `.offset` → `adhan + offsetMinutes · 60`.
- `.fixed` → **the first occurrence of that wall-clock time at or
  after the adhan, within 24 hours.**

The fixed rule is the definition, not a correction heuristic: an
iqamah follows its adhan. Resolving on the adhan's *civil day* instead
is wrong wherever the iqamah crosses midnight — at 60°N in June, an
Isha adhan at 22:30 with a board time of 00:15 would resolve
twenty-two hours **before** its adhan. "First occurrence at or after"
is deterministic, needs no special-casing for high latitudes or DST,
and is directly property-testable.

Resolution never silently repairs a genuinely wrong entry. Every
editor row prints the time it resolves to today, so a mistake is
visible where it was made.

### A4. Migration — schema V9

V8 is frozen into a nested snapshot; V9 adds `MyMasjid` and nothing
else. A new entity migrates lightweight.

A seeded V8 store + exit test joins `SchemaMigrationTests`, in that
file's established shape: seeds run inside
`#expect(processExitsWith: .success)` because the frozen-schema
snapshots share an entity-name cache across a process.

### A5. Setup — two doors

**Door 1 — Set → My Masjid.** A new `SettingsRoute.myMasjid` editor:
name; five prayer rows, each a mode segment (`—` / time / offset)
with its value control, a per-row reminder toggle, and the resolved
time for today printed beneath; a Jumu'ah khutbah row (fixed time
only); one shared "remind me N minutes before" stepper; Remove.

**Door 2 — the Nearby Masjids sheet.** `MasjidResultRow` gains a
third line: a quiet gilded inscription button, `SET AS MY MASJID`,
beneath the detail line. Once set, that row instead shows a
non-interactive `MY MASJID` inscription.

A full-width third line rather than a second glyph in the trailing
column: two tap targets crammed into one row collapse under
`.accessibility5` and give VoiceOver two rects contending for the same
space. Tapping it prefills name, street, and coordinate from the
transient search result and opens the editor. **Nothing is fetched** —
the person types the times they know.

Choosing a different venue while one is already set **replaces** it,
and clears the iqamah times with it: those times described the
previous masjid, and silently carrying them onto a new one would
present another congregation's schedule as this one's. The editor
opens on the new venue with empty rows, and the replacement is stated
before it happens.

**Clearing** deletes the record, cancels its reminders, and removes
every surface it fed.

### A6. The coordinate carve-out

Privacy invariant #1 currently reads that coordinates are never
written to SwiftData, and today no model stores one — `TravelInterval`
keeps labels only. `MyMasjid` is the first, so the invariant is
amended in the same commit, scoped precisely:

> **Device-derived** coordinates are transient — the user's own
> position, from CoreLocation, exists in memory for prayer-time,
> qibla, and search work and is never persisted. A venue the user
> deliberately names and enters times for is their own datum: stored
> encrypted, private-database, and never sent anywhere.

The distinction is between a trace of where someone has been and a
place they chose to write down.

---

## B. Display

### B1. The inscription

`IQAMAH · 1:30 PM` — in the state line's register, always the
**resolved** time, never the formula. Present only for prayers
carrying a value.

- **Focused card** — a second inscription beneath the state line.
- **Log sheet** — the same inscription beneath the window line.
- **Friday** — the Jumu'ah khutbah time replaces Dhuhr's iqamah
  inscription where one is provided. Friday is determined in the
  place's timezone, not the device's.
- **The plate is untouched.** It stays celestial.

### B2. The one layout risk

`FocusedPrayerCard.cardHeight` is a fixed 140pt, and
`TodayCompositionMetrics` lays the celestial scene against it. A
second line has room in `.active` and `.logged`; `.upcoming` already
carries a title-size numeral plus an inscription.

If `.accessibility5` capture shows crowding, the fallback is
`cardHeight(hasIqamah:)` threaded through the composition metrics —
**not** truncation, and not a silently scaled-down line.

### B3. Iqamah reminders

A standard notification (never an alarm), `reminderLeadMinutes` before
the resolved iqamah, default off per prayer.

Scheduled inside `NotificationScheduler.rebuildSchedule()` alongside
the adhkar reminders, with its own identifier prefix, so it rebuilds
on the same rolling-window cadence and is swept by the same
cancellation path.

Suppressed when:
- an excused pause is open, or
- that prayer already carries a log for that day.

---

## C. Wake anchors

### C1. The anchors

```swift
public enum WakeAnchor: String, CaseIterable, Codable, Sendable {
    case lastThird   // the night's last third begins
    case fajrStart   // suhoor's end
    case sunrise     // Fajr's window closing
    case maghrib     // iftar
}

public struct WakeAnchorConfig: Codable, Sendable, Equatable {
    public var anchor: WakeAnchor
    public var isEnabled: Bool
    public var offsetMinutes: Int   // minutes BEFORE the event
}
```

Stored as `UserSettings.wakeAnchorsConfigJSON`. Every anchor is
strictly opt-in and defaults off.

### C2. The planner

`NightWakePlanner` generalises to `WakeAnchorPlanner`, operating over
a `WakeEvents` value carrying one day's four instants
(`lastThirdStart`, `fajrStart`, `sunrise`, `maghrib`), all sourced
from `IhsanPrayerTimes`. The fire time is exactly
`event − offsetMinutes · 60` — that identity is the property test.

One coordinator and **one stable AlarmKit UUID per anchor**. A
recomputation therefore cancels and reschedules exactly one alarm,
which is what forecloses the double-fire class: there is no path by
which a shifted window leaves a stale alarm beside its replacement.

Everything continues to route through the existing AlarmKit path with
its time-sensitive notification fallback.

### C3. Sound

All four anchors take their tone from a single constant —
`WakeSound.assetName` → `AdhanAsset.nightWake` → `AdhanAsset.chime`.
`AdhanAsset.nightWake` is a computed alias, and it is the swap point:
when the muezzin-era recordings land, replacing the chime replaces
every anchor with zero code changes here.

`theGentleWakeAndTheNotificationShareOneTone` widens to assert that
every `WakeAnchor` resolves to that one constant, so the swap point
cannot silently become plural.

### C4. Migration — schema V10

V9 frozen; V10 adds `wakeAnchorsConfigJSON` and
`suhoorAnchorOfferedAt` to `UserSettings`.

A **custom** stage, following the V6→V7 pattern: `didMigrate` writes
`lastThird = (nightWakeEnabled, nightWakeOffsetMinutes)` and the other
three explicitly off. Explicit writes, because a lightweight stage
would let the new model's defaults leak into an upgrader's record and
quietly reset a wake they had configured.

`nightWakeEnabled` and `nightWakeOffsetMinutes` remain as documented
vestigial columns — deleting a stored property costs a migration over
every row to remove two scalars nothing reads.

### C5. Set — "Wakes & alarms"

Its own group, one row per anchor, each with a plain one-line
description:

| Anchor | Copy |
| --- | --- |
| `.fajrStart` | Before Fajr begins — while the meal is still open |
| `.sunrise` | Before Fajr ends — wake in time to pray before sunrise |
| `.maghrib` | Iftar — when the fast opens at Maghrib |
| `.lastThird` | *(existing copy, unchanged)* |

`.lastThird` **keeps its `sunnahLayerEnabled && sunnahNightEnabled`
gate** and its existing copy and behaviour; its row appears in the new
group only when the night layer is on. The other three are peers with
no such dependency. Migration preserves the user's current
configuration exactly — nobody's alarm behaviour changes on upgrade.

### C6. Ramadan

During Ramadan (via the existing Hijri layer), `.fajrStart` is
surfaced as a one-time quiet suggestion line in the fasting register,
gated by a new `UserSettings.suhoorAnchorOfferedAt: Date?`.

Offered, never auto-enabled.

---

## Testing

- `IqamahSchedule` property tests: offset identity; fixed resolving to
  the first occurrence at or after the adhan; the post-midnight
  high-latitude case explicitly; DST-transition days.
- Iqamah reminder scheduling, including pause suppression and
  already-logged suppression.
- `WakeAnchorPlanner` property tests: `fire == event − offset` for
  every anchor, across a DST boundary and a location change; pause
  suppression per anchor; no double-fire under recomputation.
- Migration tests: V8→V9 seeded exit test; V9→V10 asserting an
  upgrader's last-third configuration survives byte-for-byte and the
  other three anchors land off.
- Banned-language sweep extended to every new user-facing source.
- Contrast AA; `.accessibility5` on functional text; VoiceOver labels;
  Reduce Motion and Reduce Transparency defined.
- Swift 6 strict concurrency clean.

## Out of scope

The watch app, the widgets, and `WidgetSnapshot` carry no iqamah. The
surfaces this spec touches are Today, the log sheet, Set, and the
Nearby Masjids sheet.

## Project-doc repairs (same commit as A6)

`CLAUDE.md` currently describes the schema as `IhsanSchemaV1` while
the store is at V8 and heading to V10. It is corrected to current
reality, and gains the standing rule that the schema section is bumped
with every migration — a project doc that lies about the schema will
eventually talk a fresh session into writing a colliding one.
