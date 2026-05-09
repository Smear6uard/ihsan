# IhsanPrayerTimes

`IhsanPrayerTimes` is a thin wrapper around [Adhan-Swift](https://github.com/batoulapps/adhan-swift) that exposes prayer-time calculation using Ihsan domain types from `IhsanCore`.

The package is pure calculation. It does not cache results, schedule notifications, access location services, or include UI.

```swift
let provider = AdhanPrayerTimesProvider()
let times = try provider.dayTimes(
    for: .now,
    coordinates: Coordinates(latitude: 41.8781, longitude: -87.6298),
    timeZone: .current,
    calculationMethod: .isna,
    madhab: .standard,
    highLatitudeRule: .middleOfNight
)
print(times.fajr.scheduledTime)
```

All returned `Date` values are absolute UTC instants. Format them in the app, widget, or watch layer using the user's desired timezone.

`nextPrayer(from:...)` handles the post-Isha rollover by returning the following day's Fajr when today's Isha has already passed.

For high-latitude users above 48 degrees latitude, set `highLatitudeRule` explicitly. `.middleOfNight` matches the Moonsighting Committee's default recommendation for this app.
