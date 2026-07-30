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
