// Ilova ikonkasini chizadi: Resources/AppIcon.icns
// Ishga tushirish: swift scripts/make-icon.swift   (dizayn o'zgarsa — bir marta)
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)

    // macOS ikonka to'ri: 1024 da 824 lik yumaloq kvadrat
    let inset = s * 100 / 1024
    let box = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let shape = NSBezierPath(roundedRect: box, xRadius: box.width * 0.225, yRadius: box.width * 0.225)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = s * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGradient(colors: [NSColor(red: 0.05, green: 0.42, blue: 0.40, alpha: 1),
                        NSColor(red: 0.16, green: 0.20, blue: 0.48, alpha: 1)])!.draw(in: shape, angle: -65)

    // Ustki yorug'lik
    NSGraphicsContext.current?.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSRect(x: box.minX, y: box.midY, width: box.width, height: box.height / 2), angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Ustunlar — tokenlar oqimi
    let heights: [CGFloat] = [0.30, 0.52, 0.38, 0.74, 0.58]
    let barW = box.width * 0.105
    let gap = box.width * 0.06
    let total = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
    var x = box.midX - total / 2
    let base = box.minY + box.height * 0.2
    for (i, h) in heights.enumerated() {
        let r = NSRect(x: x, y: base, width: barW, height: box.height * 0.6 * h)
        let bar = NSBezierPath(roundedRect: r, xRadius: barW / 2, yRadius: barW / 2)
        (i == 3 ? NSColor(red: 1.0, green: 0.78, blue: 0.30, alpha: 1) : NSColor.white.withAlphaComponent(0.92)).setFill()
        bar.fill()
        x += barW + gap
    }

    // Jonli nuqta
    let dot = box.width * 0.085
    let dotRect = NSRect(x: box.maxX - box.width * 0.2 - dot / 2, y: box.maxY - box.height * 0.2 - dot / 2, width: dot, height: dot)
    NSColor(red: 0.33, green: 0.93, blue: 0.55, alpha: 1).setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let out = root.appendingPathComponent("Resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "✓ \(out.path)" : "iconutil xatosi")
