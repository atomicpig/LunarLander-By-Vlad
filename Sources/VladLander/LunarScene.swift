import AppKit
import SwiftUI
import SpriteKit
import FlightCore

struct LunarCanvas:NSViewRepresentable {
    let game:LanderModel
    func makeNSView(context:Context) -> SKView {
        let view = SKView(); view.preferredFramesPerSecond = 120; view.ignoresSiblingOrder = true
        let scene = LunarScene(game:game); scene.scaleMode = .resizeFill; view.presentScene(scene); return view
    }
    func updateNSView(_ view:SKView,context:Context) {}
}

private enum Art {
    static let white = NSColor(red:0.86,green:0.93,blue:0.89,alpha:1)
    static let mint = NSColor(red:0.62,green:0.94,blue:0.79,alpha:1)
    static let amber = NSColor(red:1,green:0.68,blue:0.31,alpha:1)
    static func shape(_ points:[Vector],fill:NSColor = .clear,stroke:NSColor = .clear,width:Double = 0.14,close:Bool = false) -> SKShapeNode {
        let p = CGMutablePath(); p.addLines(between:points.map {.init(x:$0.x*8,y:$0.y*8)}); if close {p.closeSubpath()}
        let node = SKShapeNode(path:p); node.fillColor = fill; node.strokeColor = stroke; node.lineWidth = width*8; node.setScale(0.125); return node
    }
    static let glow:SKTexture = {
        let image = NSImage(size:.init(width:48,height:48)); image.lockFocus()
        NSGradient(colors:[NSColor.white,NSColor.white.withAlphaComponent(0.2),NSColor.clear])!
            .draw(in:NSBezierPath(ovalIn:.init(x:0,y:0,width:48,height:48)),relativeCenterPosition:.zero)
        image.unlockFocus(); return SKTexture(image:image)
    }()
}

