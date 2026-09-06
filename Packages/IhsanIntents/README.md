# IhsanIntents

IhsanIntents is the App Intents layer for Ihsan. It exposes prayer actions to widgets, Apple Watch, Siri, Shortcuts, Spotlight, and future interactive surfaces.

All prayer-logging paths should go through these intents. The Today screen, widgets, watch app, Siri, and Shortcuts share the same `LogPrayerIntent`, `LogPrayerWithStatusIntent`, `ToggleJamaahIntent`, and `MarkAsQadaIntent` behavior so logging stays idempotent and consistent.

Import the package to use its intents in the consuming app target:

```swift
import IhsanIntents
```

Register shortcut phrases with an app-target `AppShortcutsProvider`; importing the package alone does not register them. The provider (`IhsanAppShortcuts`) lives in the app target at `ihsan/App/IhsanAppShortcuts.swift`, not here: App Shortcut phrases are extracted from the app's own binary at build time, and a provider declared in this package produced a metadata file with no phrases. The intents it names are all defined in this package.

## Coordinates Placeholder

The v1 service accepts optional `Coordinates`, but when none are provided it stores `Date.now` as `scheduledTime`. Before shipping, the application-layer coordinator that owns CoreLocation should pass real coordinates so `PrayerLogService` can compute and persist actual scheduled prayer times through `IhsanPrayerTimes`.
