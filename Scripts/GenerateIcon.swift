import AppKit
import Foundation

@main
struct GenerateIcon {
    static func main() throws {
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
                let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 202, yRadius: 202)
                NSGradient(starting: BrandArtwork.accent, ending: NSColor(srgbRed: 0.29, green: 0.12, blue: 0.90, alpha: 1))!.draw(in: tile, angle: -90)
                NSColor.white.withAlphaComponent(0.16).setStroke()
                tile.lineWidth = 2
                tile.stroke()
                BrandArtwork.drawMark(in: NSRect(x: 228, y: 217, width: 568, height: 568), color: .white)
                NSGraphicsContext.restoreGraphicsState()
                let suffix = scale == 2 ? "@2x" : ""
                try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
            }
        }
        if CommandLine.arguments.count > 2 {
            let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try Data(contentsOf: directory.appendingPathComponent("icon_512x512@2x.png"))
                .write(to: output.appendingPathComponent("re-splay-app-icon.png"))
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            BrandArtwork.drawMark(in: NSRect(x: 128, y: 128, width: 768, height: 768), color: BrandArtwork.accent)
            NSGraphicsContext.restoreGraphicsState()
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("re-splay-symbol.png"))
        }
    }
}
