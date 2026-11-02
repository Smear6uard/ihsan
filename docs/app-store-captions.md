# App Store screenshots

Six frames, in `docs/app-store/`, captured by
`ihsanUITests/AppStoreShotsUITests` from the real app on real data at a
real moment of a real day — 30 July 2026 in Chicago, with a month of
logged days behind it. Regenerate with:

```bash
xcrun simctl location <udid> set 41.8781,-87.6298
xcodebuild test -project ihsan.xcodeproj -scheme ihsan \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
    -only-testing:ihsanUITests/AppStoreShotsUITests
```

Nothing is composited, retouched, or staged in a design tool. If a
frame looks wrong, the app looks wrong.

The harness launches with `-IhsanDebugShippingGates`, so a frame shows
only what a release build shows. With the adhkār gate open, that
includes the Remembrance band and its morning and evening offers. If
the gate is ever closed again, the band reads "Tasbīḥ" with no offers,
and frames captured without the flag would picture a layer the binary
does not have.

## Captions

App Store Connect has no caption field: a screenshot is uploaded as
an image and nothing else. These lines either get set into the frames
before upload, or they stay here as the brief for the promotional
text and description. Each is one line, factual, in the app's own
register. No exclamation, no imperative, no promise.

| Frame | Caption |
| --- | --- |
| `store-1-night-plate` | The day as a single instrument. Five prayers on one arc. |
| `store-2-dawn` | The page follows the sun, from first light to the last third of the night. |
| `store-3-logging` | One tap records a prayer in its window. One more takes it back. |
| `store-4-repair` | A ledger for what you carry, and a pace you set yourself. |
| `store-5-qibla` | The direction, drawn rather than pointed at. |
| `store-6-path` | A month of prayer as a pattern of days. No streaks, no score. |

## Required sizes

The 6.9" set (1320 × 2868) is the only mandatory one; App Store Connect
scales it down for the smaller families. The frames here are captured
on iPhone 17 Pro Max at that size. Pin a clean status bar on the
simulator before running the test, or the frames carry whatever time
and signal the simulator happens to show:

```bash
xcrun simctl status_bar <udid> override --time 9:41 --dataNetwork wifi --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
```

An iPad set is not required: the app ships iPhone-only.

## What is deliberately not shown

- No numbers presented as a score, because the app keeps none.
- No empty state dressed up as a feature.
- No person, no hands, no mosque photography. The app is drawn, and
  the screenshots are the app.