private final class LunarCraft:SKNode {
    private let legs = [SKShapeNode(),SKShapeNode()]
    private let plumes = (0..<6).map { _ in SKSpriteNode(texture:Art.glow,color:Art.amber,size:.init(width:1,height:1)) }
    private let sparks = SKEmitterNode()
    private var compression = [-1.0,-1.0]
    override init() {
        super.init()
        let shell = Art.shape(Physics.hull,fill:NSColor(red:0.06,green:0.09,blue:0.11,alpha:1),stroke:Art.white,width:0.12,close:true)
        shell.zPosition = 4; addChild(shell)
        let foil = Art.shape([Vector(-1.7,-1.5),Vector(1.7,-1.5),Vector(1.9,-0.2),Vector(-1.9,-0.2)],
                             fill:NSColor(red:0.34,green:0.26,blue:0.13,alpha:1),stroke:Art.amber.withAlphaComponent(0.8),width:0.08,close:true)
        foil.zPosition = 5; addChild(foil)
        let glass = Art.shape([Vector(-0.7,2.1),Vector(0.7,2.1),Vector(1.2,0.8),Vector(-1.2,0.8)],
                              fill:NSColor(red:0.09,green:0.25,blue:0.29,alpha:1),stroke:Art.mint,width:0.09,close:true)
        glass.zPosition = 5; addChild(glass)
        let brace = Art.shape([Vector(-1.1,0.8),Vector(0,1.2),Vector(1.1,0.8)],stroke:Art.white.withAlphaComponent(0.5),width:0.06)
        brace.zPosition = 6; addChild(brace)
        let engine = Art.shape([Vector(-0.6,-1.5),Vector(-0.85,-2.1),Vector(0.85,-2.1),Vector(0.6,-1.5)],fill:.black,stroke:Art.white,width:0.1,close:true)
        engine.zPosition = 6; addChild(engine)
        for leg in legs { leg.strokeColor = Art.white; leg.lineWidth = 1.2; leg.setScale(0.125); addChild(leg) }
        let origins = [Vector(0,-1.9),Vector(0,2.8),Vector(2,0),Vector(-2,0),Vector(1.7,-1.3),Vector(-1.7,-1.3)]
        let angles = [0.0,Double.pi,Double.pi/2,-Double.pi/2,Double.pi/2,-Double.pi/2]
        for i in plumes.indices {
            plumes[i].colorBlendFactor = 1; plumes[i].blendMode = .add; plumes[i].anchorPoint = .init(x:0.5,y:0.82)
            plumes[i].position = .init(x:origins[i].x,y:origins[i].y); plumes[i].zRotation = angles[i]; addChild(plumes[i])
        }
        sparks.particleTexture = Art.glow; sparks.particleColor = Art.amber; sparks.particleColorBlendFactor = 1
        sparks.particleBlendMode = .add; sparks.particleScale = 0.018; sparks.particleScaleRange = 0.01
        sparks.particleLifetime = 0.35; sparks.particleAlpha = 0.7; sparks.particleAlphaSpeed = -1.8
        sparks.particleSpeed = 18; sparks.emissionAngle = -.pi/2; sparks.emissionAngleRange = 0.18
        sparks.position = .init(x:0,y:-2); addChild(sparks)
    }
    required init?(coder:NSCoder) { fatalError() }
    func attachParticles(to node:SKNode) { sparks.targetNode = node }
    func reset() { sparks.resetSimulation() }
    func update(world:World,running:Bool,time:Double) {
        for i in 0..<2 where abs(world.compression[i]-compression[i]) > 0.005 {
            let sign = i == 0 ? -1.0:1.0, y = -3+min(0.9,world.compression[i])
            let p = CGMutablePath()
            for points in [[Vector(sign*1.5,0),Vector(sign*2.6,y),Vector(sign*3.05,y)],
                           [Vector(sign*1.6,-1.3),Vector(sign*2.6,y),Vector(sign*2.15,y)]] {
                p.addLines(between:points.map {.init(x:$0.x*8,y:$0.y*8)})
            }
            legs[i].path = p
        }
        compression = world.compression
        for i in plumes.indices {
            let power = running && world.outcome == .flying ? world.enginePower[i]:0
            plumes[i].isHidden = power <= 0
            plumes[i].size = .init(width:i == 0 ? 2.1:0.8,height:(i == 0 ? 1.5:0.6)+power*(i == 0 ? 7:3))
            plumes[i].alpha = min(1,0.25+power)*Double(0.94+0.06*sin(time*33))
        }
        sparks.particleBirthRate = running && world.outcome == .flying ? world.enginePower[0]*45:0
        sparks.isPaused = !running; alpha = world.outcome == .crashed ? 0.4:1
    }
}

