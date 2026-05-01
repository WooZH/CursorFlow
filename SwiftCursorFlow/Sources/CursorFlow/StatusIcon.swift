import AppKit

enum StatusIcon {
    static func make(status: AutomationStatus) -> NSImage {
        let size = NSSize(width: 20, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.set()

        if status.click {
            drawClickShadow()
        }
        drawCursor(filled: status.active)
        if status.movement {
            drawMovementMarker()
        }
        if status.keepAwake {
            drawAwakeMarker()
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func drawCursor(filled: Bool) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 2.4, y: 14.9))
        path.line(to: NSPoint(x: 11.0, y: 7.7))
        path.line(to: NSPoint(x: 7.4, y: 6.9))
        path.line(to: NSPoint(x: 9.6, y: 2.4))
        path.line(to: NSPoint(x: 7.3, y: 1.3))
        path.line(to: NSPoint(x: 5.0, y: 5.7))
        path.line(to: NSPoint(x: 2.5, y: 3.3))
        path.close()

        if filled {
            path.fill()
        } else {
            path.lineWidth = 1.85
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.stroke()
        }
    }

    private static func drawClickShadow() {
        let shadow = NSBezierPath()
        shadow.move(to: NSPoint(x: 5.0, y: 12.0))
        shadow.line(to: NSPoint(x: 12.0, y: 6.1))
        shadow.line(to: NSPoint(x: 9.1, y: 5.6))
        shadow.line(to: NSPoint(x: 10.6, y: 2.6))
        shadow.line(to: NSPoint(x: 9.1, y: 1.9))
        shadow.line(to: NSPoint(x: 7.2, y: 4.9))
        shadow.line(to: NSPoint(x: 5.2, y: 3.3))
        shadow.close()
        shadow.lineWidth = 1.2
        shadow.lineJoinStyle = .round
        shadow.stroke()
    }

    private static func drawMovementMarker() {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 14.0, y: 8.4))
        path.line(to: NSPoint(x: 17.6, y: 4.8))
        path.line(to: NSPoint(x: 14.0, y: 1.2))
        path.line(to: NSPoint(x: 13.1, y: 3.5))
        path.line(to: NSPoint(x: 10.8, y: 4.8))
        path.line(to: NSPoint(x: 13.1, y: 6.1))
        path.close()
        path.fill()
    }

    private static func drawAwakeMarker() {
        let dot = NSBezierPath(ovalIn: NSRect(x: 13.8, y: 12.0, width: 3.4, height: 3.4))
        dot.fill()

        let ring = NSBezierPath(ovalIn: NSRect(x: 12.6, y: 10.8, width: 5.8, height: 5.8))
        ring.lineWidth = 1.0
        ring.stroke()
    }
}
