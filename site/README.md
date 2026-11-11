# Ihsan landing page

A static page with no build step and no dependency to install. It makes no
request to anyone but its own host, which is what its privacy section says
and what it shows the visitor by counting its own requests.

```
index.html        the page
styles.css        all of the styling
js/main.js        state and wiring
js/day.js         a city's day: prayer times, "now", sun and moon angles
js/sky.js         the six sky palettes and the blend between them
js/plate.js       the hero instrument: arc, ornaments, sun, moon, stars
js/glyphs.js      the five prayer ornaments, ported from the app
js/specimens.js   the Path, Repair and qibla copies, and the request count
js/cities.js      cities by time zone, and the method each region starts on
vendor/           adhan-js 4.4.6 (MIT), the sibling of the app's Adhan-Swift
fonts/            Source Serif 4 and Amiri (both SIL OFL), served from here
assets/           screenshots, widget renders, icon
```

## What the page does

The hero is today, where the visitor is. The city is a guess from the
browser's time zone, the five times are computed in the tab, and the sky,
the ground and every colour on the page follow the sun through the app's
six palette states. Dragging the sun or the line under the horizon moves
the whole page through the day. The Today card, the Path grid, the Repair
ledger and the qibla compass are working copies; nothing they do is stored.

## Preview

```bash
python3 -m http.server 4173 --directory site
```

The scripts are ES modules, so the page needs a server; opening
`index.html` from the file system will not run them.

## Deploy

Point any static host at this folder as the project root, with no build
command and no output directory. On Vercel, Netlify or Cloudflare Pages that is
"Root directory: `site`".

## Before launch

- In `index.html`, replace both "Coming to the App Store" spans (masthead
  and footer) with the real App Store link. The markup is in the comment
  beside the first one.
- `og:image` is a relative path. Once the domain is known, make it absolute,
  since most link previews require that.
- The epigraph under the hero quotes the hadith of Jibrīl (Ṣaḥīḥ Muslim 8)
  in Arabic and English. Have the wording checked the same way the app's
  adhkār were before it ships.

## Keeping it true

- Screenshots in `assets/` are downscaled copies of `docs/app-store/*.png`
  and two frames from `docs/gallery/`. After recapturing, regenerate them:

  ```bash
  for f in store-1-night-plate store-2-dawn store-3-logging store-4-repair store-5-qibla store-6-path; do sips -s format jpeg -s formatOptions 84 --resampleWidth 720 docs/app-store/$f.png --out site/assets/$f.jpg; done
  sips -s format jpeg -s formatOptions 84 --resampleWidth 720 docs/gallery/10-reflect.png --out site/assets/screen-reflect.jpg
  sips -s format jpeg -s formatOptions 84 --resampleWidth 720 docs/gallery/11-dhikr.png --out site/assets/screen-tasbih.jpg
  ```

- `assets/widgets/` are copies of the pinned renders in
  `docs/widgets/gallery/`. `assets/live-activity.jpg` is a crop of
  `docs/gallery/live-activity-lock-screen.png`.
- The palette in `js/sky.js` mirrors
  `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Tokens/SkyPalette.swift`.
- The ornaments in `js/glyphs.js` mirror `PrayerOrnamentLibrary.swift`, and
  the arc in `js/plate.js` follows `PlateGeometry.swift`.
- `methodFor` in `js/cities.js` mirrors
  `CalculationMethodChoice.commonMethod(forCountryCode:)`.
- The privacy section restates `docs/app-privacy.md` and
  `docs/privacy-policy.md`. If the app's network calls change, change it here too.
- Do not add a web font service, an analytics script or a CDN. The page
  tells the visitor it loads nothing from anyone else, and counts.
