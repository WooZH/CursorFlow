import AppKit

enum StatusIcon {
    static func make(active: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.set()

        let path = NSBezierPath()
        path.move(to: NSPoint(x: 5.1, y: 14.7))
        path.line(to: NSPoint(x: 13.0, y: 8.0))
        path.line(to: NSPoint(x: 9.6, y: 7.3))
        path.line(to: NSPoint(x: 11.6, y: 2.8))
        path.line(to: NSPoint(x: 9.6, y: 1.9))
        path.line(to: NSPoint(x: 7.4, y: 6.2))
        path.line(to: NSPoint(x: 5.2, y: 3.8))
        path.close()

        if active {
            path.fill()
        } else {
            path.lineWidth = 2.0
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.stroke()
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
