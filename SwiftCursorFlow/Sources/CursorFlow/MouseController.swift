import AppKit
import ApplicationServices

enum MouseController {
    static func accessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func currentPosition() -> CGPoint {
        guard let event = CGEvent(source: nil) else { return .zero }
        return event.location
    }

    static func move(to point: CGPoint) {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            return
        }
        event.post(tap: .cghidEventTap)
    }

    static func click(at point: CGPoint, button: MouseButton) {
        let cgButton: CGMouseButton = button == .right ? .right : .left
        let downType: CGEventType = button == .right ? .rightMouseDown : .leftMouseDown
        let upType: CGEventType = button == .right ? .rightMouseUp : .leftMouseUp

        CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: cgButton)?
            .post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: cgButton)?
            .post(tap: .cghidEventTap)
    }
}
