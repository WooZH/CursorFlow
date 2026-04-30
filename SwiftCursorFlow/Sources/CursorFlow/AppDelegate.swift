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
        statusItem.button?.image = StatusIcon.make(status: AutomationStatus(movement: false, click: false, keepAwake: false))
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        model.onStatusChanged = { [weak self] status in
            DispatchQueue.main.async {
                self?.statusItem?.button?.image = StatusIcon.make(status: status)
                self?.statusItem?.button?.image?.isTemplate = true
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
}
