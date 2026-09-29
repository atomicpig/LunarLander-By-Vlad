import AppKit
import SwiftUI
import SpriteKit
import FlightCore

enum Palette {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.09)
    static let panel = Color(red: 0.065, green: 0.09, blue: 0.135)
    static let accent = Color(red: 0.38, green: 0.91, blue: 0.79)
    static let muted = Color(red: 0.54, green: 0.62, blue: 0.72)
    static func planet(_ name: String) -> NSColor {
        switch name {
        case "orange": return NSColor(red: 0.98, green: 0.59, blue: 0.36, alpha: 1)
        case "purple": return NSColor(red: 0.70, green: 0.60, blue: 1, alpha: 1)
        case "green": return NSColor(red: 0.38, green: 0.91, blue: 0.66, alpha: 1)
        default: return NSColor(red: 0.38, green: 0.91, blue: 0.85, alpha: 1)
        }
    }
}

struct FlightCanvas: NSViewRepresentable {
    let model: GameModel
    func makeNSView(context: Context) -> SKView {
        let view = SKView()
        view.preferredFramesPerSecond = 120
        view.ignoresSiblingOrder = true
        let scene = FlightScene(model: model)
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        return view
    }
    func updateNSView(_ view: SKView, context: Context) {}
}

final class FlightScene: SKScene {
    private weak var model: GameModel?
    private let space = SKNode()
    private let environment = SKNode()
    private let ship = SKNode()
    private let flame = SKShapeNode()
    private let jets = (0..<5).map { _ in SKShapeNode() }
    private let legs = SKShapeNode()
    private let vectors = SKNode()
    private let velocityArrow = VectorArrow(color: .systemCyan, text: "v")
    private let forceArrow = VectorArrow(color: .systemGreen, text: "F")
    private let gravityArrow = VectorArrow(color: .systemOrange, text: "G")
    private let trail = SKShapeNode()
    private let targetLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let shipLabel = SKLabelNode(fontNamed: "Menlo")
    private var lastMission = -1
    private var lastSize = CGSize.zero
    private var trailPoints: [CGPoint] = []
    private var lastTrailTime = -1.0
    private var previousOutcome = FlightOutcome.flying
    private var landedAt: TimeInterval?
    private var cameraCentre = Vector(100, 48)
    private var cameraScale = 0.0
    private var lastRenderTime: TimeInterval?
    private var frameDurations: [Double] = []
    private let performanceLog = ProcessInfo.processInfo.arguments.contains("--performance-log")

