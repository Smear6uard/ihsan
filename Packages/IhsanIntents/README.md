# IhsanIntents

IhsanIntents is the App Intents layer for Ihsan. It exposes prayer actions to widgets, Apple Watch, Siri, Shortcuts, Spotlight, and future interactive surfaces.

All prayer-logging paths should go through these intents. The Today screen, widgets, watch app, Siri, and Shortcuts share the same `LogPrayerIntent`, `LogPrayerWithStatusIntent`, `ToggleJamaahIntent`, and `MarkAsQadaIntent` behavior so logging stays idempotent and consistent.

To wire shortcuts into the consuming app target, import the package from the `@main` app file:

```swift
import IhsanIntents
```

`IhsanAppShortcuts` conforms to `AppShortcutsProvider`; once the framework is loaded by the app target, the system can register its curated shortcuts.

## Coordinates Placeholder

The v1 service accepts optional `Coordinates`, but when none are provided it stores `Date.now` as `scheduledTime`. Before shipping, the application-layer coordinator that owns CoreLocation should pass real coordinates so `PrayerLogService` can compute and persist actual scheduled prayer times through `IhsanPrayerTimes`.
