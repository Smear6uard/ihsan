# Widgets v2 — Phase 0 diagnosis

Every defect below was found by reading the shipping widget code at
`9c20f94` and verified where a claim needed proof (the range trap was
reproduced in isolation; the geometry mismatches are arithmetic from
the two definitions; the missing reload triggers are a repo-wide grep).
The baseline `ihsanWidgets` scheme builds clean — none of this is
build breakage; all of it ships.

## Data defects

**D1 — Blank widgets: the countdown range trap.**
`CountdownLabel.Hero/Compact/Tabular` and `NextPrayerRectangularWidgetView`
build `Text(timerInterval: .now...target)`. `ClosedRange` traps when
`target < .now` (verified standalone: SIGTRAP). WidgetKit re-renders
archived entries whenever it wants — most commonly the *last* entry of
a stale timeline, overnight, when the requested reload was deferred
(Low Power Mode, budget exhaustion, device asleep). Rendering the Isha
entry after its target passed kills the render process; the system
shows the empty face. This is the literal "blank widget in the
morning" competitor failure mode, reproduced at the source. *Fix:
countdown intervals start at `entry.date` and clamp
(`entry.date...max(target, entry.date)`); the terminal timeline entry
never carries an expirable countdown.*

**D2 — Widgets disagree with the app: no reload triggers.**
The iOS app never calls `WidgetCenter.shared.reloadAllTimelines()` —
only the watch app has a `WidgetReloader`. Log a prayer in the app,
change calculation method or madhab, start a pause, travel: the
widgets keep rendering the old truth until the next natural reload,
whose policy is `.after(nextDayFajr)` — up to a day away. A madhab
change that moves Asr while the widget shows yesterday's Asr is
exactly the "Pillars bug" this rebuild is designed against. *Fix:
reload from every app-side mutation path; optimistic snapshot update
from the intent funnel.*

**D3 — The day-rollover cliff: the cache holds one day.**
`PrayerTimesCache` carries today's table only. `WidgetSnapshotLoader.isValid`
requires the entry's date to share a civil day with `cache.date`, so
the morning after any day the app wasn't opened, every widget degrades
to "Open Ihsan **to set your location**" — misleading copy (location
is fine; the data is just from yesterday) — even though tomorrow's
Fajr was computed and discarded. *Fix: snapshot carries today +
tomorrow as full resolver tables; staleness gates at 36 h; the copy is
honest.*

**D4 — The widget process opens a second CloudKit-mirrored store.**
`WidgetSnapshotLoader.openSharedContext()` and `RepairSnapshotLoader`
call `IhsanModelContainerFactory.makeContainer()` with the default
`cloudSync: true` — a second process CloudKit-mirroring the same
SQLite file, the exact CoreData 134422 ("another instance actively
syncing") class the house pass fixed *inside* the app, now recreated
across processes. It is also SwiftData spin-up cost and memory against
WidgetKit's ~30 MB budget on every timeline build. *Fix: logged
states, fasting, Hijri, and pause travel in the snapshot; the widget
render process never opens SwiftData. The intent process (widget
buttons) opens the store without mirroring.*

**D5 — Logged states are baked at timeline-build time.**
All entries for the day capture `loggedStatusByPrayerRaw` once, at
build. Combined with D2, a prayer logged at noon stays visually
unlogged on the widget until tomorrow.

**D6 — Log buttons on the wrong prayers with the wrong semantics.**
Medium and large widgets make *every* prayer a
`Button(intent: LogPrayerIntent(prayer:))`, which logs `.onTime`
unconditionally — `PrayerLogService` has no future guard, so tapping
the upcoming Isha ornament at 10 am records Isha as prayed on time.
Tapping a passed-window prayer silently records on-time where the
app's own sheet would ask. Widget logs are also stamped
`sourceSurface: .siri`. *Fix: one interactive button, on the current
prayer, On Time only; every other target deep-links into the app's
sheet; a correct source surface.*

**D7 — Deep links are dead.**
`WidgetDeeplink` produces `ihsan://today` and `ihsan://today?qibla=1`,
but no `onOpenURL` exists anywhere in the app and no URL scheme is
registered in any Info.plist or build setting. `QiblaFlag.markFresh`
is called by nobody. Taps fall through to "open the app" by default,
so the plain link *appears* to work; the qibla destination and any
per-widget routing are impossible. *Fix: register the scheme, route in
the app, one URL per widget destination.*

**D8 — Timezone leaks in fallback entries.**
`missingLocationEntry` stamps `TimeZone.current` (device timezone)
onto an entry in a codebase whose one-Asr lesson was "always the place
timezone." Placeholder schedules are built in device tz as well —
fine for the gallery, wrong as a live fallback.

**D9 — The timeline knows five boundaries and nothing else.**
Entries exist at prayer starts and sunrise only. No solar midnight, no
last-third start, no Hijri rollover, no suhoor/iftar awareness — the
cache carries no fasting, Hijri, or pause data at all, so the night
and fasting surfaces this family specifies are unbuildable on the old
spine.

**D10 — `writtenAt` exists and nothing reads it.**
There is no staleness policy: a two-week-old cache renders exactly
like this morning's, provided the civil day matches (it can — a cache
written at 00:30 serves fake confidence all day after a timezone
move).

