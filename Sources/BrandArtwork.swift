import AppKit

// One resolution-independent return-frame mark for the app, status item and icon.
// Coordinates use a 100-point canvas with an upward Y axis.
enum BrandArtwork {
    static let accent = NSColor(srgbRed: 0.36, green: 0.18, blue: 1.0, alpha: 1)

    static func drawMark(in rect: NSRect, color: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.minX, yBy: rect.minY)
        transform.scaleX(by: rect.width / 100, yBy: rect.height / 100)
        transform.concat()
        color.setStroke()
        color.setFill()
        let frame = NSBezierPath()
        frame.move(to: NSPoint(x: 42, y: 78))
        frame.line(to: NSPoint(x: 24, y: 78))
        frame.curve(to: NSPoint(x: 12, y: 66), controlPoint1: NSPoint(x: 17, y: 78), controlPoint2: NSPoint(x: 12, y: 73))
        frame.line(to: NSPoint(x: 12, y: 32))
        frame.curve(to: NSPoint(x: 24, y: 20), controlPoint1: NSPoint(x: 12, y: 25), controlPoint2: NSPoint(x: 17, y: 20))
        frame.line(to: NSPoint(x: 76, y: 20))
        frame.curve(to: NSPoint(x: 88, y: 32), controlPoint1: NSPoint(x: 83, y: 20), controlPoint2: NSPoint(x: 88, y: 25))
        frame.line(to: NSPoint(x: 88, y: 66))
        frame.curve(to: NSPoint(x: 76, y: 78), controlPoint1: NSPoint(x: 88, y: 73), controlPoint2: NSPoint(x: 83, y: 78))
        frame.line(to: NSPoint(x: 59, y: 78))
        frame.lineWidth = 10
        frame.lineCapStyle = .round
        frame.lineJoinStyle = .round
        frame.stroke()
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 67, y: 89))
        arrow.line(to: NSPoint(x: 54, y: 78))
        arrow.line(to: NSPoint(x: 67, y: 67))
        arrow.lineWidth = 8
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        arrow.stroke()
        let foot = NSBezierPath()
        foot.move(to: NSPoint(x: 36, y: 6))
        foot.line(to: NSPoint(x: 64, y: 6))
        foot.lineWidth = 9
        foot.lineCapStyle = .round
        foot.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    static func symbol(size: CGFloat = 32, template: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            drawMark(in: rect.insetBy(dx: size * 0.035, dy: size * 0.035), color: template ? .black : accent)
            return true
        }
        image.isTemplate = template
        image.accessibilityDescription = "re-sPLAY"
        return image
    }
}
