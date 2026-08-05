# Corrective J — four repairs

Date: 2026-08-04

Four maintainer findings from a device pass, repaired together because
three of them are the same failure: **a control that does not say what
it does.**

No new palette, no new typefaces. The manuscript system (leaf gold,
lapis, warm metal, inscription small-caps, ornament glyphs,
`celestialPanel`) is the brief. The one deliberate risk is
**subtraction** — two controls are deleted outright and replaced by
derived state.

No schema change. No migration. `IhsanSchemaV7` is untouched.

---

## 1 · Path — delete the chips, label the rows

**Finding.** The `NAFL` and `DHIKR` chips above the gestalt panel toggle
a presence row so quiet that, with no nafl or dhikr data recorded, the
control has *no visible effect at all*. A switch whose effect is
invisible is worse than no switch.

**Repair.**

- Both chips are deleted from `TrajectoryScreen`, along with
  `naflOverlayToggle` and `dhikrOverlayToggle`.
- `GestaltGrid` gains a **key row** beneath the pattern, drawn only when
  a presence row is: each row's own mark at legible size (11pt) beside
  its name, `✦ NAFL` and `● DHIKR`. The marks are the same units the
  rows draw, so the key can never describe something the grid does not
  show.
- **Presence rows render when they have data.** `TrajectoryScreen`
  passes `naflDays` whenever `sunnahLayerEnabled` is true and
  `dhikrDays` always. `GestaltGrid` draws each overlay row only if at
  least one of its columns is present. Empty data → no row → nothing to
  be confused by.
- `gridHeight` accounts for the conditional rows via the same
  presence test, so the panel never reserves space for a row it will
  not draw.
- The grid's accessibility label names the presence rows when they are
  drawn.

**Vestigial settings.** `UserSettings.pathNaflOverlayEnabled` and
`.pathDhikrOverlayEnabled` remain in the schema — removing them would
force a migration for no gain — but nothing reads or writes them. Both
are marked deprecated in a doc comment.

### Why not a per-row legend gutter

The design started as a left gutter naming all seven rows, and it does
not survive the densities. At 30D the row pitch is 10pt and at 90D it is
4pt; an inscription label is about 11pt tall. Labels at those pitches
overlap each other, and a gutter that works only at 7D is worse than
none. The naming moved underneath, where it has room at every period.

The five fardh rows keep no labels. They were not what anyone
misread — the complaint was about the two quiet rows nobody could name
— and the ornament column headers on the `DailyPracticeGrid` directly
below already teach the prayer order.

### Presence logic placement

The per-column presence computation moves into `GestaltAggregation`
(already a tested pure helper) as `presenceColumns(days:period:
daysWithRecord:)`, so the "is there anything to draw" question is
answerable in a test without a view.

---

## 2 · `Late` → `Delayed`

**Finding.** The log sheet captions `Late` as "PRAYED AFTER ITS WINDOW"
and `Qadā` as "MADE UP LATER". Those describe the same thing. Under
Hanafi fiqh the distinction that matters is *inside* the window versus
*after* it.

**Repair.** A new single source of truth in
`IhsanCore/Vocabulary/PrayerStatusVocabulary.swift`, alongside
`IhsanVocabulary`, so the word can never drift between surfaces again:

| status | `displayName` | `inscription` | `caption` | `spokenLabel` |
|---|---|---|---|---|
| `.onTime` | On Time | ON TIME | PRAYED IN ITS WINDOW | on time |
| `.late` | **Delayed** | DELAYED | PRAYED **LATE** IN ITS WINDOW | delayed |
| `.qada` | Qadā | QADĀ | **PRAYED AFTER ITS WINDOW** | qadā |
| `.missed` | Missed | MISSED | ITS WINDOW PASSED UNPRAYED | missed |

On Time and Delayed are both *in-window*; the single word `LATE`
carries the entire distinction. Qadā takes over the "after its window"
caption that Delayed was wrongly wearing. The captions are parallel by
construction — four phrases about one window.

**The enum case and its raw value stay `late`.** The persisted string,
the CloudKit records, the widget snapshot payloads, and every existing
row are untouched. Only display copy changes.

### Call sites

