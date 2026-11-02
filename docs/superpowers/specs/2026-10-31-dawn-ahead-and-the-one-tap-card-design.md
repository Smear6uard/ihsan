# The dawn ahead, and the one-tap card

Date: 2026-10-31

Two launch blockers from the maintainer, repaired together because both
are about what the Today screen says at a glance:

1. After Isha the plate still prints the Fajr that opened the day.
2. Recording a prayer takes a tap to open the card, a tap to commit, a
   hidden swipe to a sheet for anything else, and three more taps there.

No schema change. No migration. `IhsanSchemaV11` is untouched.

---

## 1 · The record stays on the cycle; the times look ahead

**Finding.** At 10 PM on 31 October in Chicago the header read
`NEXT: FAJR 5:05 AM` and the plate's Fajr marker read `6:04 AM`. The
plate was showing that morning's Fajr. Daylight saving ends overnight,
so the two figures were an hour apart; on any other night they differ
by a minute, which is the harder failure to notice.

**Root cause.** `5bb337a` ("Fix pre-Fajr worship cycle") moved every
Today surface onto the Fajr → Fajr cycle, which was right for the
record, and in doing so deleted Corrective G's rule that Fajr's
*displayed* instance rolls to the next Fajr once Isha opens. The
`CelestialPlateScene.Marker` comment still promises that rule. Widgets
and the watch caption show the same stale Fajr, because each surface
picked its own Fajr instead of asking one rule.

**Decision.** Two separate questions, two separate answers:

- *Which day does a log belong to?* The cycle, unchanged. An Isha
  prayed at 1 AM belongs to the evening it opened in.
- *Which Fajr does a glanceable surface print?* From the instant the
  cycle's Isha opens, the Fajr that closes the cycle — the dawn the
  night is heading toward. Sunrise rolls with it, so the morning pair
  stays coherent.

The rule lives once, in `PrayerCycleClock.namesClosingFajr`, and once
as data, in `PrayerScheduleWindow.displayedPrayerTime(of:at:)` /
`displayedSunrise(at:)`. The plate, the card, the header, the widgets
and the watch all read it. The rolled Fajr is `upcoming` by
definition: this morning's log never attaches to it.

Because the closing Fajr of one cycle *is* the opening Fajr of the
next, the marker's instance does not change at Fajr at all. The only
moment it moves is Isha's opening, which is the moment `NEXT` becomes
Fajr — so the header and the plate agree by construction.

**Alternatives rejected.**

- *Civil midnight* (what most prayer apps do): files a 1 AM Isha under
  a day whose Isha has not been called, and still prints the stale
  Fajr from Isha until midnight.
- *Roll at Maghrib*: changes Fajr while Isha is still the next prayer,
  buying nothing, and drops the morning's record from the plate an
  hour earlier.
- *Keep the cycle for display too* (the current state): the header and
  the plate disagree for the whole night.

**Cost, accepted.** After Isha, this morning's Fajr is no longer on the
plate. If it went unlogged, the next morning's Yesterday line names it,
and Path holds it.

### Widgets

The snapshot's tables now follow the cycle as well as its logs. A
snapshot published before dawn used to carry the civil day's tables
beside the *previous* cycle's logs, which hung last night's statuses on
today's slots and gave the night widget the coming night instead of
the one in progress. The strip applies the same Fajr roll, and both
arc faces now inscribe sunrise with its time, as the plate does.

---

## 2 · The card is the commit

**Finding.** The resting card was a door, not a control: tap to
expand, choose, and jamāʿah had to be set *before* the commit. The
expanded card held a grabber, a close mark, two commits, a chip, a
disclosure and a link, and folded itself away after 12 seconds. A
swipe up opened a separate sheet (four tiles, a switch, a commit bar),
so the "drawer" did not grow — it summoned something else.

**Decision.** Every recording happens on the card, in one tap, and
every recording can be taken back in one tap.

- **Open window, unlogged** — two seals sit on the card itself: On
  time (gilded, the default) and Delayed. One tap records.
- **Closed window, unlogged** (a marker tap, or a widget link) — four
  seals, each drawn as the ornament state it would produce: gilded,
  warm outline, lapis, quiet. One tap records.
- **Logged** — the summary, a jamāʿah chip that applies immediately,
  and for six seconds an Undo. Tapping the card opens *change* in
  place: the same seals with the current one marked, and Remove.
- **Upcoming** — unchanged: the time, and when it opens.
- A long press offers Change, Remove, and Begin a pause. The pause
  used to live only in the sheet's footer.
- No grabber, no swipe, no auto-collapse. A marker tap holds focus
  while the card is being used and returns to the moment ten seconds
  after the last touch.

Removal needed a funnel member: `RemovePrayerLogIntent`, beside the
other logging intents, so dedup, the widget mirror and the Live
Activity hook stay single-path. Undo restores the exact prior state
through the same intents.

The log sheet stays — Path's retroactive ledger still uses it — but
Today no longer opens it. Its jamāʿah switch moves to
`IhsanSwitchToggleStyle`; the system switch drew white on white by day.

---

## Device checks owed

Appended to `POLISH_FINDINGS.md`: the seal row at the largest Dynamic
Type size, the 6-second Undo with VoiceOver, the rolled Fajr and
sunrise on a real lock screen on the night daylight saving ends.
