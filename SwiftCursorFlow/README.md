# CursorFlow SwiftUI

Native macOS menu bar version of CursorFlow.

## Build

```bash
swift build
./scripts/build_app.sh
```

The app bundle is written to:

```text
.build/release/CursorFlow.app
```

## Notes

- This version is macOS native and uses SwiftUI + AppKit.
- The menu bar icon is a template image, so macOS renders it black or white according to the menu bar background.
- Mouse movement and clicking use CoreGraphics / ApplicationServices and require Accessibility permission.
- Default auto-click interval is `1000ms`.
