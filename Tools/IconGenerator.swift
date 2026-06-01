import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("usage: swift Tools/IconGenerator.swift <source.svg> <output.iconset>\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fputs("failed to load source svg: \(sourceURL.path)\n", stderr)
    exit(1)
}

let iconFiles: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIcon(size: Int) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    bounds.fill()

    let padding = CGFloat(size) * 0.12
    let drawRect = bounds.insetBy(dx: padding, dy: padding)
    sourceImage.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

for (name, size) in iconFiles {
    let bitmap = drawIcon(size: size)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fputs("failed to render \(name)\n", stderr)
        exit(1)
    }
    try data.write(to: outputURL.appendingPathComponent(name))
}
