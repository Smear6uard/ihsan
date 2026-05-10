# Ramadan Settings Integration Notes

When `feat/settings` is merged, add a Display setting named `Ramadan focus`.

- Store the preference on `UserSettings` as a persisted `Bool`, defaulting to `true`.
- Render it in `ihsan/Settings/Sections/DisplaySection.swift` with the existing Display row/toggle style.
- Use copy in this shape: title `Ramadan focus`, description `Show suhoor and iftar context automatically during Ramadan.`
- Thread the setting into `TodayViewModel` so `SuhoorIftarBanner` and the Maghrib `Iftar` framing render only when both Ramadan is detected and Ramadan focus is enabled.
- Keep automatic Hijri month detection in `RamadanContext`; the setting should suppress UI focus, not override the calendar.
