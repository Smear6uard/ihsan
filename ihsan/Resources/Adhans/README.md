# Adhan Audio Assets

These audio files are bundled into the main app and used by IhsanNotifications when scheduling adhan notifications.

## Required files

- adhan-standard-long.caf — ~30 seconds, standard adhan (used for Dhuhr, Asr, Maghrib, Isha). Hits Apple's notification sound limit.
- adhan-standard-short.caf — ~10 seconds, opening takbirat only. Used when user prefers shorter notifications.
- adhan-fajr-long.caf — ~30 seconds, Fajr-specific adhan including the additional "as-salatu khayrun min an-nawm" line.
- adhan-fajr-short.caf — ~10 seconds, Fajr opening takbirat.

## Format requirements

- Apple .caf format (Core Audio Format)
- Maximum 30 seconds (Apple's notification sound hard limit)
- Sample rate: 44.1 kHz, 16-bit
- Single channel (mono) acceptable; stereo also fine

## Sourcing

Audio files must be CC-licensed or explicitly licensed for App Store distribution. Mishary Rashid Alafasy's adhan recordings are widely available under CC (verify license per source before use). Alternative sources: Saud Al-Shuraim, Abdul Rahman Al-Sudais (license verification required).

Conversion from MP3/WAV to .caf:
`afconvert input.mp3 -d ima4 -f caff output.caf`

## License documentation

Maintain a LICENSES.txt file in this folder documenting each audio file's source and license. App Store review will spot-check audio provenance — keep this documentation current.

## Fallback behavior

If a .caf file is missing at runtime, IhsanNotifications falls back to UNNotificationSound.default. The app does not crash, but the user experience degrades.
