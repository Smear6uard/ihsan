# Daily Utilities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship My Masjid (hand-entered iqamah times shown beside the calculated adhan) and the wake anchors (the single last-third alarm generalised to four opt-in anchors).

**Architecture:** Both features extend machinery already present. Iqamah resolution is one pure function in `IhsanCore` over a `MyMasjid` singleton `@Model`; display surfaces read a `Sendable` snapshot of it, never the model. The wake anchors generalise `NightWakePlanner` into `WakeAnchorPlanner` over a `WakeEvents` value, with one coordinator and one stable AlarmKit UUID per anchor, riding the existing AlarmKit-with-notification-fallback path.

**Tech Stack:** Swift 6.2 (language mode v6), SwiftUI, SwiftData + CloudKit private DB, AlarmKit, UserNotifications, Adhan-Swift (via `IhsanPrayerTimes`), Swift Testing + XCTest.

**Spec:** `docs/superpowers/specs/2026-08-09-daily-utilities-design.md` — read it before Task 1. Every task is written against it.

**Worktree:** `.claude/worktrees/daily-utilities`, branch `daily-utilities`. All paths below are relative to that worktree root.

## Global Constraints

- **Platform floor:** iOS 26 / watchOS 26 / visionOS 26 / macOS 26. Packages pin `.v26`. No availability guards back to older OSes.
- **Language mode:** Swift 6 strict concurrency on every target. New types crossing an isolation boundary must be `Sendable`. `@Model` types are **not** `Sendable` — pass value snapshots.
- **`IhsanCore` imports no SwiftUI / UIKit / AppKit.** Keep it that way.
- **No network.** No masjid-times fetch, no third-party SDK, no analytics. The only permitted network calls remain Apple reverse-geocoding and the optional `IhsanFiqhConfig` fetch.
- **Privacy invariant #1, as amended in Task 5:** device-derived coordinates stay transient. `MyMasjid.latitude/longitude` are the single carve-out, encrypted, and only ever written from a venue the user explicitly chose.
- **Banned language** (from `ihsanTests/BannedLanguageSweepTests.swift`): no `streak`, `badge`, `congratulation`, `congrats`, `well done`, `great job`, `keep it up`, `on fire`, `don't break`, `broken fast`, `you missed`, `you failed`, `failure`, `fell short`, `behind on`, `catch up`. Every new user-facing source file is added to that suite's `sweptFiles`.
- **Copy rules:** describe the window, never the user's act. Sentence case in prose, `UPPERCASE` only in the `IhsanFont.inscription` register. Active voice.
- **Accessibility:** contrast AA; functional text survives `.accessibility5`; VoiceOver labels/values/hints on every control; Reduce Motion and Reduce Transparency have defined behaviour.
- **All `Date`s from `IhsanPrayerTimes` are absolute UTC instants.** Format at the UI layer in the place's timezone via `PlateTimeFormat`.
- **One `NowProvider`.** Never call `Date()` in view or model logic; take `now` from the caller.
- **Commit per phase** with `utilities: <phase>` subject lines, push after each phase's verification report. No force pushes.

### Test commands

```bash
# Package tests (fast — prefer these)
swift test --package-path Packages/IhsanCore
swift test --package-path Packages/IhsanNotifications
swift test --package-path Packages/IhsanPrayerTimes

# Single suite
swift test --package-path Packages/IhsanCore --filter IqamahScheduleTests

# App-level tests (slow, needs a simulator)
xcodebuild -project ihsan.xcodeproj -scheme ihsan \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

### Known environment gotchas

- Frozen-schema snapshots share a process-wide entity-name cache. **Every migration seed test must run inside `#expect(processExitsWith: .success)`** — follow the existing shape in `Packages/IhsanCore/Tests/IhsanCoreTests/SchemaMigrationTests.swift`.
- Never assert on `JSONEncoder` output as a string; ordering is not stable across processes. Compare decoded values.
- Xcode's synchronized groups cache an in-memory file list. After adding files from the CLI, a green `swift build` proves nothing about the Xcode targets — quit and reopen Xcode before trusting an app-target build.

## File Structure

**Create**
| Path | Responsibility |
| --- | --- |
| `Packages/IhsanCore/Sources/IhsanCore/Masjid/IqamahEntry.swift` | The per-prayer iqamah value type + `Mode`. |
| `Packages/IhsanCore/Sources/IhsanCore/Masjid/IqamahSchedule.swift` | Pure resolution: entry + adhan + timezone → instant. |
| `Packages/IhsanCore/Sources/IhsanCore/Models/MyMasjid.swift` | The singleton `@Model`. |
| `Packages/IhsanCore/Sources/IhsanCore/Masjid/MyMasjidSnapshot.swift` | `Sendable` value copy for view/actor boundaries. |
| `Packages/IhsanCore/Sources/IhsanCore/Schema/IhsanSchemaV9.swift` | Frozen V9 (adds `MyMasjid`). |
| `Packages/IhsanCore/Sources/IhsanCore/Schema/IhsanSchemaV10.swift` | Frozen V10 (adds wake-anchor columns). |
| `Packages/IhsanCore/Sources/IhsanCore/Wake/WakeAnchor.swift` | The four anchors + per-anchor config. |
| `Packages/IhsanNotifications/Sources/IhsanNotifications/WakeAnchors.swift` | `WakeEvents`, `WakeAnchorPlanner`, `WakeAnchorCoordinator`. |
| `ihsan/Masjid/MyMasjidEditorScreen.swift` | The editor. |
| `ihsan/Masjid/Components/IqamahRow.swift` | One prayer's mode + value + resolved-today line. |
| `ihsan/Today/Helpers/IqamahInscription.swift` | Card/sheet inscription text incl. Friday substitution. |
| `ihsan/Night/WakeAnchorService.swift` | Replaces `NightWakeService`; four anchors, one sound constant. |

**Modify**
| Path | Change |
| --- | --- |
| `Packages/IhsanCore/Sources/IhsanCore/Models/UserSettings.swift` | `wakeAnchorsConfigJSON`, `suhoorAnchorOfferedAt`; accessors; vestigial notes on the two `nightWake*` columns. |
| `Packages/IhsanCore/Sources/IhsanCore/Schema/IhsanMigrationPlan.swift` | Two stages appended. |
| `Packages/IhsanNotifications/Sources/IhsanNotifications/NotificationScheduler.swift` | Iqamah reminders in `rebuildSchedule()`. |
| `Packages/IhsanNotifications/Sources/IhsanNotifications/AdhanSoundCatalog.swift` | Doc note: `nightWake` is the four-anchor swap point. |
| `Packages/IhsanDesignSystem/.../Components/SettingsGlyph.swift` | `case masjid`. |
| `ihsan/MasjidFinder/Components/MasjidResultRow.swift` | The `SET AS MY MASJID` line. |
| `ihsan/MasjidFinder/MasjidFinderScreen.swift` | Threads the set-as callback + replacement confirmation. |
| `ihsan/Today/Components/FocusedPrayerCard.swift` | Iqamah inscription. |
| `ihsan/Today/Components/PrayerLogSheet.swift` | Iqamah inscription under the window line. |
| `ihsan/Today/ViewModel/TodayState.swift`, `TodayViewModel.swift` | Carry `MyMasjidSnapshot?`; call the anchor service. |
| `ihsan/Settings/SettingsScreen.swift` | `SettingsRoute.myMasjid`; "Wakes & alarms" group; last-third row moves. |
| `ihsan/Ramadan/…` | One-time suhoor anchor offer. |
| `CLAUDE.md` | Invariant #1 carve-out; schema section corrected to reality. |
| `ihsanTests/BannedLanguageSweepTests.swift` | New sources appended to `sweptFiles`. |

---

# Phase 1 — My Masjid: data + setup

### Task 1: Iqamah value type and pure resolution

The heart of the feature. Resolution is pure arithmetic over absolute instants and a timezone; everything else in Phase 1 depends on these signatures.

**Files:**
- Create: `Packages/IhsanCore/Sources/IhsanCore/Masjid/IqamahEntry.swift`
- Create: `Packages/IhsanCore/Sources/IhsanCore/Masjid/IqamahSchedule.swift`
- Test: `Packages/IhsanCore/Tests/IhsanCoreTests/IqamahScheduleTests.swift`

