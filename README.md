# CursorFlow

[中文说明](#中文说明)

Native macOS menu bar utility for gentle mouse movement and optional auto-clicking.

CursorFlow is built with SwiftUI + AppKit. It runs from the menu bar, uses a native macOS-style glass UI, and performs pointer movement/click automation through CoreGraphics.

## Features

- Menu bar app with light/dark theme switching
- Automatic mouse movement using curved, human-like paths
- Auto-click at a chosen screen position
- Start-after idle delay
- Stop-after countdown timer
- Keep-awake mode to prevent idle sleep while automation is active
- Menu bar visual status indicators for movement, click, and keep-awake
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

---

## 中文说明

[English](#cursorflow)

CursorFlow 是一个原生 macOS 菜单栏工具，用于轻量鼠标移动和可选的自动点击。

CursorFlow 使用 SwiftUI + AppKit 构建。它运行在菜单栏中，提供 macOS 原生风格的玻璃拟态界面，并通过 CoreGraphics 执行鼠标移动和点击自动化。

## 功能

- 菜单栏应用，支持浅色/深色主题切换
- 自动鼠标移动，使用曲线化、接近自然操作的路径
- 在指定屏幕坐标执行自动点击
- 支持闲置后开始
- 支持倒计时停止
- 支持保持清醒，自动化运行时防止系统空闲睡眠
- 菜单栏使用图形状态标识鼠标移动、自动点击和保持清醒
- 支持低电量保护
- 支持英文、中文、日文界面
- 原生模板菜单栏图标，可适配系统深浅色

## 系统要求

- macOS 14 或更高版本
- 需要授予辅助功能权限，才能移动鼠标和执行点击

## 构建

```bash
cd SwiftCursorFlow
./scripts/build_app.sh
```

构建脚本会生成：

```text
SwiftCursorFlow/.build/release/CursorFlow.app
```

如果要本地测试或分发，可以复制到：

```text
dist/CursorFlow.app
```

## 开发

```bash
cd SwiftCursorFlow
swift build
```

## 作者

[WooZH](https://github.com/WooZH)
