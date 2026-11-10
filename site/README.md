# Ihsan landing page

A static page: `index.html`, `styles.css`, `main.js`, and `assets/`. There is
no build step and no dependency, and the page makes no third-party request
(system fonts, no analytics), which is what its privacy section says.

## Preview

```bash
python3 -m http.server 4173 --directory site
```

## Deploy

Point any static host at this folder as the project root, with no build
command and no output directory. On Vercel, Netlify or Cloudflare Pages that is
"Root directory: `site`".

## Before launch

- In `index.html`, replace the "Coming to the App Store" span in the masthead
  with the real App Store link (the markup is in the comment beside it).
- `og:image` is a relative path. Once the domain is known, make it absolute,
  since most link previews require that.

## Keeping it true

- Screenshots in `assets/` are downscaled copies of `docs/app-store/*.png`.
  After recapturing, regenerate them:

  ```bash
  for f in store-3-logging store-6-path store-4-repair store-5-qibla; do sips -s format jpeg -s formatOptions 84 --resampleWidth 720 docs/app-store/$f.png --out site/assets/$f.jpg; done
  ```

- The palette in `main.js` mirrors
  `Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Tokens/SkyPalette.swift`.
- The privacy section restates `docs/app-privacy.md` and
  `docs/privacy-policy.md`. If the app's network calls change, change it here too.