**Interfaces:**
- Consumes: `Prayer` (existing, `IhsanCore`).
- Produces: `IqamahEntry`, `IqamahEntry.Mode`, `IqamahSchedule.resolve(entry:adhan:timeZone:) -> Date?`, `IqamahSchedule.resolveFixed(minutesFromMidnight:onOrAfter:timeZone:) -> Date?`, `IqamahSchedule.decode(_:) -> [IqamahEntry]`, `IqamahSchedule.encode(_:) -> String`.

- [ ] **Step 1: Write the failing tests**

Create `Packages/IhsanCore/Tests/IhsanCoreTests/IqamahScheduleTests.swift`:

```swift
import Foundation
import Testing
@testable import IhsanCore

@Suite("Iqamah resolution")
struct IqamahScheduleTests {

    private static func utc(_ tz: String) -> TimeZone { TimeZone(identifier: tz)! }

    private static func instant(
        _ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, in tz: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        return calendar.date(
            from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi)
        )!
    }

    @Test("An offset entry resolves to the adhan plus its minutes")
    func offsetAddsToAdhan() {
        let tz = Self.utc("America/Chicago")
        let adhan = Self.instant(2026, 8, 9, 5, 22, in: tz)
        let entry = IqamahEntry(prayer: .fajr, mode: .offset, offsetMinutes: 20)

        let resolved = IqamahSchedule.resolve(entry: entry, adhan: adhan, timeZone: tz)

        #expect(resolved == adhan.addingTimeInterval(20 * 60))
    }

    @Test("A none entry resolves to nothing")
    func noneResolvesToNil() {
        let tz = Self.utc("America/Chicago")
        let adhan = Self.instant(2026, 8, 9, 5, 22, in: tz)
        let entry = IqamahEntry(prayer: .fajr, mode: .none)

        #expect(IqamahSchedule.resolve(entry: entry, adhan: adhan, timeZone: tz) == nil)
    }

    @Test("A fixed time later the same day resolves on that day")
    func fixedLaterSameDay() {
        let tz = Self.utc("America/Chicago")
        let adhan = Self.instant(2026, 8, 9, 12, 51, in: tz)   // Dhuhr 12:51 PM
        let entry = IqamahEntry(
            prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 13 * 60 + 30
        )

        let resolved = IqamahSchedule.resolve(entry: entry, adhan: adhan, timeZone: tz)

        #expect(resolved == Self.instant(2026, 8, 9, 13, 30, in: tz))
    }

    /// The flag that killed "resolve on the adhan's civil day": at high
    /// latitude in summer an Isha adhan at 22:30 with a board time of
    /// 00:15 belongs to the NEXT civil day. Resolving on the adhan's own
    /// day would place the iqamah twenty-two hours before its adhan.
    @Test("A fixed time past midnight resolves forward, never backward")
    func fixedPastMidnightRollsForward() {
        let tz = Self.utc("Europe/Oslo")
        let adhan = Self.instant(2026, 6, 15, 22, 30, in: tz)
        let entry = IqamahEntry(
            prayer: .isha, mode: .fixed, fixedMinutesFromMidnight: 15
        )

        let resolved = IqamahSchedule.resolve(entry: entry, adhan: adhan, timeZone: tz)

        #expect(resolved == Self.instant(2026, 6, 16, 0, 15, in: tz))
        #expect(resolved! > adhan)
    }

    @Test("A fixed time equal to the adhan resolves to the adhan itself")
    func fixedEqualToAdhanIsTheAdhan() {
        let tz = Self.utc("America/Chicago")
        let adhan = Self.instant(2026, 8, 9, 13, 30, in: tz)
        let entry = IqamahEntry(
            prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 13 * 60 + 30
        )

        #expect(IqamahSchedule.resolve(entry: entry, adhan: adhan, timeZone: tz) == adhan)
    }

    @Test("Every fixed resolution lands within 24 hours after its adhan")
    func fixedAlwaysWithinTwentyFourHours() {
        let tz = Self.utc("America/Chicago")
        let adhan = Self.instant(2026, 8, 9, 17, 40, in: tz)

        for minute in stride(from: 0, to: 1440, by: 7) {
            let entry = IqamahEntry(
                prayer: .asr, mode: .fixed, fixedMinutesFromMidnight: minute
            )
            let resolved = IqamahSchedule.resolve(
                entry: entry, adhan: adhan, timeZone: tz
            )
            let delta = resolved!.timeIntervalSince(adhan)
            #expect(delta >= 0)
            #expect(delta < 24 * 3600)
        }
    }

    /// Spring-forward skips 2:00–3:00 local. A board time inside the gap
    /// has no instant that day; resolution must still return the first
    /// real occurrence rather than nil or a time before the adhan.
    @Test("A fixed time inside a spring-forward gap still resolves forward")
    func fixedInsideDSTGapResolvesForward() {
        let tz = Self.utc("America/Chicago")
        // 2026-03-08: clocks jump 02:00 -> 03:00 local.
        let adhan = Self.instant(2026, 3, 7, 20, 10, in: tz)
        let entry = IqamahEntry(
            prayer: .isha, mode: .fixed, fixedMinutesFromMidnight: 2 * 60 + 30
        )

        let resolved = IqamahSchedule.resolve(entry: entry, adhan: adhan, timeZone: tz)

        #expect(resolved != nil)
        #expect(resolved! > adhan)
        #expect(resolved!.timeIntervalSince(adhan) < 24 * 3600)
    }

    @Test("Entries survive an encode and decode round trip")
    func roundTripsThroughJSON() {
        let entries = [
            IqamahEntry(prayer: .fajr, mode: .offset, offsetMinutes: 20, reminderEnabled: true),
            IqamahEntry(prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 810),
        ]

        let decoded = IqamahSchedule.decode(IqamahSchedule.encode(entries))

        // Compare decoded VALUES — never the encoded string; JSONEncoder
        // key ordering is not stable across processes.
        #expect(decoded == entries)
    }

    @Test("A payload missing newer keys still decodes")
    func decodesLeniently() {
        let json = #"[{"prayer":"fajr","mode":"offset","offsetMinutes":15}]"#

        let decoded = IqamahSchedule.decode(json)

        #expect(decoded.count == 1)
        #expect(decoded[0].reminderEnabled == false)
    }

    @Test("Unreadable JSON decodes to no entries rather than throwing")
    func decodesGarbageToEmpty() {
        #expect(IqamahSchedule.decode("not json").isEmpty)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/IhsanCore --filter IqamahScheduleTests`
Expected: FAIL — `cannot find 'IqamahEntry' in scope`.

- [ ] **Step 3: Write `IqamahEntry.swift`**

```swift
import Foundation

/// One prayer's iqamah, as the person entered it.
///
/// A fixed time is stored as **minutes from local midnight**, never as
/// an instant. A board on a masjid wall reading 1:30 PM means 1:30 PM —
/// civil wall-clock time. An instant would need a stored timezone to
/// interpret and would drift the moment the user travels or the region
/// shifts for DST.
public struct IqamahEntry: Codable, Sendable, Equatable {

    public enum Mode: String, Codable, Sendable {
        /// No iqamah recorded for this prayer; it renders nowhere.
        case none
        /// A wall-clock time from the masjid's board.
        case fixed
        /// A duration after this day's calculated adhan.
        case offset
    }

    public var prayer: Prayer
    public var mode: Mode
    /// 0..<1440. Meaningful only in `.fixed`.
    public var fixedMinutesFromMidnight: Int?
    /// Minutes AFTER the adhan. Meaningful only in `.offset`.
    public var offsetMinutes: Int?
    /// Whether this prayer's iqamah reminder is armed. The lead time
    /// itself is shared across the masjid, on `MyMasjid`.
    public var reminderEnabled: Bool

    public init(
        prayer: Prayer,
        mode: Mode = .none,
        fixedMinutesFromMidnight: Int? = nil,
        offsetMinutes: Int? = nil,
        reminderEnabled: Bool = false
    ) {
        self.prayer = prayer
        self.mode = mode
        self.fixedMinutesFromMidnight = fixedMinutesFromMidnight
        self.offsetMinutes = offsetMinutes
        self.reminderEnabled = reminderEnabled
    }

    /// Decoded leniently so a payload written by an earlier build still
    /// reads, rather than discarding times someone typed in by hand.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prayer = try container.decode(Prayer.self, forKey: .prayer)
        mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? .none
        fixedMinutesFromMidnight = try container.decodeIfPresent(
            Int.self, forKey: .fixedMinutesFromMidnight
        )
        offsetMinutes = try container.decodeIfPresent(Int.self, forKey: .offsetMinutes)
        reminderEnabled = try container.decodeIfPresent(
            Bool.self, forKey: .reminderEnabled
        ) ?? false
    }

    /// True when this entry would render a time somewhere.
    public var isSet: Bool {
        switch mode {
        case .none: false
        case .fixed: fixedMinutesFromMidnight != nil
        case .offset: offsetMinutes != nil
        }
    }
}
```