    init(model: GameModel) {
        self.model = model
        super.init(size: CGSize(width: 1000, height: 620))
        backgroundColor = NSColor(red: 0.025, green: 0.045, blue: 0.08, alpha: 1)
        addChild(space); space.addChild(environment); space.addChild(trail)
        space.addChild(ship); space.addChild(vectors)
        vectors.addChild(velocityArrow); vectors.addChild(forceArrow); vectors.addChild(gravityArrow)
        ship.zPosition = 20; vectors.zPosition = 30
        createShip()
        targetLabel.fontSize = 16.8; targetLabel.setScale(0.125); targetLabel.zPosition = 15
        space.addChild(targetLabel)
        shipLabel.fontSize = 13.2; shipLabel.setScale(0.125); shipLabel.fontColor = .white.withAlphaComponent(0.75)
        shipLabel.zPosition = 25; space.addChild(shipLabel)
        trail.strokeColor = .white.withAlphaComponent(0.16); trail.lineWidth = 1.44; trail.setScale(0.125)
        trail.zPosition = 2
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func createShip() {
        let hull = CGMutablePath()
        hull.move(to: CGPoint(x: 0, y: 3.8))
        hull.addLine(to: CGPoint(x: 1.65, y: 1.2))
        hull.addLine(to: CGPoint(x: 1.45, y: -1.7))
        hull.addLine(to: CGPoint(x: -1.45, y: -1.7))
        hull.addLine(to: CGPoint(x: -1.65, y: 1.2)); hull.closeSubpath()
        let body = SKShapeNode(path: hull)
        body.fillColor = NSColor(red: 0.85, green: 0.92, blue: 0.96, alpha: 1)
        body.strokeColor = .white; body.lineWidth = 0.12; body.zPosition = 3
        crisp(body); ship.addChild(body)
        let window = SKShapeNode(ellipseOf: CGSize(width: 1.7, height: 1.5))
        window.position = CGPoint(x: 0, y: 1.3)
        window.fillColor = NSColor(red: 0.17, green: 0.49, blue: 0.62, alpha: 1)
        window.strokeColor = NSColor.cyan.withAlphaComponent(0.65); window.lineWidth = 0.12
        window.zPosition = 4; crisp(window); ship.addChild(window)
        let stripe = SKShapeNode(rectOf: CGSize(width: 2.8, height: 0.5))
        stripe.position.y = -0.75; stripe.fillColor = .systemOrange; stripe.strokeColor = .clear
        stripe.zPosition = 4; crisp(stripe); ship.addChild(stripe)
        let legPath = CGMutablePath()
        for sign in [-1.0, 1.0] {
            legPath.move(to: CGPoint(x: sign * 1.1, y: -0.6))
            legPath.addLine(to: CGPoint(x: sign * 2.4, y: -3))
            legPath.addLine(to: CGPoint(x: sign * 3, y: -3))
        }
        legs.path = legPath; legs.strokeColor = .lightGray; legs.lineWidth = 0.28
        crisp(legs); ship.addChild(legs)
        flame.fillColor = NSColor(red: 0.42, green: 0.95, blue: 0.93, alpha: 0.9)
        flame.strokeColor = .white.withAlphaComponent(0.8); flame.lineWidth = 1.04
        let plume = CGMutablePath()
        plume.move(to: .init(x: -0.8, y: 0)); plume.addLine(to: .init(x: 0, y: -1))
        plume.addLine(to: .init(x: 0.8, y: 0)); plume.closeSubpath()
        flame.path = enlarged(plume); flame.position.y = -1.7
        flame.setScale(0.125); ship.addChild(flame)
        for jet in jets {
            let path = CGMutablePath(); path.move(to: .zero); path.addLine(to: .init(x: 1, y: 0))
            jet.path = enlarged(path); jet.strokeColor = .systemCyan; jet.lineWidth = 2.4
            jet.setScale(0.125); ship.addChild(jet)
        }
    }

    private func rebuild(_ mission: Mission) {
        environment.removeAllChildren()
        children.filter { $0.name == "sky" }.forEach { $0.removeFromParent() }
        let sky = SKNode(); sky.name = "sky"; sky.zPosition = -10; addChild(sky)
        for i in 0..<125 {
            let x = Double((i * 7919 + 113) % 10_000) / 10_000 * size.width
            let y = Double((i * 3557 + 799) % 10_000) / 10_000 * size.height
            let star = SKShapeNode(circleOfRadius: i % 9 == 0 ? 1.4 : 0.65)
            star.position = CGPoint(x: x, y: y); star.fillColor = .white.withAlphaComponent(i % 3 == 0 ? 0.48 : 0.18)
            star.strokeColor = .clear; sky.addChild(star)
        }
        let planet = SKShapeNode(circleOfRadius: 53)
        planet.position = CGPoint(x: size.width * 0.85, y: size.height * 0.81)
        planet.fillColor = Palette.planet(mission.accent).withAlphaComponent(0.06)
        planet.strokeColor = Palette.planet(mission.accent).withAlphaComponent(0.14)
        planet.lineWidth = 1; sky.addChild(planet)
        for x in stride(from: -100.0, through: 300, by: 20) {
            line(from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: 240),
                 color: .white.withAlphaComponent(0.035), width: 0.1, parent: environment)
        }
        for y in stride(from: 0.0, through: 240, by: 20) {
            line(from: CGPoint(x: -100, y: y), to: CGPoint(x: 300, y: y),
                 color: .white.withAlphaComponent(0.045), width: 0.1, parent: environment)
            let label = SKLabelNode(fontNamed: "Menlo")
            label.text = "\(Int(y)) m"; label.fontSize = 13.6; label.setScale(0.125); label.fontColor = .gray
            label.position = CGPoint(x: 5, y: y + 1); environment.addChild(label)
        }
        let terrain = SKShapeNode(rect: CGRect(x: -200, y: -200, width: 600, height: 200))
        terrain.fillColor = NSColor(red: 0.09, green: 0.12, blue: 0.17, alpha: 1)
        terrain.strokeColor = .white.withAlphaComponent(0.22); terrain.lineWidth = 0.2
        terrain.zPosition = 3; crisp(terrain); environment.addChild(terrain)
        for i in 0..<50 {
            let rock = SKShapeNode(ellipseOf: CGSize(width: Double(i % 7 + 2), height: 0.9))
            rock.position = CGPoint(x: Double((i * 41) % 260) - 20, y: -Double(i % 9) * 2 - 3)
            rock.fillColor = .black.withAlphaComponent(0.17); rock.strokeColor = .clear; rock.zPosition = 4
            crisp(rock); environment.addChild(rock)
        }
        let pad = SKShapeNode(rect: CGRect(x: mission.padX - mission.padWidth / 2, y: -0.7, width: mission.padWidth, height: 0.7))
        pad.fillColor = Palette.planet(mission.accent); pad.strokeColor = .clear; pad.glowWidth = 0.4
        pad.zPosition = 5; crisp(pad); environment.addChild(pad)
        for side in [-1.0, 1.0] {
            let x = mission.padX + side * mission.padWidth / 2
            line(from: .init(x: x, y: 0), to: .init(x: x, y: 4), color: Palette.planet(mission.accent), width: 0.2, parent: environment)
            let beacon = SKShapeNode(circleOfRadius: 0.45)
            beacon.position = .init(x: x, y: 4.2); beacon.fillColor = Palette.planet(mission.accent)
            beacon.strokeColor = .clear; beacon.glowWidth = 0.7; crisp(beacon); environment.addChild(beacon)
        }
        targetLabel.text = "↓  ZONA DE ATERIZARE"
        targetLabel.fontColor = Palette.planet(mission.accent)
        targetLabel.position = CGPoint(x: mission.padX, y: -7)
        lastMission = mission.id; lastSize = size
    }

