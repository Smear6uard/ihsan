# Corrective K — the two clocks, and the voluntary rows done right

Date: 2026-08-05

Two defects, one cause and one omission.

**A.** The tracking day rolls at midnight. Isha's window runs past
midnight, so a 1 AM Isha is attributed to the wrong day; and the
Islamic calendar day begins at Maghrib, which the app ignores
everywhere.

**B.** The nafl/dhikr rows on Path's pattern card were never built to
the approved design: no row labels, and nothing in the code proves
their marks land on the prayer columns' grid.

---

## Phase 1 — the two-clock day model

Midnight stops being a boundary in tracking code. Two clocks are named
explicitly in `IhsanCore`, and every consumer routes through one of
them.

### Clock 1 — the prayer cycle (attribution)

A prayer belongs to the date its **window opened**. The day a tracker
row represents is the cycle Fajr → next Fajr, keyed by the Gregorian
date of its Fajr.

```swift
// IhsanCore/Time/PrayerCycle.swift
public struct PrayerCycle: Sendable, Hashable {
    /// Start of the Gregorian day this cycle's Fajr opened on. The key.
    public let date: Date
    /// The next Fajr — the instant the tracker rolls.
    public let rollsAt: Date
}

public enum PrayerCycleClock {
    public static func cycle(
        at instant: Date, civilDayFajr: Date, nextDayFajr: Date, calendar: Calendar
    ) -> PrayerCycle
}
```

The rule is one line: *before the civil day's Fajr, the cycle is
yesterday's.* `IhsanPrayerTimes` adapts a bracketed
`PrayerScheduleWindow` into a cycle; `IhsanCore` holds the arithmetic
so it is testable without a schedule and without coordinates.

`PrayerScheduleWindow` grows from `yesterdayIsha: PrayerTime` to
`yesterday: DayPrayerTimes` (the builder already computes the whole
table and discards it). `yesterdayIsha` survives as a computed
property, so no call site changes. This is what lets a pre-Fajr log of
*any* prayer resolve against the correct — yesterday's — window.

Routed consumers: `PrayerLogService` (prayerDate **and** scheduledTime),
Today's day anchor and its four `@Query` predicates, `YesterdayAccount`,
`TrajectoryPeriod.window` and the aggregator, `TimingAvailability`,
the nafl/dhikr/adhkar intents, the widget snapshot, the watch.

### Clock 2 — the Hijri day (display + calendar-anchored worship)

The Hijri date flips at **Maghrib**, everywhere it is shown, still
honoring the moonsighting offset.

`HijriConverter.components(for:offsetDays:maghribOfCivilDay:timeZone:)`
shifts the tabulation anchor forward one civil day when the instant is
at or past that day's Maghrib. The existing 3-argument signature stays
and consults a process-wide published boundary table:

```swift
// IhsanCore/Hijri/HijriDisplay.swift
public struct EveningBoundary: Sendable, Equatable {
    public let civilDayStart: Date
    public let maghrib: Date
}
public static func publish(eveningBoundaries: [EveningBoundary], timeZone: TimeZone)
public static func maghrib(forCivilDayOf date: Date) -> Date?
```

Data, not a closure: the app republishes two or three days whenever the
day resolves; widget processes publish from the snapshot. An unknown
day yields `nil` and tabulates civilly — which is exactly right for a
historical date passed as a day *start*, because a day start is never
past its own Maghrib.

**Consequences implemented:**

- Voluntary fast offers (Mon/Thu, white days, ʿArafah, ʿĀshūrāʾ) surface
  from the **prior Maghrib** — the evening the niyyah belongs to —
  worded for the coming fast (`TOMORROW'S FAST · THURSDAY` before Fajr;
  the existing day-of wording after).
- `FastLog.fastDate` keys on the **civil date of the daytime fasted**.
  An intention recorded Wednesday 21:10 attaches to Thursday. No
  existing row moves; only the offer/commit path attaches forward.
- Ramadan's nightly context belongs to the Hijri day that began at that
  Maghrib.

### Migration

The reattribution needs each stored day's Fajr. Fajr needs coordinates,
and coordinates are never persisted (privacy invariant #1). **A
SwiftData migration stage therefore cannot recompute windows**, and any
stage that pretended to would be guessing.

So the schema bump and the data repair are separate, and both are
tested:

1. **Schema V8** (lightweight). V7 is frozen into nested snapshots
   first — stores on disk already claim version 7, exactly as V6 was
   frozen before it. V8 adds one defaulted optional field,
   `PrayerLog.reviewFlagRaw`, so a collision can be surfaced rather
   than resolved silently.
2. **`CycleReattributionSweep`** — one-shot, gated by
   `UserSettings.cycleReattributionVersion`, run on launch once a
   schedule is available. It takes a `(Date) -> Date?` Fajr lookup from
   the caller, so `IhsanCore` never learns what a coordinate is.

Rules:

- An Isha log whose `loggedAt` falls between clock midnight and that
  stored date's Fajr moves to the previous cycle, and its timing status
  is **recomputed against the correct window** — a 1 AM in-window Isha
  wrongly stored as qada or missed becomes on time.
- Post-midnight qiyam/witr `NaflLog`s and post-midnight `DhikrSession`s
  follow the same rule.
- Collision (the previous cycle already holds an Isha): keep the
  earlier **performed** entry, flag the duplicate
  `reviewFlagRaw = "cycleDuplicate"`, delete nothing. Path surfaces it.
- Every move, recomputation, and collision is counted in a
  `CycleReattributionReport` the seeded-store test prints.

---

## Phase 2 — the voluntary rows

### Geometry

One left gutter, shared by every row in the pattern — the five prayer
rows and the two presence rows. The gutter is where a row label goes;
the prayer rows leave theirs empty, which is what "aligned with the
prayer rows' implicit label position" means. Because all seven rows are
laid out from the same `GestaltLayout` — same available width, same
pitch, same count — a mark cannot render off-grid by construction, and
`GestaltLayoutTests` asserts the column centers are identical row to
row for every period.

The presence rows keep the marks at the fardh dot size but take their
own row height, so an 11 pt label has vertical room at 90D where the
dots are 3 pt apart. Height changes; x never does.

### Marks

- **Nafl** — the four-pointed star, **filled** metal. Filled at every
  size now, not stroked above 8 pt: a hairline star was the reason the
  row read as debris.
- **Dhikr** — the small round bead, filled. (Kept a bead rather than an
  outlined ring: an outline ring is what an *unlogged fardh* cell
  draws, so an outlined dhikr mark says "nothing happened here" in the
  one row where it means the opposite.)
- Absence draws nothing. Presence rows have no empty state.

### Labels

`NAFL` / `DHIKR`, `IhsanFont.inscription`, tracking 1.3,
`inkSecondary`, right-aligned in the gutter. They replace the key row
underneath, which existed only because the rows had no names.

### Auto-show

Unchanged and now load-bearing for the gutter too: a row appears only
when its data exists in the selected period. Both absent → no rows, no
labels, no gutter, pristine card.

### Detail lives in the table

Tapping a day row in Daily Practice expands it **in place**: that
cycle's nafl breakdown as small ornament-state chips (rawatib per fard,
duha, qiyam, witr) and its dhikr sittings as label + count. Facts only
— no percentages, no totals across days. VoiceOver voices "Nafl
recorded" on the row and the full breakdown in the expansion.

Excused-pause days stay neutral and excluded, exactly as the fard rows
treat them.

---

## Out of scope

Device-only verification (arm's-length glance, VoiceOver pronunciation,
Reduce Motion timing) is appended to `POLISH_FINDINGS.md`, not asserted
here.