- [ ] **Step 4: Write `IqamahSchedule.swift`**

```swift
import Foundation

/// Pure resolution of an entered iqamah against a computed adhan.
///
/// No clock is read here and no state is held: callers hand in the
/// adhan instant and the place's timezone, and get back an absolute
/// instant to format.
public enum IqamahSchedule {

    /// The iqamah instant for one entry, or nil when none is recorded.
    public static func resolve(
        entry: IqamahEntry,
        adhan: Date,
        timeZone: TimeZone
    ) -> Date? {
        switch entry.mode {
        case .none:
            return nil
        case .offset:
            guard let minutes = entry.offsetMinutes else { return nil }
            return adhan.addingTimeInterval(TimeInterval(minutes * 60))
        case .fixed:
            guard let minutes = entry.fixedMinutesFromMidnight else { return nil }
            return resolveFixed(
                minutesFromMidnight: minutes, onOrAfter: adhan, timeZone: timeZone
            )
        }
    }

    /// The first occurrence of a wall-clock time at or after `adhan`,
    /// within 24 hours.
    ///
    /// This is the definition, not a correction heuristic: an iqamah
    /// follows its adhan. Resolving on the adhan's civil day instead
    /// breaks wherever the iqamah crosses midnight — at 60°N in June an
    /// Isha adhan at 22:30 with a board time of 00:15 would land
    /// twenty-two hours BEFORE its own adhan.
    ///
    /// Searching forward day by day (rather than computing a candidate
    /// and nudging it) also disposes of the DST cases for free: a wall
    /// time inside a spring-forward gap simply has no match that day,
    /// and the next day's occurrence is returned.
    public static func resolveFixed(
        minutesFromMidnight: Int,
        onOrAfter adhan: Date,
        timeZone: TimeZone
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let hour = minutesFromMidnight / 60
        let minute = minutesFromMidnight % 60

        // The adhan's own civil day, then the two that follow. Three is
        // enough for any real timezone: a wall time missing on one day
        // (a spring-forward gap) exists on the next.
        for dayOffset in 0...2 {
            guard
                let day = calendar.date(byAdding: .day, value: dayOffset, to: adhan),
                let candidate = calendar.date(
                    bySettingHour: hour, minute: minute, second: 0, of: day,
                    matchingPolicy: .nextTime,
                    repeatedTimePolicy: .first,
                    direction: .forward
                )
            else { continue }

            if candidate >= adhan, candidate.timeIntervalSince(adhan) < 24 * 3600 {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Storage

    /// Sorted keys so the stored default is byte-stable across
    /// processes. Tests still compare decoded values, never this string.
    public static func encode(_ entries: [IqamahEntry]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(entries),
              let json = String(data: data, encoding: .utf8)
        else { return "[]" }
        return json
    }

    public static func decode(_ json: String) -> [IqamahEntry] {
        guard let data = json.data(using: .utf8),
              let entries = try? JSONDecoder().decode([IqamahEntry].self, from: data)
        else { return [] }
        return entries
    }

    /// One `.none` entry per prayer, in the day's order.
    public static var empty: [IqamahEntry] {
        Prayer.allCases.map { IqamahEntry(prayer: $0) }
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --package-path Packages/IhsanCore --filter IqamahScheduleTests`
Expected: PASS, 9 tests.

- [ ] **Step 6: Commit**

```bash
git add Packages/IhsanCore/Sources/IhsanCore/Masjid/ \
        Packages/IhsanCore/Tests/IhsanCoreTests/IqamahScheduleTests.swift
git commit -m "utilities: resolve an entered iqamah against its adhan"
```

---

### Task 2: The `MyMasjid` model, its snapshot, and schema V9

**Files:**
- Create: `Packages/IhsanCore/Sources/IhsanCore/Models/MyMasjid.swift`
- Create: `Packages/IhsanCore/Sources/IhsanCore/Masjid/MyMasjidSnapshot.swift`
- Create: `Packages/IhsanCore/Sources/IhsanCore/Schema/IhsanSchemaV9.swift`
- Modify: `Packages/IhsanCore/Sources/IhsanCore/Schema/IhsanMigrationPlan.swift`
- Modify: `Packages/IhsanCore/Sources/IhsanCore/ModelContainer/` — wherever `IhsanSchemaV8` is named as current, point it at V9
- Test: `Packages/IhsanCore/Tests/IhsanCoreTests/SchemaMigrationTests.swift` (append)
- Test: `Packages/IhsanCore/Tests/IhsanCoreTests/MyMasjidTests.swift`

**Interfaces:**
- Consumes: `IqamahEntry`, `IqamahSchedule` (Task 1).
- Produces: `MyMasjid` (with `fetchOrCreate(in:)`, `fetchExisting(in:)`, `entry(for:)`, `setEntry(_:)`, `snapshot`), `MyMasjidSnapshot`, `IhsanSchemaV9`.

- [ ] **Step 1: Freeze V8**

`IhsanSchemaV8.swift` currently lists the live top-level models. Freeze it exactly as V7 was frozen: copy the current model definitions into nested snapshot classes inside `IhsanSchemaV8`, so a store already claiming V8 can still be described. Follow the shape of `IhsanSchemaV7.swift` line for line — nested `@Model final class` per entity, all properties defaulted, no behaviour.

- [ ] **Step 2: Write the failing model test**

Create `Packages/IhsanCore/Tests/IhsanCoreTests/MyMasjidTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import IhsanCore

@Suite("My Masjid")
@MainActor
struct MyMasjidTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(IhsanSchemaV9.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test("Nothing exists until one is set")
    func fetchExistingReturnsNilBeforeSetup() throws {
        let context = try makeContext()
        #expect(MyMasjid.fetchExisting(in: context) == nil)
    }

    @Test("fetchExisting does not conjure a record")
    func fetchExistingHasNoSideEffect() throws {
        let context = try makeContext()
        _ = MyMasjid.fetchExisting(in: context)
        #expect(try context.fetch(FetchDescriptor<MyMasjid>()).isEmpty)
    }

    @Test("Only one masjid is ever created")
    func fetchOrCreateIsSingleton() throws {
        let context = try makeContext()
        let first = try MyMasjid.fetchOrCreate(in: context)
        first.name = "Masjid al-Noor"
        let second = try MyMasjid.fetchOrCreate(in: context)

        #expect(first.id == second.id)
        #expect(second.name == "Masjid al-Noor")
    }

    @Test("An entry set on one prayer leaves the others alone")
    func setEntryIsPerPrayer() throws {
        let context = try makeContext()
        let masjid = try MyMasjid.fetchOrCreate(in: context)

        masjid.setEntry(
            IqamahEntry(prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 810)
        )

        #expect(masjid.entry(for: .dhuhr).mode == .fixed)
        #expect(masjid.entry(for: .asr).mode == .none)
    }

    @Test("A masjid with no times set reports itself empty")
    func reportsWhetherAnythingIsSet() throws {
        let context = try makeContext()
        let masjid = try MyMasjid.fetchOrCreate(in: context)
        #expect(masjid.hasAnyIqamah == false)

        masjid.setEntry(IqamahEntry(prayer: .fajr, mode: .offset, offsetMinutes: 20))
        #expect(masjid.hasAnyIqamah)
    }

    @Test("Replacing the venue clears the times that described the old one")
    func replacingVenueClearsTimes() throws {
        let context = try makeContext()
        let masjid = try MyMasjid.fetchOrCreate(in: context)
        masjid.name = "Masjid al-Noor"
        masjid.setEntry(IqamahEntry(prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 810))

        masjid.replaceVenue(
            name: "Masjid al-Rahma", streetLabel: "12 Mill Rd",
            latitude: 41.88, longitude: -87.63
        )

        #expect(masjid.name == "Masjid al-Rahma")
        #expect(masjid.hasAnyIqamah == false)
        #expect(masjid.entry(for: .dhuhr).mode == .none)
    }

    @Test("The snapshot carries the values a view needs and nothing live")
    func snapshotIsAValueCopy() throws {
        let context = try makeContext()
        let masjid = try MyMasjid.fetchOrCreate(in: context)
        masjid.name = "Masjid al-Noor"
        masjid.setEntry(IqamahEntry(prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 810))

        let snapshot = masjid.snapshot

        #expect(snapshot.name == "Masjid al-Noor")
        #expect(snapshot.entry(for: .dhuhr).fixedMinutesFromMidnight == 810)
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `swift test --package-path Packages/IhsanCore --filter MyMasjidTests`
Expected: FAIL — `cannot find 'MyMasjid' in scope`.

- [ ] **Step 4: Write `MyMasjid.swift`**

```swift
import Foundation
import SwiftData