    override func update(_ currentTime: TimeInterval) {
        guard let model else { return }
        let frameDT = max(0, currentTime - (lastRenderTime ?? currentTime))
        lastRenderTime = currentTime
        if performanceLog && frameDT > 0 {
            frameDurations.append(frameDT)
            if frameDurations.count == 300 {
                let sorted = frameDurations.sorted()
                print(String(format: "FRAME flying=%d t=%.1f mean=%.2fms p95=%.2fms max=%.2fms", model.paused ? 0 : 1,
                             model.world.elapsed, sorted.reduce(0,+) / 0.3, sorted[284] * 1000, sorted.last! * 1000))
                fflush(stdout); frameDurations.removeAll(keepingCapacity: true)
            }
        }
        model.tick(currentTime)
        let world = model.world
        let resetCamera = model.mission.id != lastMission || world.elapsed == 0
        if model.mission.id != lastMission || lastSize != size { rebuild(model.mission) }
        let position = model.renderedPosition
        let scale = min(size.width / 205, size.height / 118) * model.zoom
        let follow = clamp((model.zoom - 1) / 0.5, 0, 1)
        let centreX = 100 + (clamp(position.x, 65, 145) - 100) * follow
        let centreY = max(48, position.y - 48) * (1 - follow) + max(35, position.y - 8) * follow
        let blend = resetCamera || cameraScale == 0 ? 1 : 1 - exp(-frameDT * 8)
        cameraCentre = cameraCentre + (Vector(centreX, centreY) - cameraCentre) * blend
        cameraScale += (scale - cameraScale) * blend
        space.setScale(cameraScale)
        space.position = CGPoint(x: size.width / 2 - cameraCentre.x * cameraScale, y: size.height / 2 - cameraCentre.y * cameraScale)
        ship.position = .init(x: position.x, y: position.y)
        ship.zRotation = model.renderedAngle
        legs.isHidden = !world.gear
        if world.outcome == .landed {
            if landedAt == nil { landedAt = currentTime }
            let elapsed = currentTime - (landedAt ?? currentTime)
            let compression = sin(min(1, elapsed / 0.65) * .pi) * 0.5
            ship.position.y -= compression
            legs.yScale = 0.125 * (1 - compression / Physics.footHeight)
            ship.zRotation = world.angle * exp(-elapsed * 6)
        } else {
            landedAt = nil; legs.yScale = 0.125
        }
        ship.alpha = world.outcome == .crashed ? 0.45 : 1
        let speedText = String(format: "%.1f m/s", world.velocity.length)
        if shipLabel.text != speedText { shipLabel.text = speedText }
        shipLabel.position = CGPoint(x: position.x, y: position.y + 7)
        let input = model.appliedInput
        let firing = !model.paused && world.fuel > 0 && (input.thrust > 0 || input.boost)
        let length = (0.3 + 8 * input.thrust + (input.boost ? 4 : 0)) * (0.96 + 0.04 * sin(currentTime * 30))
        flame.yScale = 0.125 * length; flame.isHidden = !firing
        let powers = [input.reverse, input.lateralLeft, input.lateralRight, input.rotationLeft, input.rotationRight]
        let origins = [CGPoint(x: 0, y: 3.9), .init(x: 1.6, y: 0), .init(x: -1.6, y: 0),
                       .init(x: 1.4, y: -1.4), .init(x: -1.4, y: -1.4)]
        let angles = [Double.pi / 2, 0, Double.pi, 0, Double.pi]
        for index in jets.indices {
            let amount = max(powers[index], input.brake && (index == 1 || index == 2) ? 0.5 : 0)
            jets[index].isHidden = model.paused || world.fuel <= 0 || amount <= 0
            jets[index].position = origins[index]; jets[index].zRotation = angles[index]
            jets[index].xScale = 0.125 * (0.2 + 4 * amount)
        }
        if world.elapsed < lastTrailTime || world.elapsed == 0 { trailPoints = []; lastTrailTime = -1 }
        if world.elapsed - lastTrailTime > 0.25 {
            trailPoints.append(ship.position); lastTrailTime = world.elapsed
            if trailPoints.count > 250 { trailPoints.removeFirst() }
            let p = CGMutablePath(); p.addLines(between: trailPoints); trail.path = enlarged(p)
        }
        vectors.isHidden = !model.showVectors
        if model.showVectors {
            velocityArrow.update(world.velocity * 0.65, at: ship.position)
            forceArrow.update(world.thrustForce / 1_200, at: ship.position)
            gravityArrow.update(Vector(0, -world.mass * world.gravity / 1_200), at: ship.position)
        }
        if previousOutcome == .flying && world.outcome == .crashed { burst(at: ship.position, time: currentTime) }
        previousOutcome = world.outcome
    }

