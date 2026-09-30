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
    let terrain = NSBezierPath()
    terrain.move(to:.init(x:90,y:195)); terrain.line(to:.init(x:220,y:260)); terrain.line(to:.init(x:350,y:200))
    terrain.line(to:.init(x:670,y:200)); terrain.line(to:.init(x:790,y:295)); terrain.line(to:.init(x:930,y:205))
    NSColor(red:0.62,green:0.94,blue:0.79,alpha:0.8).setStroke(); terrain.lineWidth = 12; terrain.stroke()
    let hull = NSBezierPath()
    for (i,p) in [NSPoint(x:430,y:800),.init(x:590,y:800),.init(x:670,y:650),.init(x:645,y:465),.init(x:375,y:465),.init(x:350,y:650)].enumerated() {
        if i == 0 { hull.move(to:p) } else { hull.line(to:p) }
    }
    hull.close(); NSColor(red:0.08,green:0.14,blue:0.17,alpha:1).setFill(); hull.fill()
    NSColor(red:0.86,green:0.94,blue:0.90,alpha:1).setStroke(); hull.lineWidth = 15; hull.stroke()
    let window = NSBezierPath(); window.move(to:.init(x:440,y:745)); window.line(to:.init(x:575,y:745))
    window.line(to:.init(x:604,y:635)); window.line(to:.init(x:410,y:635)); window.close()
    NSColor(red:0.62,green:0.94,blue:0.79,alpha:0.8).setFill(); window.fill()
    let legs = NSBezierPath()
    for sign in [-1.0,1.0] {
        legs.move(to:.init(x:512+sign*125,y:535)); legs.line(to:.init(x:512+sign*232,y:350))
        legs.line(to:.init(x:512+sign*285,y:350)); legs.move(to:.init(x:512+sign*130,y:465)); legs.line(to:.init(x:512+sign*232,y:350))
    }
    NSColor(red:0.9,green:0.96,blue:0.92,alpha:1).setStroke(); legs.lineWidth = 14; legs.stroke()
    let flame = NSBezierPath(); flame.move(to:.init(x:460,y:440)); flame.line(to:.init(x:512,y:290)); flame.line(to:.init(x:564,y:440)); flame.close()
    NSColor(red:1,green:0.69,blue:0.35,alpha:1).setFill(); flame.fill()
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Icon rendering failed") }
    try png.write(to: directory.appendingPathComponent("\(name).png"))
}
