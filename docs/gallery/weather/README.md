# The living sky — verification gallery

Simulator frames for the weather work (`sky:` commits). All staged
with the debug harness — `-IhsanDebugSkyConditions <kind>` forces a
reading, `-IhsanDebugLivingSky` stands in for the Set → Display
toggle — so no WeatherKit provisioning or real weather is involved.

## Weather dua lines (Phase 2)

The quiet register line during each trigger, and the reader it opens.
Captured by `WeatherCaptureUITests.testCaptureWeatherDuaLines`.

- `weather-line-rain.png` — IT IS RAINING · THE DUA OF RAIN
- `weather-line-after-rain.png` — THE RAIN HAS PASSED · ITS REMEMBRANCE
- `weather-line-wind.png` — THE WIND IS STRONG · ITS DUA
- `weather-line-thunder.png` — THUNDER · ITS DHIKR
- `weather-reader-rain.png` — the transmitted text on the reading
  surface (al-Bukhārī 1032), source toggle and counting ring intact

## The seasoned clear day (Phase 2.5)

- `seasoned-day.png` — mid-morning: the re-graded continuous ramp,
  the 16/16 ray collar, the corner pieces, the worked ground
- `seasoned-late-afternoon.png` — the same page at the warm end

## Per-condition gates (Phase 3)

`living-sky-<condition>-<day|night>.png`, captured by
`WeatherCaptureUITests.testCaptureLivingSkyTreatments`. Each condition
ships only after its maintainer gate; a rejected condition is cut from
`SkyWeatherTreatment.gateApproved` and falls back along its chain.

| condition | forced kind | treatment |
|---|---|---|
| partly-veiled | `partlyCloudy` | two tinted-vellum washes behind the instrument |
| overcast | `cloudy` | value compression toward a lowered middle, calmed chroma, quieted metal |
| rain | `rain` | engraved diagonal hatching, deepened ground band |
| snow | `snow` | the gold-dust discipline in cool white |
| storm | `thunderstorms` | overcast + rain, one step deeper; nothing flashes |

## Fallback drills (Phase 4)

- `drill-weatherkit-error.png` — living sky ON, no forced reading: the
  real WeatherKit fetch fails on the simulator (no provisioning) and
  the plate paints its idealized day, silently
- `drill-toggle-off.png` — everything off: no fetch is attempted at all
