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
        if status.keepAwake {
            drawCoffeeCup()
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
        for (index, y) in [13.2, 9.2, 5.2].enumerated() {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 15.0, y: y))
            path.curve(
                to: NSPoint(x: 27.0, y: y - 0.8),
                controlPoint1: NSPoint(x: 18.6, y: y + 1.6),
                controlPoint2: NSPoint(x: 23.0, y: y - 2.0)
            )
            path.lineWidth = index == 1 ? 1.45 : 1.25
            path.lineCapStyle = .round
            path.stroke()
        }
    }

    private static func drawCoffeeCup() {
        let cup = NSBezierPath(roundedRect: NSRect(x: 28.2, y: 4.0, width: 6.2, height: 5.3), xRadius: 1.2, yRadius: 1.2)
        cup.lineWidth = 1.15
        cup.stroke()

        let handle = NSBezierPath()
        handle.move(to: NSPoint(x: 34.1, y: 7.8))
        handle.curve(
            to: NSPoint(x: 34.1, y: 5.2),
            controlPoint1: NSPoint(x: 37.0, y: 7.8),
            controlPoint2: NSPoint(x: 37.0, y: 5.2)
        )
        handle.lineWidth = 1.05
        handle.lineCapStyle = .round
        handle.stroke()

        let plate = NSBezierPath()
        plate.move(to: NSPoint(x: 28.0, y: 2.8))
        plate.line(to: NSPoint(x: 34.9, y: 2.8))
        plate.lineWidth = 1.0
        plate.lineCapStyle = .round
        plate.stroke()

        for x in [29.4, 31.5, 33.6] {
            let steam = NSBezierPath()
            steam.move(to: NSPoint(x: x, y: 10.5))
            steam.curve(
                to: NSPoint(x: x + 0.3, y: 14.4),
                controlPoint1: NSPoint(x: x + 1.0, y: 11.7),
                controlPoint2: NSPoint(x: x - 0.6, y: 13.0)
            )
            steam.lineWidth = 0.8
            steam.lineCapStyle = .round
            steam.stroke()
        }
    }
}