/// The user's own masjid: a name they typed, optionally the venue they
/// picked out of the nearby search, and the iqamah times they know.
///
/// Nothing here is fetched. There is no masjid-times network dependency
/// anywhere in this app, by design — these are the times the person
/// read off a board and entered.
///
/// The stored coordinate is the single carve-out to privacy invariant
/// #1 (see CLAUDE.md): device-derived coordinates remain transient, but
/// a venue the user deliberately chose and typed times for is their own
/// datum. It is encrypted at rest and stays in the private database.
@Model
public final class MyMasjid {
    public static let singletonID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    public var id: UUID = MyMasjid.singletonID

    @Attribute(.allowsCloudEncryption)
    public var name: String?

    @Attribute(.allowsCloudEncryption)
    public var streetLabel: String?

    @Attribute(.allowsCloudEncryption)
    public var latitude: Double?

    @Attribute(.allowsCloudEncryption)
    public var longitude: Double?

    public var iqamahConfigJSON: String = "[]"

    /// The khutbah's wall-clock time, minutes from local midnight.
    /// Fixed only — a khutbah is announced, not derived.
    public var jumuahKhutbahMinutesFromMidnight: Int?

    /// One lead time for the whole masjid. Someone thinks about their
    /// commute once, not five times.
    public var reminderLeadMinutes: Int = 10

    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    public init(
        id: UUID = MyMasjid.singletonID,
        name: String? = nil,
        streetLabel: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        iqamahConfigJSON: String = "[]",
        jumuahKhutbahMinutesFromMidnight: Int? = nil,
        reminderLeadMinutes: Int = 10,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.streetLabel = streetLabel
        self.latitude = latitude
        self.longitude = longitude
        self.iqamahConfigJSON = iqamahConfigJSON
        self.jumuahKhutbahMinutesFromMidnight = jumuahKhutbahMinutesFromMidnight
        self.reminderLeadMinutes = reminderLeadMinutes
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// The record, or nil. The display surfaces ask this — they must be
    /// able to find out that no masjid is set without creating one as a
    /// side effect of asking.
    public static func fetchExisting(in context: ModelContext) -> MyMasjid? {
        let singletonID = MyMasjid.singletonID
        var descriptor = FetchDescriptor<MyMasjid>(
            predicate: #Predicate<MyMasjid> { $0.id == singletonID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    public static func fetchOrCreate(in context: ModelContext) throws -> MyMasjid {
        if let existing = fetchExisting(in: context) { return existing }
        let masjid = MyMasjid()
        context.insert(masjid)
        return masjid
    }

    // MARK: - Entries

    public var iqamahEntries: [IqamahEntry] {
        let stored = IqamahSchedule.decode(iqamahConfigJSON)
        guard !stored.isEmpty else { return IqamahSchedule.empty }
        return Prayer.allCases.map { prayer in
            stored.first { $0.prayer == prayer } ?? IqamahEntry(prayer: prayer)
        }
    }

    public func entry(for prayer: Prayer) -> IqamahEntry {
        iqamahEntries.first { $0.prayer == prayer } ?? IqamahEntry(prayer: prayer)
    }

    public func setEntry(_ entry: IqamahEntry) {
        var entries = iqamahEntries
        if let index = entries.firstIndex(where: { $0.prayer == entry.prayer }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        iqamahConfigJSON = IqamahSchedule.encode(entries)
        modifiedAt = .now
    }

    public var hasAnyIqamah: Bool {
        iqamahEntries.contains(\.isSet) || jumuahKhutbahMinutesFromMidnight != nil
    }

    /// Point this record at a different venue. The times go with the old
    /// one: they described that congregation's schedule, and carrying
    /// them across would present another masjid's times as this one's.
    public func replaceVenue(
        name: String?,
        streetLabel: String?,
        latitude: Double?,
        longitude: Double?
    ) {
        self.name = name
        self.streetLabel = streetLabel
        self.latitude = latitude
        self.longitude = longitude
        self.iqamahConfigJSON = "[]"
        self.jumuahKhutbahMinutesFromMidnight = nil
        self.modifiedAt = .now
    }

    public var snapshot: MyMasjidSnapshot {
        MyMasjidSnapshot(
            name: name,
            streetLabel: streetLabel,
            entries: iqamahEntries,
            jumuahKhutbahMinutesFromMidnight: jumuahKhutbahMinutesFromMidnight,
            reminderLeadMinutes: reminderLeadMinutes
        )
    }
}
```

- [ ] **Step 5: Write `MyMasjidSnapshot.swift`**

```swift
import Foundation

/// A `Sendable` copy of the masjid for views, actors, and the
/// notification scheduler. `@Model` types are not `Sendable` under
/// Swift 6 and must never cross an isolation boundary; this does.
///
/// The coordinate is deliberately absent: no display surface needs it,
/// and the narrowest snapshot is the one least able to leak.
public struct MyMasjidSnapshot: Sendable, Equatable {
    public let name: String?
    public let streetLabel: String?
    public let entries: [IqamahEntry]
    public let jumuahKhutbahMinutesFromMidnight: Int?
    public let reminderLeadMinutes: Int

    public init(
        name: String?,
        streetLabel: String?,
        entries: [IqamahEntry],
        jumuahKhutbahMinutesFromMidnight: Int?,
        reminderLeadMinutes: Int
    ) {
        self.name = name
        self.streetLabel = streetLabel
        self.entries = entries
        self.jumuahKhutbahMinutesFromMidnight = jumuahKhutbahMinutesFromMidnight
        self.reminderLeadMinutes = reminderLeadMinutes
    }

    public func entry(for prayer: Prayer) -> IqamahEntry {
        entries.first { $0.prayer == prayer } ?? IqamahEntry(prayer: prayer)
    }

    public var hasAnyIqamah: Bool {
        entries.contains(\.isSet) || jumuahKhutbahMinutesFromMidnight != nil
    }
}
```

- [ ] **Step 6: Write `IhsanSchemaV9.swift`**

```swift
import SwiftData

/// Current schema. Adds one entity, `MyMasjid`, holding the iqamah
/// times a person entered by hand.
///
/// V8 was frozen into nested snapshots rather than extended, for the
/// same reason V5 through V7 were: stores on disk already claim that
/// version. A new entity with no change to any existing record type
/// migrates lightweight.
public enum IhsanSchemaV9: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(9, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            PrayerLog.self,
            Reflection.self,
            DayRecord.self,
            PauseInterval.self,
            TravelInterval.self,
            PeriodSummary.self,
            UserSettings.self,
            QadaLedger.self,
            QadaEntry.self,
            NaflLog.self,
            FastLog.self,
            DhikrSession.self,
            AdhkarSession.self,
            MyMasjid.self
        ]
    }
}
```

- [ ] **Step 7: Append the stage to `IhsanMigrationPlan.swift`**

Add `IhsanSchemaV9.self` to `schemas`, and append:

```swift
.lightweight(
    fromVersion: IhsanSchemaV8.self,
    toVersion: IhsanSchemaV9.self
)
```

Then update whatever names the current schema in `ModelContainer/` (grep for `IhsanSchemaV8` outside the `Schema/` directory) to `IhsanSchemaV9`.

- [ ] **Step 8: Append the migration test**

In `SchemaMigrationTests.swift`, add a `seedV8Store(at:)` following the existing `seedV7Store` shape, then:

```swift
@Test
func migratesV8StoreToCurrent() async {
    await #expect(processExitsWith: .success) {
        // Runs in its own process: the frozen-schema snapshots share a
        // process-wide entity-name cache, so a seed in this process
        // would poison every later suite.
        try withMigratedStore(seed: seedV8Store) { context in
            let masjids = try context.fetch(FetchDescriptor<MyMasjid>())
            #expect(masjids.isEmpty)

            // The upgrade adds an entity and touches nothing else.
            let settings = try context.fetch(FetchDescriptor<UserSettings>())
            #expect(settings.count == 1)
            #expect(settings[0].nightWakeEnabled == false)
        }
    }
}
```

- [ ] **Step 9: Run the tests**

Run: `swift test --package-path Packages/IhsanCore`
Expected: PASS — `MyMasjidTests` (7), the new migration test, and every pre-existing suite still green.

- [ ] **Step 10: Commit**

```bash
git add Packages/IhsanCore/
git commit -m "utilities: hold a masjid's own iqamah times"
```

---

### Task 3: The editor

**Files:**
- Create: `ihsan/Masjid/MyMasjidEditorScreen.swift`
- Create: `ihsan/Masjid/Components/IqamahRow.swift`
- Modify: `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Components/SettingsGlyph.swift` — add `case masjid`
- Modify: `ihsan/Settings/SettingsScreen.swift` — `SettingsRoute.myMasjid`, its `navigationDestination` arm, its `debugName`, and a row in the appropriate section

**Interfaces:**
- Consumes: `MyMasjid`, `IqamahEntry`, `IqamahSchedule` (Tasks 1–2); `PickerScaffold`, `SettingsSectionCard`, `SettingsRow`, `SettingsDescriptionText`, `IhsanFont`, `IhsanSpacing`, `SkyPaletteTokens` (existing).
- Produces: `MyMasjidEditorScreen(masjid:todaySchedule:)`, `IqamahRow`.

**Design notes — follow these exactly:**

- The editor is a `PickerScaffold(title: "My Masjid")` holding `SettingsSectionCard`s. It is not a `Form`; a stock Form breaks the illuminated-panel surface.
- Rows run in prayer order — a real sequence (the day's own), so no invented numbering.
- **Each row prints the time it resolves to today**, small and quiet beneath the control: `TODAY · 5:42 AM`. This is the signature element, and it is what makes a wrong entry self-evident instead of silently misresolved. Where today's schedule is unavailable, print nothing rather than a guess.
- Time entry uses `DatePicker(.hourAndMinute).labelsHidden()`. It is the correct native control: localized to 12/24h, Dynamic Type-correct, and accessible. Do not hand-roll one. Convert to/from minutes-from-midnight at the boundary.
- Offset entry uses the file's existing `miniCountControl` pattern (step 5, range 0...90).
- **No gold anywhere in this screen.** Gold means *committed* in this app — the logged ornament, the ON TIME button, the LOG chip. An informational time may not borrow it.
- The Jumu'ah row sits in its own section beneath a divider: it is not a sixth prayer, it is a substitution for one.
- Remove uses the existing `.remove` glyph and a confirmation dialog.

- [ ] **Step 1: Add the `masjid` glyph**

In `SettingsGlyph.swift`, add `case masjid` to the enum and a drawing arm matching the engraved-linework weight of the neighbouring `.nightMoon` case: a centred arch (two mirrored quarter-curves meeting at an apex) over a level base line, stroked, no fill. Keep to the same `Path`-in-`Canvas` idiom the other cases use and the same stroke width.

- [ ] **Step 2: Write `IqamahRow.swift`**

```swift
import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// One prayer's iqamah: the rule, and the time that rule produces today.
///
/// The resolved line is the point of this row. An iqamah entered wrong —
/// a fixed time that lands before its adhan, an offset with a stray
/// digit — is invisible in the rule and obvious in the answer, so the
/// answer is always on screen.
struct IqamahRow: View {
    let prayer: Prayer
    /// Today's adhan for this prayer, in the place's timezone. `nil`
    /// where no schedule is in hand — the resolved line then prints
    /// nothing rather than a guess.
    let adhan: Date?
    let timeZone: TimeZone
    let tokens: SkyPaletteTokens
    let entry: IqamahEntry
    let onChange: (IqamahEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
            Divider()
                .overlay(tokens.metal.opacity(0.18))

            HStack {
                Text(prayer.displayNameEnglish)
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.ink)
                Spacer()
                modePicker
            }

