import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 430, height: 610)
        popover.appearance = model.appearanceForCurrentTheme()
        popover.contentViewController = NSHostingController(rootView: ContentView(model: model))
        self.popover = popover

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem
        statusItem.length = 40
        statusItem.button?.image = StatusIcon.make(status: model.currentStatus)
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = model.statusTooltip
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        model.onStatusChanged = { [weak self] status in
            DispatchQueue.main.async {
                self?.statusItem?.button?.image = StatusIcon.make(status: status)
                self?.statusItem?.button?.image?.isTemplate = true
                self?.statusItem?.button?.toolTip = self?.model.statusTooltip
            }
        }
        model.onThemeChanged = { [weak self] appearance in
            DispatchQueue.main.async {
                self?.popover?.appearance = appearance
                self?.popover?.contentViewController?.view.appearance = appearance
            }
        }
        model.onPositionCaptureStarted = { [weak self] in
            self?.popover?.behavior = .applicationDefined
        }
        model.onPositionCaptureFinished = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self?.popover?.behavior = .transient
                self?.showPopover()
            }
        }
    }

    @objc private func togglePopover() {
        guard let popover else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            showQuickActionsMenu()
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button, let popover else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showQuickActionsMenu() {
        let menu = NSMenu()
        menu.addItem(menuItem(
            title: "Mouse Movement",
            action: #selector(toggleMovementFromMenu),
            checked: model.movementEnabled
        ))
        let clickItem = menuItem(
            title: "Auto Click",
            action: #selector(toggleClickFromMenu),
            checked: model.clickEnabled
        )
        clickItem.isEnabled = model.config.clickPosition != nil || model.clickEnabled
        menu.addItem(clickItem)
        menu.addItem(menuItem(
            title: "Keep Awake",
            action: #selector(toggleKeepAwakeFromMenu),
            checked: model.config.keepAwakeEnabled
        ))
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open CursorFlow", action: #selector(openFromMenu), keyEquivalent: "")
        menu.addItem(withTitle: "Quit", action: #selector(quitFromMenu), keyEquivalent: "")

        menu.items.forEach { $0.target = self }
        statusItem?.button?.highlight(true)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: statusItem?.button?.bounds.height ?? 0), in: statusItem?.button)
        statusItem?.button?.highlight(false)
    }

    private func menuItem(title: String, action: Selector, checked: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.state = checked ? .on : .off
        return item
    }

    @objc private func toggleMovementFromMenu() {
        model.toggleMovement()
    }

    @objc private func toggleClickFromMenu() {
        model.toggleClick()
    }

    @objc private func toggleKeepAwakeFromMenu() {
        model.toggleKeepAwake()
    }

    @objc private func openFromMenu() {
        showPopover()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }
}
