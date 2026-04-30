import AppKit

enum StatusIcon {
    static func make(status: AutomationStatus) -> NSImage {
        let size = NSSize(width: 44, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.set()

        drawCursor(filled: status.active)
        drawBadges(status)

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

    private static func drawBadges(_ status: AutomationStatus) {
        let badges = [
            status.movement ? "A" : nil,
            status.click ? "C" : nil,
            status.keepAwake ? "E" : nil
        ].compactMap { $0 }.joined()

        guard !badges.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 8.4, weight: .bold),
            .foregroundColor: NSColor.black
        ]
        let string = NSAttributedString(string: badges, attributes: attributes)
        string.draw(at: NSPoint(x: 14.2, y: 4.7))
    }
}
