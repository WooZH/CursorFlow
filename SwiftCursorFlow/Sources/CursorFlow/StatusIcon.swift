import AppKit

enum StatusIcon {
    static func make(status: AutomationStatus) -> NSImage {
        let size = NSSize(width: 34, height: 18)
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
        path.move(to: NSPoint(x: 20.2, y: 14.2))
        path.line(to: NSPoint(x: 25.4, y: 9.0))
        path.line(to: NSPoint(x: 20.2, y: 3.8))
        path.line(to: NSPoint(x: 18.7, y: 7.5))
        path.line(to: NSPoint(x: 15.0, y: 9.0))
        path.line(to: NSPoint(x: 18.7, y: 10.5))
        path.close()
        path.fill()
    }

    private static func drawAwakeMarker() {
        let dot = NSBezierPath(ovalIn: NSRect(x: 27.2, y: 11.4, width: 4.2, height: 4.2))
        dot.fill()

        let ring = NSBezierPath(ovalIn: NSRect(x: 25.8, y: 10.0, width: 7.0, height: 7.0))
        ring.lineWidth = 1.15
        ring.stroke()
    }
}
