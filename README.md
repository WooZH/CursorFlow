# CursorFlow

Native macOS menu bar utility for gentle mouse movement and optional auto-clicking.

CursorFlow is built with SwiftUI + AppKit. It runs from the menu bar, uses a native macOS-style glass UI, and performs pointer movement/click automation through CoreGraphics.

## Features

- Menu bar app with light/dark theme switching
- Automatic mouse movement using curved, human-like paths
- Auto-click at a chosen screen position
- Start-after idle delay
- Stop-after countdown timer
- Low battery protection
- English, Chinese, and Japanese UI
- Native template menu bar icon

## Requirements

- macOS 14 or later
- Accessibility permission for mouse movement and clicking

## Build

```bash
cd SwiftCursorFlow
./scripts/build_app.sh
```

The build script creates:

```text
SwiftCursorFlow/.build/release/CursorFlow.app
```

For local testing/distribution, you can copy the app bundle to:

```text
dist/CursorFlow.app
```

## Development

```bash
cd SwiftCursorFlow
swift build
```

## Author

[WooZH](https://github.com/WooZH)
