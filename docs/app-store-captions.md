# App Store screenshots

Six frames, in `docs/app-store/`, captured by
`ihsanUITests/AppStoreShotsUITests` from the real app on real data at a
real moment of a real day — 30 July 2026 in Chicago, with a month of
logged days behind it. Regenerate with:

```bash
xcrun simctl location <udid> set 41.8781,-87.6298
xcodebuild test -project ihsan.xcodeproj -scheme ihsan \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:ihsanUITests/AppStoreShotsUITests
```

Nothing is composited, retouched, or staged in a design tool. If a
frame looks wrong, the app looks wrong.

## Captions

Set these in App Store Connect rather than burning them into the
images — burnt-in text does not localise and does not scale. Each is
one line, factual, in the app's own register. No exclamation, no
imperative, no promise.

| Frame | Caption |
| --- | --- |
| `store-1-night-plate` | The day as a single instrument. Five prayers on one arc. |
| `store-2-dawn` | The page follows the sun, from first light to the last third of the night. |
| `store-3-logging` | Two questions, one tap: when you prayed, and whether you prayed with others. |
| `store-4-repair` | A ledger for what you carry, and a pace you set yourself. |
| `store-5-qibla` | The direction, drawn rather than pointed at. |
| `store-6-standby` | On the nightstand, at the brightness a dark room deserves. |

## Required sizes

The 6.9" set (1320 × 2868) is the only mandatory one; App Store Connect
scales it down for the smaller families. Frames here are captured on
iPhone 17 Pro (1206 × 2622). Before submission, re-run the test against
an iPhone 17 Pro Max destination:

```bash
-destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

An iPad set is not required: the app ships iPhone-only.

## What is deliberately not shown

- No numbers presented as a score, because the app keeps none.
- No empty state dressed up as a feature.
- No person, no hands, no mosque photography. The app is drawn, and
  the screenshots are the app.
