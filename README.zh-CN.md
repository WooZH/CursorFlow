# CursorFlow

[English](README.md)

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
- 支持通过 GitHub Releases 手动检查更新
- 菜单栏使用图形状态标识鼠标移动、自动点击和保持清醒
- 支持低电量保护
- 支持英文、中文、日文界面
- 原生模板菜单栏图标，可适配系统深浅色

## 系统要求

- macOS 14 或更高版本
- 需要授予辅助功能权限，才能移动鼠标和执行点击

## 下载与安装

1. 前往 [GitHub Releases](https://github.com/WooZH/CursorFlow/releases) 下载最新的 `CursorFlow-v1.2.0-macOS.zip`。
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

## 协议

[MIT](LICENSE)
