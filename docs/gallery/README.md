# Gallery

Frames captured from the real app by `ihsanUITests/GalleryCaptureUITests`
and the per-phase verification tests. Nothing here is a mockup.

Regenerate:

```bash
xcodebuild test -project ihsan.xcodeproj -scheme ihsan \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:ihsanUITests/GalleryCaptureUITests/testCaptureGallery
# then copy from the runner's tmp directory:
#   ~/Library/Developer/CoreSimulator/Devices/<udid>/data/Containers/Data/
#     Application/<uuid>/tmp/ihsan-gallery
```

Each frame is one launch with the debug arguments that stage its state
(`-IhsanNowOverride`, `-IhsanDebugTab`, `-IhsanDebugSettingsRoute`, …),
so a frame is reproducible rather than a moment someone happened to
catch.

## Live Activity

`live-activity-compact.png`, `live-activity-expanded.png`, and
`live-activity-lock-screen.png` come from the real ActivityKit fixture in
`LiveActivityCaptureUITests`. The minimal frame is also a SpringBoard
capture; it uses a second, ad-hoc simulator bundle because iOS groups two
activities from one app into the ordinary compact presentation instead
of selecting the distinct-app minimal presentation.