    private func burst(at point: CGPoint, time: TimeInterval) {
        for i in 0..<22 {
            let dot = SKShapeNode(circleOfRadius: 0.22)
            dot.position = point; dot.fillColor = i % 2 == 0 ? .systemOrange : .systemYellow
            dot.strokeColor = .clear; dot.zPosition = 40; space.addChild(dot)
            let angle = Double(i) * .pi * 2 / 22
            dot.run(.sequence([.group([.moveBy(x: cos(angle) * 12, y: sin(angle) * 12, duration: 0.8),
                                      .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
        }
    }
    private func line(from: CGPoint, to: CGPoint, color: NSColor, width: Double, parent: SKNode) {
        let path = CGMutablePath(); path.move(to: from); path.addLine(to: to)
        let node = SKShapeNode(path: path); node.strokeColor = color; node.lineWidth = width
        crisp(node); parent.addChild(node)
    }
    // Rasterize tiny metre-based geometry at a higher resolution before display scaling.
    private func enlarged(_ path: CGPath) -> CGPath {
        var transform = CGAffineTransform(scaleX: 8, y: 8)
        return path.copy(using: &transform) ?? path
    }
    private func crisp(_ node: SKShapeNode) {
        if let path = node.path { node.path = enlarged(path) }
        node.lineWidth *= 8; node.glowWidth *= 8; node.setScale(0.125)
    }
}

/// Reuse GPU geometry and text; updating a force vector only changes transforms.
private final class VectorArrow: SKNode {
    private let shaft: SKSpriteNode
    private let tip = SKShapeNode()
    private let label = SKLabelNode(fontNamed: "Menlo-Bold")
    init(color: NSColor, text: String) {
        shaft = SKSpriteNode(color: color.withAlphaComponent(0.8), size: .init(width: 1, height: 0.22))
        super.init()
        shaft.anchorPoint = .init(x: 0, y: 0.5); addChild(shaft)
        let path = CGMutablePath(); path.move(to: .init(x: -12, y: 6))
        path.addLine(to: .zero); path.addLine(to: .init(x: -12, y: -6))
        tip.path = path; tip.strokeColor = color; tip.lineWidth = 1.76; tip.setScale(0.125); addChild(tip)
        label.text = text; label.fontSize = 16; label.setScale(0.125); label.fontColor = color; addChild(label)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    func update(_ vector: Vector, at origin: CGPoint) {
        position = origin; isHidden = vector.length <= 0.3
        guard !isHidden else { return }
        let v = vector * min(1, 22 / vector.length)
        shaft.xScale = v.length; shaft.zRotation = atan2(v.y, v.x)
        tip.position = .init(x: v.x, y: v.y); tip.zRotation = shaft.zRotation
        label.position = .init(x: v.x + 2, y: v.y + 1)
    }
}