final class LunarScene:SKScene {
    private weak var game:LanderModel?
    private let space = SKNode(), scenery = SKNode(), far = SKNode(), particles = SKNode(), sky = SKNode()
    private let craft = LunarCraft(), trail = SKShapeNode()
    private let reticle = SKShapeNode(circleOfRadius:13)
    private var padLabels:[SKLabelNode] = [], beaconNodes:[SKSpriteNode] = []
    private var sectorNumber = -1, flightID = -1
    private var cameraCentre = Vector(155,150), scale = 0.0, lastTime:Double?
    private var lastSample = -1.0, lastDust = -1.0
    private var points:[CGPoint] = [], previousOutcome = FlightOutcome.flying
    private var backdropSize = CGSize.zero
    private var frameTimes:[Double] = []
    private let profiling = ProcessInfo.processInfo.arguments.contains("--performance-log")
    init(game:LanderModel) {
        self.game = game; super.init(size:.init(width:1280,height:610))
        backgroundColor = NSColor(red:0.021,green:0.033,blue:0.05,alpha:1)
        sky.zPosition = -30; addChild(sky); addChild(space)
        space.addChild(far); far.zPosition = -10; space.addChild(scenery)
        space.addChild(trail); space.addChild(particles); space.addChild(craft)
        craft.zPosition = 10; particles.zPosition = 9; trail.zPosition = 3
        trail.strokeColor = Art.white.withAlphaComponent(0.12); trail.lineWidth = 0.14
        craft.attachParticles(to:particles)
        reticle.strokeColor = Art.mint.withAlphaComponent(0.28); reticle.fillColor = .clear; reticle.lineWidth = 0.8
        reticle.zPosition = 15; addChild(reticle)
    }
    required init?(coder:NSCoder) { fatalError() }
    private func buildSky() {
        sky.removeAllChildren(); backdropSize = size
        for i in 0..<150 {
            let node = SKSpriteNode(color:.white.withAlphaComponent(i%7 == 0 ? 0.6:0.18),size:.init(width:i%11 == 0 ? 1.5:0.8,height:i%11 == 0 ? 1.5:0.8))
            node.position = .init(x:Double((i*7919+117)%10_000)/10_000*size.width,y:Double((i*3571+201)%10_000)/10_000*size.height)
            sky.addChild(node)
        }
        // Small Earth above the horizon. All artwork is original vector geometry.
        let earth = SKShapeNode(circleOfRadius:24); earth.position = .init(x:size.width*0.78,y:size.height*0.72)
        earth.fillColor = NSColor(red:0.12,green:0.24,blue:0.29,alpha:1); earth.strokeColor = Art.mint.withAlphaComponent(0.24); earth.lineWidth = 1
        sky.addChild(earth)
        let shadow = SKShapeNode(circleOfRadius:23); shadow.fillColor = backgroundColor; shadow.strokeColor = .clear
        shadow.position = .init(x:13,y:3); earth.addChild(shadow)
    }
    private func buildTerrain(_ sector:MoonSector) {
        scenery.removeAllChildren(); far.removeAllChildren(); padLabels = []; beaconNodes = []
        let ground = [Vector(-200,-300)]+sector.vertices+[Vector(1400,-300)]
        let fill = Art.shape(ground,fill:NSColor(red:0.064,green:0.084,blue:0.096,alpha:1),close:true)
        scenery.addChild(fill)
        scenery.addChild(Art.shape(sector.vertices,stroke:Art.white.withAlphaComponent(0.8),width:0.4))
        let ridge: [Vector] = stride(from: -500.0, through: 1_700.0, by: 35.0).map { x in
            let broad = 45.0 * sin(x * 0.006 + 2.0)
            let detail = 25.0 * cos(x * 0.023)
            return Vector(x, 60.0 + broad + detail)
        }
        far.addChild(Art.shape([Vector(-500,-300)]+ridge+[Vector(1700,-300)],fill:NSColor(red:0.042,green:0.059,blue:0.075,alpha:1),close:true))
        far.addChild(Art.shape(ridge,stroke:Art.white.withAlphaComponent(0.09),width:0.4))
        for i in 0..<120 {
            let x = Double((i*73)%1200), y = sector.height(at:x)-Double(i%8)*8-9
            let width = Double(2+i%8)*2
            scenery.addChild(Art.shape([Vector(x-width,y),Vector(x,y-0.8),Vector(x+width,y)],stroke:Art.white.withAlphaComponent(0.055),width:0.4))
        }
        for pad in sector.sites {
            scenery.addChild(Art.shape([Vector(pad.left,pad.height),Vector(pad.right,pad.height)],stroke:Art.mint,width:0.8))
            scenery.addChild(Art.shape([Vector(pad.left,pad.height-2),Vector(pad.right,pad.height-2)],stroke:Art.mint.withAlphaComponent(0.25),width:0.4))
            let label = SKLabelNode(fontNamed:"Menlo-Bold"); label.fontColor = Art.mint; label.fontSize = 13
            label.text = "×\(pad.multiplier)"; label.position = .init(x:pad.x,y:pad.height+5); label.zPosition = 6
            scenery.addChild(label); padLabels.append(label)
            for x in [pad.left,pad.right] {
                let light = SKSpriteNode(texture:Art.glow,color:Art.mint,size:.init(width:5,height:5))
                light.colorBlendFactor = 1; light.blendMode = .add; light.position = .init(x:x,y:pad.height+1)
                scenery.addChild(light); beaconNodes.append(light)
            }
            for x in stride(from:pad.left+3,through:pad.right-3,by:6) {
                scenery.addChild(Art.shape([Vector(x,pad.height-3),Vector(x+2,pad.height-5)],stroke:Art.amber.withAlphaComponent(0.22),width:0.5))
            }
        }
        sectorNumber = sector.number
    }
    override func update(_ time:TimeInterval) {
        guard let game else { return }
        let dt = min(0.1,max(0,time-(lastTime ?? time)))
        if profiling, let previous = lastTime {
            frameTimes.append(time-previous)
            if frameTimes.count == 300 {
                let sorted = frameTimes.sorted()
                print(String(format:"FRAME running=%d t=%.1f mean=%.2fms p95=%.2fms max=%.2fms",game.running ? 1:0,game.world.elapsed,sorted.reduce(0,+)/0.3,sorted[284]*1000,sorted.last!*1000)); fflush(stdout)
                frameTimes.removeAll(keepingCapacity:true)
            }
        }
        lastTime = time; game.tick(time)
        if size != backdropSize { buildSky() }
        if sectorNumber != game.sector.number { buildTerrain(game.sector) }
        let reset = game.flightID != flightID
        if reset {
            flightID = game.flightID; points = []; lastSample = -1; lastDust = -1; previousOutcome = .flying
            particles.removeAllChildren(); craft.reset()
        }
        let w = game.world, position = game.renderedPosition, pad = game.currentSite
        let altitude = max(0,position.y-pad.height)
        let usableHeight = max(180,size.height-220)
        var nextScale = min(14,usableHeight/max(28,altitude+7))
        var centre = Vector(position.x+(pad.x-position.x)*0.15,pad.height+(size.height/2-110)/nextScale)
        if !game.autoCamera {
            nextScale = size.height/(230/game.zoom)
            centre = Vector(position.x,position.y-25)
        }
        if game.phase == .title {
            nextScale = size.height/380; centre = Vector(590,145)
        }
        let blend = reset || scale == 0 ? 1:1-exp(-dt*3)
        cameraCentre = cameraCentre+(centre-cameraCentre)*blend; scale += (nextScale-scale)*blend
        space.setScale(scale); space.position = .init(x:size.width/2-cameraCentre.x*scale,y:size.height/2-cameraCentre.y*scale)
        far.position = .init(x:(cameraCentre.x-400)*0.25,y:0)
        for label in padLabels { label.setScale(1/max(0.5,scale)) }
        for beacon in beaconNodes { beacon.alpha = 0.65+0.25*sin(time*2.2) }
        craft.position = .init(x:position.x,y:position.y); craft.zRotation = game.renderedAngle
        craft.update(world:w,running:game.running,time:w.elapsed)
        reticle.position = .init(x:craft.position.x*scale+space.position.x,y:craft.position.y*scale+space.position.y)
        reticle.isHidden = scale > 4 || w.outcome != .flying || game.phase == .title
        if w.elapsed < lastSample { points = []; lastSample = -1 }
        if w.elapsed-lastSample > 0.15 {
            points.append(craft.position); if points.count > 160 { points.removeFirst() }
            let path = CGMutablePath(); path.addLines(between:points); trail.path = path; lastSample = w.elapsed
        }
        if w.outcome != previousOutcome {
            if w.outcome == .crashed { puff(at:craft.position,color:Art.amber,count:35,spread:16) }
            if w.outcome == .settling { puff(at:.init(x:position.x,y:pad.height),color:Art.white,count:18,spread:8) }
        }
        let clearance = position.y-game.sector.height(at:position.x)-3
        if game.running && w.outcome == .flying && clearance < 22 && w.enginePower[0] > 0.03 && w.elapsed-lastDust > 0.1 {
            puff(at:.init(x:position.x,y:game.sector.height(at:position.x)+0.5),color:Art.white,count:2,spread:5)
            lastDust = w.elapsed
        }
        particles.isPaused = !game.running && w.outcome.active
        previousOutcome = w.outcome
    }
    private func puff(at point:CGPoint,color:NSColor,count:Int,spread:Double) {
        for i in 0..<count {
            let p = SKSpriteNode(texture:Art.glow,color:color,size:.init(width:0.8,height:0.8)); p.colorBlendFactor = 1
            p.position = point; p.alpha = 0.55; particles.addChild(p)
            let angle = Double(i)*2.39996
            p.run(.sequence([.group([.moveBy(x:cos(angle)*spread,y:abs(sin(angle))*spread*0.5,duration:0.8),.scale(to:3,duration:0.8),.fadeOut(withDuration:0.8)]),.removeFromParent()]))
        }
    }
}
