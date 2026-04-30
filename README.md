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
- 支持定时保持清醒，并兼容跨午夜时间段
- 支持菜单栏状态提示和右键快捷操作
- 菜单栏使用图形状态标识鼠标移动、自动点击和保持清醒
- 支持低电量保护
- 支持英文、中文、日文界面
- 原生模板菜单栏图标，可适配系统深浅色

## 系统要求

- macOS 14 或更高版本
- 需要授予辅助功能权限，才能移动鼠标和执行点击

## 下载与安装

1. 前往 [GitHub Releases](https://github.com/WooZH/CursorFlow/releases) 下载最新的 `CursorFlow-v1.1.0-macOS.zip`。
2. 解压后，将 `CursorFlow.app` 移动到 `Applications` 文件夹。
3. 打开 `CursorFlow.app`，应用会运行在 macOS 菜单栏中。
4. 根据提示授予辅助功能权限，或手动前往 `系统设置 > 隐私与安全性 > 辅助功能` 开启。

如果 macOS 因为应用来自互联网而阻止打开，请前往 `系统设置 > 隐私与安全性`，选择 `仍要打开`。

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
