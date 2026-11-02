# Path, made legible

Date: 2026-11-01

A review of Path with a month of real-looking data found five faults:

1. The data came third, under two offer cards.
2. The pattern could not be read: no prayer names, no key.
3. The same data appeared twice. The top grid could not be touched. The
   bottom one, 30 rows long, led to a pick-a-tile-then-commit sheet.
4. The numbers confused. `Missed: 0` sat beside 16 blank marks, and
   "132 recorded" sat one line above "129 of 145 slots".
5. One screen had five names, plus "slots", "carry a record" and "hold
   their time".

No schema change.

---

## One grid, one key, one day

```
Path                                 share
Jul 1 – Jul 30, 2026
7 days   30 days   90 days   Year

Fajr     ● ● ● ○ ● ● ● ●  ▐●▌
Dhuhr    ● ● ● ● ● ○ ● ●  ▐●▌     the pattern; tap or drag
Asr      ● ● ● ● ● ● ● ●  ▐●▌
Maghrib  ● ○ ● ● ● ● ● ●  ▐·▌
Isha     ● ● ● ● ● ● ● ●  ▐·▌
         Jul 1   Tap a day  Today

132 of 138 prayers recorded
● On time    121    ◉ In jamāʿah   0   the key is also the count
○ Delayed     11    ◍ Qadā         0
◌ Missed       0    ∘ No record    6

‹      Thursday, Jul 30       ›
● Fajr              On time  ⌄        tap: the Today card's seals
● Dhuhr             Delayed  Undo     one tap records; Undo for 6 s
· Isha     Not recorded yet  ⌄

What stands out                        one reading, one action
[at most one offer]                    below the data, one at a time
[Khatam] [Repair]
```

**The key is the count.** Each number sits beside the mark it counts, so
one element answers "what does this mean?" and "how many?".

**One basis for every number** (`PathTally`). A blank counts as a gap
unless it is today's or predates the person's first record. Those draw as
a small pip, not a ring. `PathTally.isCounted` is the one rule behind both
the mark and the number, so:

    onTime + delayed + qada + missed == recorded
    recorded + noRecord              == counted

`inJamaah` is outside the sum: it says how some of those prayers were
offered. Linked make-ups draw no mark on their own day, so the readout
says them in words rather than folding them into a count the marks cannot
account for.

**One grid.** Tap a column or drag across it, and the day card follows.
The pan declines to begin unless the finger starts sideways, so a vertical
swipe still scrolls the page. Arrows on the day card are the exact way to
a day at 90 days and through a year's week. VoiceOver gets one adjustable
element instead of 150 buttons.

**Long periods draw ticks.** At 90 days and a year a column is 3–5 points
wide, too narrow for a hollow ring. Colour keeps its meaning and height
adds one: full for on time or qadā, shorter for delayed, a stub where
nothing was prayed. A steady prayer reads as an unbroken band. The key
switches to ticks with it.

**The sheet is gone.** Path was `PrayerLogSheet`'s last caller. Its colour
recipes moved to `TimingSealGlyph`, and their audit became
`TimingSealContrastTests`.

**One name.** Path. Sections say what they are: "What stands out",
"Context and sources". The finding's copy no longer says slots, ledger or
weak point, and `PathVocabularyTests` keeps those words out.

**Offers come after the data, one at a time:** Ramadan first, then Repair,
then the sunnah invitation.

## Copy under review

The `unrecordedSlots` grounding dropped "slot" (title: "No record is not a
missed prayer"). Its meaning and citation are unchanged, and
`PATH_FIQH_REVIEW.md` carries the new wording to the scholar. The ledger
glossary is now titled "How Ihsan records timing". A remote config served
before the public JSON is updated will still show the old title.

---

## Live Activities, one prayer at a time

Settings has its own Live Activities section: a switch for all prayers and
one for each prayer. The per-prayer choices are device-local, stored
beside the master switch.

A prayer's countdown no longer follows that prayer's notification. Before,
turning off Asr's notification silently took its countdown too.

The master "Prayer notifications" switch still governs both. With it off,
the section says "Needs prayer notifications" and no activity runs.
Showing a countdown with notifications off would be new behaviour for
everyone who had turned them off, and the request was for a way to turn
activities off.

Changing a switch calls `applyLiveActivityPreferences()`, which withdraws
first. A rebuild only stages, so a start already parked for a prayer just
switched off would otherwise still fire.
