# CursorFlow

[中文说明](README.zh-CN.md)

Native macOS menu bar utility for gentle mouse movement and optional auto-clicking.

CursorFlow is built with SwiftUI + AppKit. It runs from the menu bar, uses a native macOS-style glass UI, and performs pointer movement/click automation through CoreGraphics.

## Features

- Menu bar app with light/dark theme switching
- Automatic mouse movement using curved, human-like paths
- Auto-click at a chosen screen position
- Start-after idle delay
- Stop-after countdown timer
- Keep-awake mode to prevent idle sleep while automation is active
- Scheduled keep-awake window with overnight schedule support
- Menu bar tooltip summary and right-click quick actions
- Menu bar visual status indicators for movement, click, and keep-awake
- Low battery protection
- English, Chinese, and Japanese UI
- Native template menu bar icon

## Requirements

- macOS 14 or later
- Accessibility permission for mouse movement and clicking

## Download & Install

1. Download the latest `CursorFlow-v1.1.0-macOS.zip` from the [GitHub Releases](https://github.com/WooZH/CursorFlow/releases) page.
2. Unzip the file and move `CursorFlow.app` to your `Applications` folder.
3. Open `CursorFlow.app`. The app runs from the macOS menu bar.
4. Grant Accessibility permission when prompted, or enable it manually in `System Settings > Privacy & Security > Accessibility`.

If macOS blocks the app because it was downloaded from the internet, open `System Settings > Privacy & Security` and choose `Open Anyway`.

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

## License

[MIT](LICENSE)
