import AppKit

enum StatusIcon {
    static func make(status: AutomationStatus) -> NSImage {
        let size = NSSize(width: 38, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.set()

        if status.click {
            drawClickShadow()
        }
        drawCursor(filled: status.active)
        if status.movement {
            drawMotionLines()
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func drawCursor(filled: Bool) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 2.2, y: 14.7))
        path.line(to: NSPoint(x: 10.1, y: 8.0))
        path.line(to: NSPoint(x: 6.7, y: 7.3))
        path.line(to: NSPoint(x: 8.7, y: 2.8))
        path.line(to: NSPoint(x: 6.7, y: 1.9))
        path.line(to: NSPoint(x: 4.5, y: 6.2))
        path.line(to: NSPoint(x: 2.3, y: 3.8))
        path.close()

        if filled {
            path.fill()
        } else {
            path.lineWidth = 2.0
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.stroke()
        }
    }

    private static func drawClickShadow() {
        let shadow = NSBezierPath()
        shadow.move(to: NSPoint(x: 5.0, y: 12.0))
        shadow.line(to: NSPoint(x: 11.2, y: 6.8))
        shadow.line(to: NSPoint(x: 8.6, y: 6.3))
        shadow.line(to: NSPoint(x: 10.0, y: 3.2))
        shadow.line(to: NSPoint(x: 8.6, y: 2.5))
        shadow.line(to: NSPoint(x: 6.9, y: 5.7))
        shadow.line(to: NSPoint(x: 5.2, y: 3.9))
        shadow.close()
        shadow.lineWidth = 1.15
        shadow.lineJoinStyle = .round
        shadow.stroke()
    }

    private static func drawMotionLines() {
        for (index, points) in [
            (NSPoint(x: 15.0, y: 14.0), NSPoint(x: 28.5, y: 10.8)),
            (NSPoint(x: 15.0, y: 9.7), NSPoint(x: 30.0, y: 6.2)),
            (NSPoint(x: 15.0, y: 5.4), NSPoint(x: 28.5, y: 2.2))
        ].enumerated() {
            let path = NSBezierPath()
            path.move(to: points.0)
            path.line(to: points.1)
            path.lineWidth = index == 1 ? 1.45 : 1.25
            path.lineCapStyle = .round
            path.stroke()
        }
    }
}
