import AppKit
import SwiftUI
import FlightCore

/// Fixed AppKit labels keep telemetry updates out of SwiftUI's slider/button
/// layout graph. Updating a reading never relays out the flight controls.
struct InstrumentReadout: NSViewRepresentable {
    let world: World
    let initialFuel: Double
    func makeNSView(context: Context) -> InstrumentView { InstrumentView() }
    func updateNSView(_ view: InstrumentView, context: Context) { view.update(world, initialFuel: initialFuel) }
}

final class InstrumentView: NSView {
    override var isFlipped: Bool { true }
    private var labels: [String: NSTextField] = [:]
    private let fuelTrack = NSView()
    private let fuelFill = NSView()
    private var fuelFraction = 1.0
    private let muted = NSColor(red: 0.54, green: 0.62, blue: 0.72, alpha: 1)
    private let accent = NSColor(red: 0.38, green: 0.91, blue: 0.79, alpha: 1)

    init() {
        super.init(frame: .zero)
        for (key, title) in [("altTitle", "ALTITUDINE"), ("vxTitle", "VITEZĂ X"), ("vyTitle", "VITEZĂ Y"),
                             ("accTitle", "ACCELERAȚIE"), ("angleTitle", "ÎNCLINARE"), ("fuelTitle", "COMBUSTIBIL")] {
            add(key, text: title, size: 9, color: muted)
        }
        add("alt", size: 37); add("vx", size: 21); add("vy", size: 21)
        add("acc", size: 21); add("angle", size: 21)
        add("fuel", size: 10); add("mass", size: 9, color: muted)
        labels["fuel"]?.alignment = .right
        fuelTrack.wantsLayer = true; fuelTrack.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        fuelTrack.layer?.cornerRadius = 2.5; addSubview(fuelTrack)
        fuelFill.wantsLayer = true; fuelFill.layer?.backgroundColor = accent.cgColor
        fuelFill.layer?.cornerRadius = 2.5; fuelTrack.addSubview(fuelFill)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    private func add(_ key: String, text: String = "", size: Double, color: NSColor = .white) {
        let label = NSTextField(labelWithString: text)
        label.font = .monospacedDigitSystemFont(ofSize: size, weight: size > 30 ? .light : .regular)
        label.textColor = color; label.lineBreakMode = .byClipping
        labels[key] = label; addSubview(label)
    }
    override func layout() {
        super.layout()
        let w = bounds.width, half = w / 2 + 7
        let placements: [(String, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            ("altTitle",0,0,w,14), ("alt",0,18,w,47),
            ("vxTitle",0,76,w/2,12), ("vyTitle",half,76,w/2-7,12),
            ("vx",0,92,w/2,28), ("vy",half,92,w/2-7,28),
            ("accTitle",0,131,w/2,12), ("angleTitle",half,131,w/2-7,12),
            ("acc",0,147,w/2,28), ("angle",half,147,w/2-7,28),
            ("fuelTitle",0,187,w/2,13), ("fuel",w/2,187,w/2,13), ("mass",0,218,w,13)
        ]
        for (key,x,y,width,height) in placements { labels[key]?.frame = .init(x:x,y:y,width:width,height:height) }
        fuelTrack.frame = .init(x:0,y:207,width:w,height:5)
        fuelFill.frame = .init(x:0,y:0,width:w * fuelFraction,height:5)
    }
    func update(_ world: World, initialFuel: Double) {
        let values = ["alt": String(format: "%.1f m", world.altitude),
                      "vx": String(format: "%.1f m/s", world.velocity.x), "vy": String(format: "%.1f m/s", world.velocity.y),
                      "acc": String(format: "%.1f m/s²", world.acceleration.length), "angle": String(format: "%.1f°", world.angle * 180 / .pi),
                      "fuel": String(format: "%.1f kg", world.fuel),
                      "mass": String(format: "Masă %.0f kg · motor %.0f N", world.mass, world.thrustForce.length)]
        for (key, text) in values where labels[key]?.stringValue != text { labels[key]?.stringValue = text }
        labels["vx"]?.textColor = abs(world.velocity.x) <= Physics.landingHorizontalSpeed ? accent : .systemOrange
        labels["vy"]?.textColor = abs(world.velocity.y) <= Physics.landingVerticalSpeed ? accent : .systemOrange
        labels["angle"]?.textColor = abs(world.angle) <= Physics.landingAngle ? accent : .systemOrange
        fuelFraction = clamp(world.fuel / max(1, initialFuel), 0, 1)
        fuelFill.frame.size.width = bounds.width * fuelFraction
        fuelFill.layer?.backgroundColor = (world.fuel < 20 ? NSColor.systemOrange : accent).cgColor
    }
}