            valueControl

            if let resolvedLine {
                Text(resolvedLine)
                    .font(IhsanFont.inscription)
                    .tracking(1.3)
                    .foregroundStyle(tokens.inkSecondary)
                    .accessibilityLabel(spokenResolvedLine ?? resolvedLine)
            }

            if entry.isSet {
                Toggle(isOn: reminderBinding) {
                    Text("Remind me")
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(tokens.inkSecondary)
                }
                .tint(tokens.leafGold)
                .accessibilityLabel("Remind me before \(prayer.displayNameEnglish) iqamah")
            }
        }
        .settingsControlInset()
        .padding(.vertical, IhsanSpacing.xs)
    }

    // Mode, value control, and bindings follow the file's existing
    // control idioms: a segmented Picker over IqamahEntry.Mode with
    // labels "—", "Time", "Offset"; DatePicker(.hourAndMinute) for
    // .fixed; miniCountControl(step: 5, range: 0...90) for .offset.
    // Every control carries an accessibilityLabel naming its prayer.

    private var resolvedLine: String? {
        guard let adhan,
              let resolved = IqamahSchedule.resolve(
                  entry: entry, adhan: adhan, timeZone: timeZone
              )
        else { return nil }
        return "TODAY · \(PlateTimeFormat.time(resolved, in: timeZone))"
    }

    private var spokenResolvedLine: String? {
        guard let adhan,
              let resolved = IqamahSchedule.resolve(
                  entry: entry, adhan: adhan, timeZone: timeZone
              )
        else { return nil }
        return "Today, \(PlateTimeFormat.time(resolved, in: timeZone))"
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { entry.reminderEnabled },
            set: { newValue in
                var updated = entry
                updated.reminderEnabled = newValue
                onChange(updated)
            }
        )
    }
}
```

- [ ] **Step 3: Write `MyMasjidEditorScreen.swift`**

A `PickerScaffold(title: "My Masjid")` containing:
1. `SettingsSectionCard("The masjid")` — a `TextField` bound to `masjid.name` with placeholder `Name`, and the street label beneath as an inscription when one came from the search.
2. `SettingsSectionCard("Iqamah")` — `ForEach(Prayer.allCases)` of `IqamahRow`, then `SettingsDescriptionText("Enter the times your masjid keeps. An offset follows the calculated adhan each day; a set time stays where you put it.")`
3. `SettingsSectionCard("Jumu'ah")` — a khutbah `DatePicker(.hourAndMinute)` with a clear action, plus `SettingsDescriptionText("On Fridays this replaces the Dhuhr iqamah.")`
4. `SettingsSectionCard("Reminders")` — the shared `miniCountControl(label: "Remind me before iqamah (min)", value: masjid.reminderLeadMinutes, step: 5, range: 0...60)`, plus `SettingsDescriptionText("A reminder arrives only for the prayers you switched on above, and never during a pause or after you have logged that prayer.")`
5. `SettingsRow(title: "Remove my masjid", glyph: .remove, action:)` behind a `confirmationDialog`, deleting the record.

- [ ] **Step 4: Wire the route**

In `SettingsScreen.swift`: add `case myMasjid` to `SettingsRoute` and to its `#if DEBUG init?(debugName:)`; add the `navigationDestination` arm; add `SettingsRow(title: "My Masjid", subtitle: masjidSubtitle, glyph: .masjid, action:)` to the `LocationSection` (it belongs with place, not with notifications). `masjidSubtitle` is the masjid's name, or `"Not set"`.

