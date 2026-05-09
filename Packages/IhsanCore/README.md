# IhsanCore

IhsanCore is the shared data package for the Ihsan iOS and watchOS app. It contains the SwiftData models, schema versioning, migration plan scaffolding, and `ModelContainer` factory used by the app, widgets, and watch targets.

## Architecture

- Local-first data model backed by SwiftData.
- CloudKit private database sync through `iCloud.com.sameerstudios.ihsan`.
- Shared persistent store through the App Group `group.com.sameerstudios.ihsan`.
- No external dependencies, analytics, servers, or third-party services.
- Data-only package with no SwiftUI, UIKit, or AppKit imports.

## Usage

```swift
import IhsanCore

let container = try IhsanModelContainerFactory.makeContainer()
```

Use `inMemory: true` for SwiftUI Previews and unit tests:

```swift
let previewContainer = try IhsanModelContainerFactory.makeContainer(inMemory: true)
```
