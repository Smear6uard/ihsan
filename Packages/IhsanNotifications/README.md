# IhsanNotifications

`IhsanNotifications` schedules adhan notifications for a rolling 14-day window. It is infrastructure-only: no SwiftUI, no assets, and no app target wiring.

## Integration notes

Add this package as a local dependency from the main app after merging. Do not commit `.pbxproj` changes from this package branch.

The main app target must also add the background task identifier below to `BGTaskSchedulerPermittedIdentifiers` in its `Info.plist`:

```text
com.sameerstudios.ihsan.refresh-notifications
```

Register the task during app startup:

```swift
BackgroundRefreshTask.register()
```

The package expects adhan CAF files to be bundled by the main app target:

- `adhan-standard-long.caf`
- `adhan-standard-short.caf`
- `adhan-fajr-long.caf`
- `adhan-fajr-short.caf`

If a selected file is missing at runtime, notification content falls back to `UNNotificationSound.default`.