`PrayerLogSheet`, `FocusedPrayerCard`, `YesterdaySheet`,
`QuietSummaryRow`, `DailyPracticeGrid`, `GestaltGrid` (doc comment),
watch `PrayerActionSheet` / `TodayView` / `PrayerDots`, watch
complications, `PrayerStatusEntity` (Siri vocabulary),
`LogPrayerWithStatusIntent` (spoken dialog), `InsightPromptBuilder`
(the on-device model's prompt should use the word the UI uses).

`PrayerLog.lateBySeconds` keeps its stored name — it now means
"seconds into the window" and gains a doc comment saying so.

`spokenLabel` returns the bare word with no connective. An earlier draft
had qadā as "as qadā", which read correctly in the card's VoiceOver
label and turned every complication count into "1 as qadā". Callers
supply their own grammar.

### The availability rule changes with the semantics

`TimingAvailability` currently allows only `[.onTime]` while a window is
open, because "Late" meant "after the window" and could not yet be
true. Under the repaired semantics a prayer performed *now*, late in
its window, **is** Delayed. So:

| window state | before | after |
|---|---|---|
| `.upcoming` | `[]` | `[]` |
| `.current` | `[.onTime]` | **`[.onTime, .late]`** |
| `.closed` | all four | all four |
| past day | all four | all four |

This also repairs a live inconsistency: the focused card offers a Late
commit while the window is open, and the sheet disables the matching
tile. Both now agree.

### `QuietSummaryRow`

`LATE` → `DELAYED`, and `QuietRowLayout` gains balanced row splitting:
five stats break 3 + 2 instead of greedily filling row one and
stranding `QADĀ: 0` alone on row two. The row count is still found
greedily (the minimum that fits); items are then distributed as evenly
as that row count allows.

---

## 3 · The expanded log card, rebuilt

**Finding.** The expanded state crams a header, a centered floating
pill, two full-width buttons, and a two-control footer into a fixed
140pt at 7pt spacing. It reads as crowded, and the jamāʿah pill's
on/off state is genuinely ambiguous.

**Repair.** Collapsed stays 140pt. Expanded animates to **176pt** on an
explicit, user-initiated tap — deliberate growth, not the layout jitter
the fixed height was guarding against. (First built at 186 and measured
on the simulator: it left a visible void above the lone trailing MORE
link. Answering "crowded" with a card of slack only moves the problem.)

```
┌─────────── ━━━━ ────────────────────────┐  ← grabber
│ ✦  Isha العشاء                      ✕   │
│    NOW · UNTIL 4:19 AM                  │
│                                         │
│  ┌────────────────┐ ┌────────────────┐  │
│  │    ON TIME     │ │    DELAYED     │  │
│  └────────────────┘ └────────────────┘  │
│                                         │
│  ◇ IN JAMĀʿAH                           │
│  RAWATIB ⌄                     MORE ⌄   │
└─────────────────────────────────────────┘
              ↑ swipe up → full sheet
              ↓ swipe down → collapse
```

- **The window inscription returns to the expanded state.** It is
  exactly the information that makes On Time vs Delayed a real choice,
  and it was absent.
- **`TimingCommitButton` primary rests filled** — leafGold fill with
  keyline text, which is the log sheet's own commit-bar recipe, so the
  two surfaces speak one language. Today both buttons rest as identical
  outlined capsules and the `prominent` flag is invisible until press.
  Secondary rests as a plain metal outline and keeps its fill-on-press.
- **Jamāʿah stops being a centered floating pill.** It becomes a
  left-aligned chip on the app's own marker vocabulary: hollow ornament
  → gilded ornament, with the label beside it. Same idiom as the nafl
  chips, so state is unmistakable.
- `RAWATIB` and `MORE` share the footer. Revealed rawatib chips replace
  `RAWATIB ⌄` in place, at the same height, so nothing reflows.

### Swipe

Today is a non-scrolling `ZStack` (`TodayScreen.swift:343`) with no
existing gestures on the card, so the vertical axis at the card is
free.

- **Grabber pill** centred at the top of the expanded card — the
  visible signifier. A gesture with no signifier is a secret.
- **Swipe up** past a ~40pt threshold presents the full log sheet.
- **Swipe down** past the same threshold collapses the card. The `✕`
  stays for anyone who does not find the gesture.
- While dragging, the card takes a small offset and fade tracking the
  finger, so the transition reads as continuous.

**Honest mechanics.** SwiftUI cannot interactively drag a *modal* sheet
into view. The gesture is threshold-based: the card tracks the finger,
and past the threshold the sheet presents with its normal animation.
This is not one literally continuous drag, and building a custom
non-modal overlay to make it so is out of scope.

- The 12s auto-collapse timer resets on drag, so a slow gesture is
  never interrupted.
- Reduce Motion: the gesture still works; the tracking offset and fade
  are suppressed.
- VoiceOver / Switch Control cannot swipe, which is why the visible
  `MORE ⌄` link stays. The card additionally carries custom
  accessibility actions for "More options" and "Collapse".

---

## 4 · A door to remembrance that is always open

**Finding.** Adhkār is reachable only from the timed `AdhkarQuietCard`
during a morning / evening / sleep window, or from the post-prayer
dialog on a logged card. There is no way to open a set outside its
window, and free tasbīḥ is behind the same dialog.

**Repair.** `RemembranceBand` — a slim, always-present panel under the
focused card, in `AdhkarQuietCard`'s shape because it is the same kind
of thing. It opens `RemembranceSheet`:

```
Morning adhkār          5:12 – 7:40 AM
Evening adhkār          4:55 – 8:31 PM
After prayer
Before sleep
────────────────────────────────────────
Free tasbīḥ
```

- **The hub lists all four sets regardless of the per-window
  toggles.** Those toggles govern the *automatic offer cards*, not
  manual access. This is the answer to "general adhkār outside any
  window."
- Windows are inscribed beside the sets that have one today, so the hub
  still teaches when each set belongs, without gating access on it.
- The band sits **outside the pause branch**, for the reason
  `AdhkarOffer.pauseSuppresses` is written down: a pause suspends salah
  and fasting, never remembrance.
- The timed `AdhkarQuietCard` is unchanged and still appears above the
  band when a window is live. Different jobs — the card says "this
  window is open", the band says "any set, any time".
- **The scholar-review gate holds.** When `AdhkarAvailability
  .isAvailable` is false the band reads `Tasbīḥ` and opens the
  instrument directly, with no sheet — a hub of one row is not a hub.

### Composition logic

A `RemembranceMenu` pure helper decides the rows, in the shape of
`AdhkarOffer`: given content availability and today's resolved windows,
it returns the ordered entries. Screens do not compose menus in `if`
statements.

### Presentation

The hub is a `.sheet`; the set reader is a `.fullScreenCover`. A row
tap records a pending destination and dismisses; the hub's `onDismiss`
closure applies it. Presenting a cover from inside a dismissing sheet
is otherwise a race.

Scope: iOS only. The watch keeps its current entry points.

---

## Testing

New:

- `PrayerStatusVocabularyTests` (IhsanCore, Swift Testing) — pins all
  four labels, captions, and spoken forms, and asserts the captions are
  mutually distinct, which is the bug that started this.
- `RemembranceMenuTests` (ihsanTests) — row composition with content
  available and unavailable, with and without resolved windows.
- `GestaltAggregationTests` additions — presence columns, including the
  all-absent case that must draw no row.
- `QuietRowLayout` balanced-split coverage.

Updated:

- `TimingAvailabilityTests` — the in-window set is now
  `[.onTime, .late]`.
- `PrayerStateResolverIntegrationTests` — same rule.
- Any copy test or UI test pinning the string `Late`.

## Verification

- `xcodebuild` the iOS app and both extensions.
- `swift test` on `IhsanCore`, plus every package whose sources change.
- `ihsanTests` on a simulator.
- Simulator screenshots of all three changed surfaces.
- `ihsanUITests` failures are baselined against `b0f2c99` before any is
  attributed to this diff — nine fail on main already.

## Out of scope

Device-only judgments — animation timing at 120Hz, the swipe threshold
in the hand, VoiceOver pronunciation of "Delayed", Dynamic Type at
accessibility sizes on the new legend gutter — are appended to
`POLISH_FINDINGS.md` rather than asserted.


## What changed during implementation

Two things moved after the design was approved, both after seeing the
result on a simulator:

1. **The Path legend became a key row, not a gutter.** Per-row labels
   cannot fit at 30D/90D pitches. Recorded above.
2. **The expanded card is 176pt, not 186.** Measured, then tightened.

`Prayer.inscriptionAbbreviation` was added for the gutter and is now
unused by any view. It is kept because it is the right primitive if a
row legend is ever wanted at 7D, and it costs one switch statement.

## Verification performed

- `xcodebuild build` on the `ihsan` scheme: succeeded.
- `swift test` on IhsanCore (182), IhsanIntents (38), IhsanInsights
  (12), IhsanFiqhConfig (19): all passed.
- `ihsanTests`: 207 tests in 34 suites passed, including the three new
  suites.
- `ihsanUITests`: `FocusedCardSwipeUITests` (4) and
  `RemembranceDoorUITests` (3) written for this change, all passing —
  the swipe and the hub's dismissal handoff are only provable live.
- Simulator captures of Today, the expanded card, the log sheet, Path,
  and the hub, reviewed against the four findings.
