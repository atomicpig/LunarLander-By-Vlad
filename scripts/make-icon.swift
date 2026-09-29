import AppKit

let output = CommandLine.arguments[1]
let directory = URL(fileURLWithPath: output).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for (name, pixels) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
                       ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256),
                       ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    let size = CGFloat(pixels)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let transform = NSAffineTransform(); transform.scale(by: size / 1024); transform.concat()
    let rect = NSRect(x: 30, y: 30, width: 964, height: 964)
    NSColor(red: 0.04, green: 0.07, blue: 0.12, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: 215, yRadius: 215).fill()
    NSColor(red: 0.36, green: 0.9, blue: 0.78, alpha: 0.15).setStroke()
    let orbit = NSBezierPath(ovalIn: NSRect(x: 175, y: 185, width: 680, height: 650)); orbit.lineWidth = 7; orbit.stroke()
    let path = NSBezierPath()
    path.move(to: .init(x: 512, y: 850)); path.line(to: .init(x: 663, y: 570))
    path.line(to: .init(x: 641, y: 362)); path.line(to: .init(x: 383, y: 362))
    path.line(to: .init(x: 361, y: 570)); path.close()
    NSColor(red: 0.85, green: 0.94, blue: 0.95, alpha: 1).setFill(); path.fill()
    NSColor(red: 0.06, green: 0.31, blue: 0.40, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 445, y: 557, width: 134, height: 134)).fill()
    NSColor(red: 0.35, green: 0.92, blue: 0.8, alpha: 1).setFill()
    let flame = NSBezierPath(); flame.move(to: .init(x: 437, y: 333)); flame.line(to: .init(x: 512, y: 127))
    flame.line(to: .init(x: 587, y: 333)); flame.close(); flame.fill()
    NSColor.orange.setFill(); NSBezierPath(rect: .init(x: 387, y: 395, width: 250, height: 37)).fill()
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Icon rendering failed") }
    try png.write(to: directory.appendingPathComponent("\(name).png"))
}