- [ ] **Step 5: Build**

Run: `xcodebuild -project ihsan.xcodeproj -scheme ihsan -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
Expected: BUILD SUCCEEDED. If Xcode was open, quit and reopen it first — synchronized groups cache their file list and a stale one fails on the new files.

- [ ] **Step 6: Commit**

```bash
git add ihsan/Masjid/ ihsan/Settings/SettingsScreen.swift \
        Packages/IhsanDesignSystem/
git commit -m "utilities: a calm editor for a masjid's times"
```

---

### Task 4: The seamless door — Nearby Masjids

**Files:**
- Modify: `ihsan/MasjidFinder/Components/MasjidResultRow.swift`
- Modify: `ihsan/MasjidFinder/MasjidFinderScreen.swift`
- Test: `ihsanTests/MyMasjidDoorTests.swift`

**Interfaces:**
- Consumes: `MyMasjid.replaceVenue(name:streetLabel:latitude:longitude:)` (Task 2); `MasjidResult` (existing).
- Produces: `MasjidResultRow(result:tokens:isMyMasjid:onTap:onSetAsMine:)`.

**Design notes:**

- The row grows a **third line**: a gilded `SET AS MY MASJID` inscription button beneath the detail line. Full-width tap target — two targets crammed into the trailing column collapse under `.accessibility5` and hand VoiceOver two rects contending for one space.
- When this row already *is* the masjid, the same line renders `MY MASJID` in `tokens.metal`, non-interactive, with no button traits. Same register, same position: the line changes what it says, not the row's structure.
- **This is the only gold in the feature**, and it earns it: setting your masjid is a commitment, which is what gold means here.
- Choosing a different venue while one is set must state the replacement before it happens — a `confirmationDialog` titled `"Replace your masjid?"` with the message `"The times you entered belong to \(existingName). They will be cleared."` and a destructive `"Replace"` action.
- `MasjidFinderScreen` still writes no coordinates anywhere on the search path. The only write is the deliberate one, through `replaceVenue`.

- [ ] **Step 1: Write the failing test**

`ihsanTests/MyMasjidDoorTests.swift` — with an in-memory container: set a masjid from result A, enter a Dhuhr time, then `replaceVenue` from result B; assert name and coordinate are B's and `hasAnyIqamah == false`. Also assert that a row whose name and coordinate match the stored masjid reports `isMyMasjid`.

- [ ] **Step 2: Run to verify failure**, then **Step 3: implement the row and screen wiring**, then **Step 4: run to verify pass**.

- [ ] **Step 5: Verification captures**

Capture the sheet in both row states at default and `.accessibility5` Dynamic Type. Confirm the row does not clip and the third line stays legible.

- [ ] **Step 6: Commit**

```bash
git add ihsan/MasjidFinder/ ihsanTests/MyMasjidDoorTests.swift
git commit -m "utilities: set a nearby masjid as your own"
```

---

### Task 5: The project-doc repairs

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Amend privacy invariant #1**

Replace the first invariant with the amended wording from the spec (§A6): device-derived coordinates transient; a venue the user names is their own datum, encrypted, private-database, never sent anywhere. Name `MyMasjid.latitude/longitude` explicitly as the single carve-out so a fresh session cannot read it as a general licence.

- [ ] **Step 2: Correct the schema section**

The Persistence section claims `IhsanSchemaV1`. The store is at V8 and this branch takes it to V10. Correct it, and add the standing rule:

> The schema section of this file is bumped **with every migration**. A project doc that lies about the schema version will eventually talk a fresh session into writing a colliding one.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "utilities: say what the schema and the invariant actually are"
```

- [ ] **Step 4: Phase 1 verification report, then push**

```bash
swift test --package-path Packages/IhsanCore
git push -u origin daily-utilities
```

---

# Phase 2 — My Masjid: display

### Task 6: The inscription, and Friday

**Files:**
- Create: `ihsan/Today/Helpers/IqamahInscription.swift`
- Test: `ihsanTests/IqamahInscriptionTests.swift`

**Interfaces:**
- Consumes: `MyMasjidSnapshot`, `IqamahSchedule` (Tasks 1–2).
- Produces: `IqamahInscription.text(snapshot:prayer:adhan:timeZone:) -> String?`, `IqamahInscription.spoken(...) -> String?`.

Rules the tests must pin:
- Renders `IQAMAH · 1:30 PM` — always the resolved time, **never** the formula, for both modes.
- `nil` for a prayer with no entry, and `nil` when no masjid is set.
- On Friday **in the place's timezone**, a Dhuhr with a khutbah time renders `KHUTBAH · 1:15 PM` instead. Friday is `Calendar.component(.weekday)` == 6 with the calendar's timezone set to the place's — a Thursday-evening device in another zone must not change what the card says.
- On Friday with no khutbah time set, Dhuhr keeps its ordinary iqamah inscription.
- Non-Dhuhr prayers are unaffected on Fridays.
- The spoken form drops the middot: `Iqamah, 1:30 PM`.

- [ ] **Step 1: Write the failing tests** covering each rule above, including a case built in `Asia/Tokyo` and read from a device in `America/Chicago` to pin the timezone rule.
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement `IqamahInscription`.**
- [ ] **Step 4: Run to verify pass.**
- [ ] **Step 5: Commit** — `utilities: name the congregation's time`

---

### Task 7: Card and sheet

**Files:**
- Modify: `ihsan/Today/Components/FocusedPrayerCard.swift`
- Modify: `ihsan/Today/Components/PrayerLogSheet.swift`
- Modify: `ihsan/Today/ViewModel/TodayState.swift`, `ihsan/Today/ViewModel/TodayViewModel.swift`
- Modify: `ihsan/Today/TodayScreen.swift`

**Interfaces:**
- Consumes: `IqamahInscription` (Task 6), `MyMasjidSnapshot` (Task 2).
- Produces: `FocusedPrayerCard.iqamahInscription: String?` (new optional property, defaulting `nil` so every existing call site and preview compiles unchanged); `TodayState.Snapshot.myMasjid: MyMasjidSnapshot?`.

**Design notes:**

- The iqamah joins **the state line's own register** — same `IhsanFont.inscription`, same tracking, same `tokens.inkSecondary`. Not a badge, not a chip, not a pill, and **not gilded**.
- It is a second line beneath the state line, present only when non-nil.
- **The plate is untouched.** No iqamah on `CelestialPlateScene`, ever.
- In the log sheet it sits directly beneath the window line in the header.

**The one layout risk.** `FocusedPrayerCard.cardHeight` is a fixed 140pt and `TodayCompositionMetrics` lays the celestial scene against it. `.active` and `.logged` have room. `.upcoming` already carries a title-size numeral plus an inscription — verify it at `.accessibility5` in Step 4. If it crowds, introduce `FocusedPrayerCard.cardHeight(hasIqamah:)` and thread it through `TodayCompositionMetrics`. **Do not** resolve crowding by truncating or by lowering `minimumScaleFactor`.

