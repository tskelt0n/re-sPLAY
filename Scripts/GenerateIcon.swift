import AppKit
import Foundation

// Native SF Symbol artwork keeps the icon consistent with the menu-bar mark.
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let rect = NSRect(x: 64, y: 64, width: 896, height: 896)
        let shape = NSBezierPath(roundedRect: rect, xRadius: 206, yRadius: 206)
        NSGradient(starting: NSColor(srgbRed: 0.10, green: 0.55, blue: 0.98, alpha: 1), ending: NSColor(srgbRed: 0.12, green: 0.27, blue: 0.76, alpha: 1))!.draw(in: shape, angle: -90)
        NSColor.white.withAlphaComponent(0.22).setStroke()
        shape.lineWidth = 2
        shape.stroke()
        let configuration = NSImage.SymbolConfiguration(pointSize: 450, weight: .regular).applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))
        let symbol = NSImage(systemSymbolName: "display.2", accessibilityDescription: nil)!.withSymbolConfiguration(configuration)!
        let width: CGFloat = 620
        let height = width * symbol.size.height / symbol.size.width
        symbol.draw(in: NSRect(x: (1024-width)/2, y: (1024-height)/2, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
