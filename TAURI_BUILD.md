# CursorFlow – Tauri Build Guide

## Prerequisites

```bash
# Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add aarch64-apple-darwin x86_64-apple-darwin  # for universal binary

# Node (LTS)
brew install node

# Tauri CLI
npm install   # installs @tauri-apps/cli from package.json
```

## Development

```bash
npm run dev
```

Opens the window with hot-reload from `src/index.html`.

## Production Build

```bash
npm run build
```

Output: `src-tauri/target/release/bundle/macos/CursorFlow.app`

## Universal Binary (Apple Silicon + Intel)

```bash
npx tauri build --target universal-apple-darwin
```

## First-Run Notes

1. **No Dock icon** – the app lives only in the menu bar (LSUIElement = true).
2. **Left-click** the tray icon to toggle the main window.
3. **Right-click** to access the context menu (Open / Quit).
4. **Accessibility permission** is required for Auto Click (`CGEventPost`).
   - The app will prompt on first click attempt.
   - Grant in: System Settings → Privacy & Security → Accessibility.
5. **Mouse movement** uses `CGWarpMouseCursorPosition` – no permissions needed.

## Architecture

```
src-tauri/src/
  main.rs            – binary entry point
  lib.rs             – Tauri app bootstrap, all IPC commands, tray setup
  macos_mouse.rs     – CoreGraphics + ApplicationServices FFI
  config_store.rs    – JSON config persistence (~/Library/Application Support/CursorFlow/)
  input_detection.rs – Background cursor polling, user vs engine movement
  simulation_model.rs – Human Simulation Levels: Basic / Smart / Pro
  movement_engine.rs – Background tick + smooth threads, mode state machine

src/
  index.html         – Main UI (violet theme, dual feature cards)
  capture.html       – Fullscreen transparent position capture overlay
```

## Human Simulation Levels

| Level | Path type | Interval variation | Overshoot | Pauses |
|-------|-----------|-------------------|-----------|--------|
| Basic | 8-step linear | none | no | no |
| Smart | Quadratic Bezier + noise | ±40% | no | no |
| Pro   | Cubic Bezier + noise | ±60% + long pauses | yes (40%) | yes (15%) |

## PRO Activation

Enter code **SHEEP** in the activation panel to unlock the Pro simulation level.