- [ ] **Step 1:** Thread `MyMasjidSnapshot?` through `TodayState.Snapshot` and `TodayViewModel.refreshSnapshot()` via `MyMasjid.fetchExisting(in:)?.snapshot`.
- [ ] **Step 2:** Add the inscription to both surfaces.
- [ ] **Step 3:** Build.
- [ ] **Step 4: Verification captures** — focused card with a fixed-mode iqamah, with an offset-mode iqamah (showing the resolved time), on a Friday with a khutbah time, and with no masjid set (the card must be pixel-identical to today's). Each at default and `.accessibility5`. Plus the log sheet header.
- [ ] **Step 5: Commit** — `utilities: show the iqamah beside the adhan`

---

### Task 8: Iqamah reminders

**Files:**
- Modify: `Packages/IhsanNotifications/Sources/IhsanNotifications/NotificationScheduler.swift`
- Modify: `Packages/IhsanNotifications/Sources/IhsanNotifications/NotificationContent.swift`
- Test: `Packages/IhsanNotifications/Tests/IhsanNotificationsTests/IqamahReminderTests.swift`

**Interfaces:**
- Consumes: `MyMasjidSnapshot`, `IqamahSchedule`.
- Produces: `NotificationScheduleSettings.myMasjid: MyMasjidSnapshot?`, `NotificationScheduleSettings.loggedPrayerKeys: Set<String>`, `NotificationScheduler.iqamahIdentifierPrefix`.

Rules the tests must pin, using the existing `MockNotificationCenter`:
- A reminder is scheduled at `resolvedIqamah − reminderLeadMinutes · 60`, for each prayer whose entry has `reminderEnabled` **and** `isSet`.
- Identifier is `"ihsan.iqamah.\(prayer.rawValue).\(Int(fireDate.timeIntervalSince1970))"`. It sits under the `ihsan.` sweep so `cancelAllScheduledNotifications` clears it, and it rebuilds on the same rolling-window cadence as the prayer notifications.
- **No** reminder when `prayerNotificationsSuppressed` is true (an open excused pause).
- **No** reminder for a prayer already carrying a log that day — keyed off `loggedPrayerKeys`, which the settings provider populates with `PrayerLog.dedupKey`s for the window.
- **No** reminder when `myMasjid` is nil, when the entry's mode is `.none`, or when `reminderEnabled` is false.
- A reminder whose fire time has already passed is not scheduled.
- Interruption level is **not** `.timeSensitive` — this is an ordinary notification, not an alarm.
- Copy: title `"Iqamah at \(masjidName)"` (or `"Iqamah"` with no name), body `"\(Prayer) iqamah in \(n) minutes."` — factual, no exhortation, banned-language clean.

- [ ] **Step 1: Write the failing tests** — one per rule above.
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to verify pass.**
- [ ] **Step 5: Commit** — `utilities: remind before iqamah, and stay quiet when asked`

- [ ] **Step 6: Phase 2 verification report, then push.**

---

# Phase 3 — Wake anchors

### Task 9: `WakeAnchor`, `WakeEvents`, `WakeAnchorPlanner`

**Files:**
- Create: `Packages/IhsanCore/Sources/IhsanCore/Wake/WakeAnchor.swift`
- Create: `Packages/IhsanNotifications/Sources/IhsanNotifications/WakeAnchors.swift`
- Modify: `Packages/IhsanNotifications/Sources/IhsanNotifications/NightWake.swift` — `NightWakePlanner` becomes a thin deprecated shim over the new planner, or is deleted once no caller remains
- Test: `Packages/IhsanNotifications/Tests/IhsanNotificationsTests/WakeAnchorTests.swift`

**Interfaces:**
- Consumes: `NightIntervals`, `DayPrayerTimes` (existing).
- Produces: `WakeAnchor`, `WakeAnchorConfig`, `WakeEvents(lastThirdStart:fajrStart:sunrise:maghrib:)`, `WakeEvents.instant(for:)`, `WakeAnchorPlan(anchor:fireDate:)`, `WakeAnchorPlanner.plan(events:config:isPaused:now:)`, `WakeAnchorPlanner.nextPlan(days:config:isPaused:now:)`, `WakeAnchorCoordinator`.

Rules the tests must pin:
- **The identity:** for every anchor and every offset, `plan.fireDate == events.instant(for: anchor) − offsetMinutes · 60`. Test as a loop over all four anchors × a range of offsets.
- A disabled anchor plans nothing.
- A paused user plans nothing, **for every anchor** — one test per anchor, not one test with a single anchor.
- A fire time already behind `now` plans nothing; the next day's is chosen instead.
- **Across a DST boundary:** build two days spanning a spring-forward and a fall-back date and assert the identity still holds exactly — the events are absolute instants, so the subtraction is unaffected, and this test is what proves no local-time arithmetic crept in.
- **Across a location change:** recomputing with different coordinates yields a different `fireDate`, and `WakeAnchorCoordinator.sync` cancels before scheduling — assert the mock client sees exactly one cancel and one schedule, and one standing fire date.
- **No double-fire:** syncing the same plan twice issues no second schedule; syncing a changed plan issues exactly one cancel then one schedule.
- Each anchor gets its **own** coordinator and its own stable alarm ID: assert the four IDs are distinct and stable across instantiations.

- [ ] **Step 1: Write the failing tests.**
- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** `WakeAnchor` / `WakeAnchorConfig` in `IhsanCore` (they are stored, so they belong with the model layer) and `WakeEvents` / `WakeAnchorPlanner` / `WakeAnchorCoordinator` in `IhsanNotifications`, generalising the existing `NightWakePlanner` and `NightWakeCoordinator`.
- [ ] **Step 4: Run to verify pass.**
- [ ] **Step 5: Commit** — `utilities: four anchors, one arithmetic`

---

### Task 10: Schema V10 and the migration that preserves a configured wake

**Files:**
- Modify: `Packages/IhsanCore/Sources/IhsanCore/Models/UserSettings.swift`
- Create: `Packages/IhsanCore/Sources/IhsanCore/Schema/IhsanSchemaV10.swift`
- Modify: `Packages/IhsanCore/Sources/IhsanCore/Schema/IhsanMigrationPlan.swift`
- Test: `Packages/IhsanCore/Tests/IhsanCoreTests/SchemaMigrationTests.swift` (append)

**Interfaces:**
- Produces: `UserSettings.wakeAnchorsConfigJSON`, `UserSettings.suhoorAnchorOfferedAt`, `UserSettings.wakeAnchorConfigs: [WakeAnchorConfig]`, `UserSettings.wakeAnchorConfig(for:)`, `UserSettings.setWakeAnchorConfig(_:)`.

- [ ] **Step 1:** Freeze V9 into nested snapshots.
- [ ] **Step 2:** Add the two columns to the live `UserSettings`, defaulting `wakeAnchorsConfigJSON` to **all four anchors off**. Mark `nightWakeEnabled` and `nightWakeOffsetMinutes` vestigial in a doc comment, in the established house style — say what replaced them and why deleting them is not worth a migration over every row.
- [ ] **Step 3: Write the failing migration test**

```swift
@Test
func migratesV9StoreAndKeepsAConfiguredWake() async {
    await #expect(processExitsWith: .success) {
        // The seed writes nightWakeEnabled = true, offset = 15.
        try withMigratedStore(seed: seedV9StoreWithConfiguredWake) { context in
            let settings = try context.fetch(FetchDescriptor<UserSettings>())[0]

            let lastThird = settings.wakeAnchorConfig(for: .lastThird)
            #expect(lastThird.isEnabled)
            #expect(lastThird.offsetMinutes == 15)

            for anchor in [WakeAnchor.fajrStart, .sunrise, .maghrib] {
                #expect(settings.wakeAnchorConfig(for: anchor).isEnabled == false)
                #expect(settings.wakeAnchorConfig(for: anchor).offsetMinutes == 0)
            }
        }
    }
}

@Test
func migratesV9StoreAndLeavesAnUnsetWakeOff() async {
    await #expect(processExitsWith: .success) {
        try withMigratedStore(seed: seedV9Store) { context in
            let settings = try context.fetch(FetchDescriptor<UserSettings>())[0]
            for anchor in WakeAnchor.allCases {
                #expect(settings.wakeAnchorConfig(for: anchor).isEnabled == false)
            }
        }
    }
}
```

- [ ] **Step 4: Run to verify failure.**
- [ ] **Step 5: Write `IhsanSchemaV10.swift` and the custom stage**

```swift
.custom(
    fromVersion: IhsanSchemaV9.self,
    toVersion: IhsanSchemaV10.self,
    willMigrate: nil,
    didMigrate: { context in
        // The last-third wake keeps the configuration its owner set.
        // Written EXPLICITLY, for the reason V6 -> V7 was: a
        // lightweight stage would let the new model's all-off default
        // land on an upgrader and silently retire a wake they rely on.
        let settings = try context.fetch(
            FetchDescriptor<IhsanSchemaV10.UserSettings>()
        )
        for setting in settings {
            let configs = [
                WakeAnchorConfig(
                    anchor: .lastThird,
                    isEnabled: setting.nightWakeEnabled,
                    offsetMinutes: setting.nightWakeOffsetMinutes
                ),
                WakeAnchorConfig(anchor: .fajrStart, isEnabled: false, offsetMinutes: 0),
                WakeAnchorConfig(anchor: .sunrise, isEnabled: false, offsetMinutes: 0),
                WakeAnchorConfig(anchor: .maghrib, isEnabled: false, offsetMinutes: 0),
            ]
            setting.wakeAnchorsConfigJSON = WakeAnchorConfig.encode(configs)
        }
        try context.save()
    }
)
```

- [ ] **Step 6: Run to verify pass.**
- [ ] **Step 7: Commit** — `utilities: carry a configured wake across the migration`

---

### Task 11: `WakeAnchorService` and the one sound constant

**Files:**
- Create: `ihsan/Night/WakeAnchorService.swift` (replaces `ihsan/Night/NightWakeService.swift`)
- Delete: `ihsan/Night/NightWakeService.swift`
- Modify: `ihsan/Today/ViewModel/TodayViewModel.swift` — both refresh call sites (`refreshSnapshot`, the location-change observer)
- Modify: `ihsan/App/IhsanApp.swift` and `ihsan/Settings/SettingsScreen.swift` — the remaining `NightWakeService` references
- Modify: `Packages/IhsanNotifications/Sources/IhsanNotifications/AdhanSoundCatalog.swift` — doc note only
- Test: `Packages/IhsanNotifications/Tests/IhsanNotificationsTests/NotificationSchedulerTests.swift` — widen the existing tone test

- [ ] **Step 1: Widen the tone test**

```swift
@Test
func everyWakeAnchorSharesOneTone() {
    // AdhanAsset.nightWake is a computed alias for chime and is THE
    // swap point: when the muezzin-era recordings land, replacing the
    // chime replaces all four anchors with no code change here. This
    // test exists so the swap point cannot quietly become plural.
    for anchor in WakeAnchor.allCases {
        #expect(WakeSound.assetName(for: anchor) == AdhanAsset.nightWake)
    }
    #expect(AdhanAsset.nightWake == AdhanAsset.chime)
}
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement `WakeAnchorService`**

Generalise `NightWakeService`: one `WakeAnchorCoordinator` per anchor for the AlarmKit path and one per anchor for the notification fallback, four distinct stable UUIDs, four distinct notification identifiers. `refresh(using:)` computes each day's `WakeEvents` from the resolved place and settings, and syncs each anchor independently.

`.lastThird` **keeps its gate**: it is enabled only when `sunnahLayerEnabled && sunnahNightEnabled && config.isEnabled`. The other three read their config alone. Nobody's alarm behaviour changes on upgrade.

`WakeSound.assetName(for:)` returns `AdhanAsset.nightWake` for every anchor. Per-anchor alert titles: `.lastThird` keeps `"The last third of the night"`; `.fajrStart` `"Fajr begins soon"`; `.sunrise` `"Fajr's window is closing"`; `.maghrib` `"Maghrib"`.

- [ ] **Step 4: Run to verify pass.**
- [ ] **Step 5: Commit** — `utilities: one service, four anchors, one tone`

---

### Task 12: "Wakes & alarms" in Set

**Files:**
- Modify: `ihsan/Settings/SettingsScreen.swift`

- [ ] **Step 1: Build the group**

A new `WakesAndAlarmsSection` with one row per anchor, each a toggle plus (when on) a `miniCountControl` for its minutes-before, plus a one-line `SettingsDescriptionText`:

| Anchor | Row title | Description |
| --- | --- | --- |
| `.fajrStart` | Suhoor's end | Before Fajr begins — while the meal is still open. |
| `.sunrise` | Before Fajr ends | Wake in time to pray before sunrise. |
| `.maghrib` | Iftar | When the fast opens at Maghrib. |
| `.lastThird` | Gentle wake | *(existing copy, verbatim, unchanged)* |

The `.lastThird` row renders **only when `sunnahLayerEnabled && sunnahNightEnabled`**, and keeps its existing copy and its existing fallback note. The other three are always present. Remove the wake controls from `SunnahSection`, leaving the night-prayer toggle itself in place.

- [ ] **Step 2: Build and capture** the group in all states — night layer off (three rows), night layer on (four rows), an anchor enabled showing its offset control — at default and `.accessibility5`.
- [ ] **Step 3: Commit** — `utilities: gather the wakes into one group`

---

### Task 13: The Ramadan suhoor offer

**Files:**
- Modify: the fasting register view under `ihsan/Ramadan/`
- Modify: `Packages/IhsanCore/Sources/IhsanCore/Models/UserSettings.swift` — uses `suhoorAnchorOfferedAt` from Task 10
- Test: `ihsanTests/SuhoorOfferTests.swift`

Rules the tests must pin:
- The line appears only during Ramadan, only when `.fajrStart` is disabled, and only when `suhoorAnchorOfferedAt` is nil.
- Accepting it enables `.fajrStart` and stamps `suhoorAnchorOfferedAt`.
- Dismissing it stamps `suhoorAnchorOfferedAt` and leaves the anchor **off**.
- Once stamped it never returns, in this Ramadan or the next.
- It is **never** auto-enabled — no code path sets `.fajrStart.isEnabled = true` without an explicit tap.

Copy: `"A wake before Fajr can mark the end of suhoor."` with actions `Turn on` / `Not now`. Offered, never assumed.

- [ ] **Step 1–4:** failing tests → verify failure → implement → verify pass.
- [ ] **Step 5: Commit** — `utilities: offer the suhoor wake, once`

---

### Task 14: The sweeps

**Files:**
- Modify: `ihsanTests/BannedLanguageSweepTests.swift`
- Modify: `POLISH_FINDINGS.md`

- [ ] **Step 1:** Append every new user-facing source to `sweptFiles`: the two `Masjid/` files, `IqamahInscription.swift`, `IqamahEntry.swift`, `MyMasjid.swift`, `WakeAnchor.swift`, `WakeAnchors.swift`, `WakeAnchorService.swift`, and the modified `MasjidResultRow.swift`, `FocusedPrayerCard.swift`, `PrayerLogSheet.swift`, `SettingsScreen.swift`, `NotificationContent.swift`.
- [ ] **Step 2:** Run the full app test suite. Diff failures **by name** against a clean `main` worktree — roughly nine `ihsanUITests` fail on `main` itself and *which* nine drifts, so a count comparison proves nothing.
- [ ] **Step 3:** Confirm strict concurrency across all packages: `swift build --package-path Packages/<each>` with no warnings.
- [ ] **Step 4:** Contrast check the new inscriptions against every SkyPhase ground; VoiceOver pass over the editor, the nearby row, the card, and the new Set group; Reduce Motion and Reduce Transparency on the editor.
- [ ] **Step 5:** Append the device-only items to `POLISH_FINDINGS.md` — a timed real-device fire test for one anchor is a device claim and belongs there, not in a source-only assertion.
- [ ] **Step 6: Commit** — `utilities: sweep the new surfaces`
- [ ] **Step 7: Phase 3 verification report, push, open the PR.**

---

## Self-review

**Spec coverage.** §A1→T2, §A2→T1, §A3→T1, §A4→T2, §A5→T3+T4, §A6→T5, §B1→T6+T7, §B2→T7 step 4, §B3→T8, §C1→T9, §C2→T9, §C3→T11, §C4→T10, §C5→T12, §C6→T13, Testing→throughout+T14, project-doc repairs→T5. No gap.

**Type consistency.** `IqamahEntry.mode`/`fixedMinutesFromMidnight`/`offsetMinutes`/`reminderEnabled` are used under those exact names in T2, T3, T6, T8. `MyMasjidSnapshot.entry(for:)` matches `MyMasjid.entry(for:)`. `WakeAnchorConfig(anchor:isEnabled:offsetMinutes:)` is constructed identically in T9, T10, T12. `WakeSound.assetName(for:)` is defined in T11 and used only there.

**One deliberate looseness.** T3, T4, T12, and T13 specify interfaces, copy, and design rules but not every line of view code — SwiftUI view bodies are where a plan's invented code diverges most from a real codebase's idioms, and each of those tasks names the exact existing component to follow instead. Every task that carries logic worth getting wrong carries its test code in full.
