import AppKit
import SwiftUI

enum MenuBarIcon {
    static func image(size: CGFloat = 18) -> NSImage {
        if let source = loadTypeCIcon() ?? loadCableSVG() {
            return renderTemplateImage(from: source, size: size)
        }

        if let fallback = NSImage(systemSymbolName: "cable.connector", accessibilityDescription: "USB Status") {
            fallback.isTemplate = true
            fallback.size = NSSize(width: size, height: size)
            return fallback
        }

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        NSColor.labelColor.setStroke()
        let body = NSBezierPath(roundedRect: NSRect(x: 2.5, y: 5.0, width: 11.5, height: 8.5), xRadius: 3.0, yRadius: 3.0)
        body.lineWidth = 1.7
        body.stroke()

        let tip = NSBezierPath(roundedRect: NSRect(x: 10.0, y: 4.1, width: 6.0, height: 5.4), xRadius: 2.0, yRadius: 2.0)
        tip.lineWidth = 1.7
        tip.stroke()

        let port = NSBezierPath(roundedRect: NSRect(x: 11.7, y: 5.45, width: 3.8, height: 2.6), xRadius: 1.0, yRadius: 1.0)
        port.lineWidth = 1.2
        port.stroke()

        let cable1 = NSBezierPath()
        cable1.move(to: NSPoint(x: 2.7, y: 12.0))
        cable1.line(to: NSPoint(x: 0.5, y: 14.0))
        cable1.lineWidth = 1.6
        cable1.stroke()

        let cable2 = NSBezierPath()
        cable2.move(to: NSPoint(x: 4.3, y: 13.2))
        cable2.line(to: NSPoint(x: 1.8, y: 16.6))
        cable2.lineWidth = 1.6
        cable2.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func loadCableSVG() -> NSImage? {
        let mainBundleURL = Bundle.main.url(forResource: "cable", withExtension: "svg", subdirectory: "Icons")
        let moduleBundleURL = Bundle.module.url(forResource: "cable", withExtension: "svg", subdirectory: "Icons")
        guard let url = mainBundleURL ?? moduleBundleURL else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private static func loadTypeCIcon() -> NSImage? {
        let mainBundleURL = Bundle.main.url(forResource: "typec_icon", withExtension: "png", subdirectory: "Icons")
        let moduleBundleURL = Bundle.module.url(forResource: "typec_icon", withExtension: "png", subdirectory: "Icons")
        guard let url = mainBundleURL ?? moduleBundleURL else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private static func renderTemplateImage(from source: NSImage, size: CGFloat) -> NSImage {
        let target = NSImage(size: NSSize(width: size, height: size))
        target.lockFocus()
        source.draw(
            in: NSRect(x: 0, y: 0, width: size, height: size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
        target.unlockFocus()
        target.isTemplate = true
        return target
    }
}