## Visual defects

**V1 — Tap targets drift off their ornaments (medium).**
The invisible button overlay re-derives the arc layout with a flat
`inset = 13`; `ArcGeometry` uses `ornamentSize/2 + 6` (= 17 at the
medium's 22 pt ornaments) and a parabola the overlay ignores
(buttons center at `height/2`). In summer crowding, Maghrib and Isha
sit ~8 pt apart while each button is 40 pt wide — the wrong prayer is
one thumb-width away. Root cause: two definitions of one geometry.

**V2 — No tinted/clear-mode design on home widgets.**
Not one home widget declares a `widgetAccentable` hierarchy. In iOS
tinted and clear modes the system flattens the full-color art on its
own terms: gilded-logged vs outline-upcoming collapse toward the same
gray, the sky ground fights the user's tint, state becomes illegible.
Hard Rule 5 requires the hierarchy to be chosen, not inherited.

**V3 — Lock accessories: accent applied without hierarchy.**
The circular widget marks its whole ZStack accentable (ring and
ornament as one undifferentiated accent); the rectangular marks the
title row including the ticking timer, inverting emphasis against the
secondary clock time. The ornament renders at 13 pt in vibrant
material — a ten-point star at 13 pt is a smudge.

**V4 — Naive two-stop gradient grounds.**
`WidgetPalette.homeGround` linear-interpolates two darkened sRGB
stops. The app learned this lesson already (17-sample OKLCH stop
tables + grain, banding measured on row means); widgets got the naive
ramp on the worst surface class for it — small, dark, OLED. The
`darkened(by:)` channel-multiply also hue-shifts the tuned sky colors.

**V5 — StandBy and clear-mode confusion; no night-dim handling.**
Placement is inferred from `!showsWidgetContainerBackground`, which
conflates StandBy, lock-screen accessories, and iOS 18 clear mode —
clear-mode home widgets get nightstand ink. `isLuminanceReduced` is
never read, so StandBy night mode receives full-brightness gold.

**V6 — Ornament collision and edge clipping in `CompactPlate`.**
Marks sit at true time-proportion with no minimum separation: two
22 pt ornaments overlap when Maghrib–Isha compresses below ~2.6 % of
the day span (every northern summer). In the StandBy plate's 34 pt
frame the arc's peak ornament center computes above the frame top —
drawn into the neighboring text or cut by the container margin.

**V7 — Type degradation under pressure.**
`minimumScaleFactor(0.5–0.7)` as the universal answer; "CURRENT
LOCATION" crushes the small widget's header; tracking values tuned for
Latin inscriptions applied to Arabic display names.

**V8 — The sky freezes between boundaries.**
The ground resolves `SkyPhase` at `entry.date`, and entries exist only
at prayer boundaries — the widget wears the 1 pm sky until Asr
(~4 h stale), then jump-cuts. Adjacent entries were never designed as
visually continuous. *Fix: sky keyframe entries between prayer
boundaries; grounds sampled from the same continuous ramp the app
paints.*

**V9 — Score pressure and pause-blindness.**
The circular widget fills five segments as prayers are logged and the
large widget stamps "NOT LOGGED" — quiet scorekeeping on surfaces that
render identically during an excused pause, because no widget knows
pauses exist. Violates the pause invariant this family must honor.

**V10 — Pre-first-launch leakage in the circular widget.**
`PrayerProgressCircularWidgetView` never checks `isLocationMissing`,
so before first launch it renders the placeholder's fabricated logged
segments as if real.

**V11 — Placeholder fake times are one flag away from live.**
The fallback entry embeds a stylized fake schedule; every view must
remember to check `isLocationMissing` before showing times (V10 shows
one already forgot). Fake times never belong in a live entry at all —
the stale state is its own entry kind, not a placeholder wearing a
flag.

## Phase 0 — what landed against each defect

| Defect | Fix | Held by |
|---|---|---|
| D1 blank-widget trap | `WidgetTimerInterval.countdown(from:to:)` clamps every interval; all `Text(timerInterval:)` call sites route through it; the terminal timeline entry is the static invitation | `WidgetSnapshotTests/countdownIntervalNeverInverts` |
| D2 no reload triggers | `WidgetSnapshotService` publishes + `reloadAllTimelines()` from Today refresh, every settings mutation (`modifiedAt` observer), pause transitions; `WidgetSnapshotMirror` reloads from the intent funnel | call sites in `TodayViewModel`, `SettingsScreen`, `TodayScreen`, six intents |
| D3 one-day cliff | `WidgetSnapshot` carries today + tomorrow as full resolver tables (`dayAfterTomorrowFajr` terminal); honest invitation copy | `WidgetSnapshotResolverTests` two-day sweep |
| D4 second CloudKit mirror | widget render path never opens SwiftData (snapshot carries logs/fasting/pause/qadā); `IhsanSharedModelContainer` extension fallback opens `cloudSync: false`; watch app now registers its container | code paths; `RepairTimelineProvider` reads snapshot |
| D5 logs baked at build | intent funnel mirrors logs onto the snapshot (`WidgetSnapshotStore.mirrorLogs`) + reload after every log | `WidgetSnapshotTests/mirrorLogsReplacesTodaysStatesInPlace` |
| D6 wrong-prayer logging | one interactive target: the current prayer, unlogged, not paused; all other rows/ornaments non-interactive until the app's sheet | medium/large view logic |
| D7 dead deep links | unchanged in Phase 0 — scheduled for Phase 3 (routing + scheme registration) | — |
| D8 device-tz fallback | invitation entries carry no times and no timezone at all | entry model shape |
| D9 missing boundaries | composer emits window edges, sunrise, nisf al-layl, last-third, Hijri rollovers, sky keyframes for both days | `WidgetTimelineComposer` |
| D10 no staleness policy | 36-hour rule + coverage rule in `WidgetSnapshot.freshness(at:)`; resolver refuses stale instants | `staleBeyondThirtySixHours`, `staleInstantsResolveNothing` |
| V1 tap-target drift | overlay positions from the same public `ArcGeometry` that draws the ornaments | shared definition |
| V5 (part) StandBy tokens | grounds split; full rendering-mode design lands in Phases 1–2 | — |
| V6 clipping | `ArcGeometry` rise clamps to its frame | `CompactPlateGeometryTests` (was red at −1.28 pt / −1.76 pt) |
| V8 frozen sky | 45-minute sky keyframe entries between boundaries | `WidgetTimelineComposer` |
| V9 pause-blindness | snapshot carries `isPaused`; paused faces show times, no buttons, no status inscriptions, no segments | view logic + gallery `paused` frame |
| V10/V11 fake-time leakage | entry is structurally `.live` or `.invitation`; fake times cannot exist behind a flag | `PrayerTimelineEntry.Content` |

Remaining visual defect classes (V2 tinted/clear accent hierarchy, V3
accessory accent hierarchy + ornament scale, V4 gradient quality, V5
proper placement detection, V6 crowding separation, V7 type pressure)
are the subject of the Phase 1–2 face rebuilds, where each face lands
with its own render pins.

## Timeline policy (Phase 0 state)

Entries: now · every prayer start · sunrise · nisf al-layl ·
last-third start · Hijri rollover (place-tz midnight) · 45-minute sky
keyframes — for both covered days, ending in a static invitation
entry at `min(terminal Fajr, writtenAt + 36 h)`. Policy:
`.after(that instant)`. Reload triggers: every publish
(`WidgetSnapshotService`) and every intent-funnel write
(`WidgetSnapshotMirror`). Countdown text uses
`Text(timerInterval:)` over clamped intervals, so nothing ticks by
timeline spam and nothing can trap.
