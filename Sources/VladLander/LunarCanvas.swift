import AppKit
import SwiftUI
import QuartzCore
import CoreText
import FlightCore

struct LunarCanvas: NSViewRepresentable {
    let game: LanderModel
    func makeNSView(context: Context) -> LunarFlightView { LunarFlightView(game: game) }
    func updateNSView(_ view: LunarFlightView, context: Context) {}
}

enum LunarArt {
    static let ink = NSColor(red:0.018,green:0.032,blue:0.052,alpha:1).cgColor
    static let white = NSColor(red:0.87,green:0.94,blue:0.95,alpha:1).cgColor
    static let mint = NSColor(red:0.45,green:1,blue:0.76,alpha:1).cgColor
    static let amber = NSColor(red:1,green:0.68,blue:0.24,alpha:1).cgColor
    static func color(_ r:Double,_ g:Double,_ b:Double,_ a:Double = 1) -> CGColor {
        CGColor(red:r,green:g,blue:b,alpha:a)
    }
    static func path(_ points:[Vector],close:Bool = false) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between:points.map {CGPoint(x:$0.x,y:$0.y)})
        if close { path.closeSubpath() }; return path
    }
    static func polygon(_ c:CGContext,_ points:[Vector],fill:CGColor?,stroke:CGColor? = nil,width:Double = 0.12) {
        c.addPath(path(points,close:fill != nil))
        c.setLineWidth(width); c.setLineJoin(.round); c.setLineCap(.round)
        if let fill { c.setFillColor(fill) }
        if let stroke { c.setStrokeColor(stroke) }
        c.drawPath(using:fill == nil ? .stroke : (stroke == nil ? .fill : .fillStroke))
    }
    private static var fonts:[String:CTFont] = [:]
    static func font(_ size:Double,bold:Bool) -> CTFont {
        let key = "\(size)-\(bold)"
        if let font = fonts[key] { return font }
        let font = CTFontCreateWithName((bold ? "Menlo-Bold":"Menlo-Regular") as CFString,size,nil)
        fonts[key] = font; return font
    }
    static func text(_ value:String,at point:CGPoint,size:Double,color:NSColor,weight:NSFont.Weight = .medium) {
        guard let c = NSGraphicsContext.current?.cgContext else { return }
        let attributes:[NSAttributedString.Key:Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String):font(size,bold:weight.rawValue >= NSFont.Weight.semibold.rawValue),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):color.cgColor
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string:value,attributes:attributes))
        c.saveGState(); c.textMatrix = .identity
        c.textPosition = .init(x:point.x,y:point.y+size*0.2)
        CTLineDraw(line,c); c.restoreGState()
    }
    static let terrainGradient = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[color(0.025,0.047,0.071),color(0.12,0.17,0.20),color(0.24,0.29,0.30)] as CFArray,locations:[0,0.75,1])!
    static let earthGradient = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[color(0.04,0.12,0.23),color(0.12,0.49,0.67),color(0.47,0.82,0.88)] as CFArray,locations:[0,0.65,1])!
    static let skyGradient = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[color(0.04,0.075,0.12),ink] as CFArray,locations:[0,1])!
}

/// The simulation clock runs in common run-loop modes, including mouse tracking.
/// Drawing uses a regular AppKit backing layer, with no blocking Metal drawable
/// acquisition and no SpriteKit callbacks that can re-enter SwiftUI layout.
final class LunarFlightView: NSView {
    let game: LanderModel
    private lazy var cockpit = NativeCockpit(view:self,game:game)
    var flightBounds: CGRect { .init(x:0,y:0,width:bounds.width,height:max(200,bounds.height-176)) }
    private var timer: Timer?
    private var previousTime: Double?
    private var cameraCentre = Vector(155,150)
    private var scale = 1.0
    private var flightID = -1
    private var lastOutcome = FlightOutcome.flying
    private var dustRemainder = 0.0
    private var particles: [Particle] = []
    private var seed: UInt64 = 71
    private var frameIntervals: [Double] = []
    private var drawCosts: [Double] = []
    private var lastDraw: Double?
    private let profiling = ProcessInfo.processInfo.arguments.contains("--performance-log")
    private let benchmarking = ProcessInfo.processInfo.arguments.contains("--render-benchmark")
    private var benchmarkStart: Double?
    private var benchmarkAction = -1
    struct Particle { var p:Vector; var v:Vector; var life:Double; var initial:Double; var hot:Bool }

    init(game:LanderModel) {
        self.game = game
        super.init(frame:.init(x:0,y:0,width:1280,height:610))
        wantsLayer = true
        layer?.backgroundColor = LunarArt.ink
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        setAccessibilityElement(false)
        cockpit.install()
    }
    required init?(coder:NSCoder) { fatalError() }
    override var isOpaque:Bool { true }
    override var acceptsFirstResponder:Bool { false }
    override func layout() { super.layout(); cockpit.layout() }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate(); timer = nil; previousTime = nil
        guard window != nil else { return }
        let timer = Timer(timeInterval:1.0/120,repeats:true) { [weak self] _ in self?.frame() }
        timer.tolerance = 0.001
        RunLoop.main.add(timer,forMode:.common)
        self.timer = timer
    }
    deinit { timer?.invalidate() }
    private func frame() {
        let now = CACurrentMediaTime(), dt = min(0.1,max(0,now-(previousTime ?? now)))
        previousTime = now
        if benchmarking { benchmark(at:now) }
        game.tick(now)
        updateCamera(dt:dt)
        updateParticles(dt:dt)
        cockpit.refresh()
        needsDisplay = true
    }
    // Opt-in integration benchmark exercises the same model actions as the
    // cockpit without accessibility polling or synthetic OS input events.
    private func benchmark(at time:Double) {
        if benchmarkStart == nil {
            benchmarkStart = time; game.newGame(); game.togglePause()
            game.world.position = Vector(260,400); game.world.velocity = Vector()
        }
        let elapsed = time-benchmarkStart!
        let action = Int(elapsed*10)
        if action != benchmarkAction {
            benchmarkAction = action
            game.damping.toggle()
            game.setPrecision(action%2 == 0 ? 0.2:1)
            game.setMuted(action%3 == 0)
            game.setEngine(0,action%2 == 0 ? 0.10:0.12)
            if action%10 == 0 { game.fire((action/10)%7) }
        }
        if elapsed >= 20 {
            print("BENCHMARK complete actions=\(benchmarkAction+1) simulation=\(game.world.elapsed)"); fflush(stdout)
            NSApp.terminate(nil)
        }
    }
    private func updateCamera(dt:Double) {
        let w = game.world, position = game.renderedPosition, pad = game.currentSite
        let reset = flightID != game.flightID
        if reset { flightID = game.flightID; particles.removeAll(keepingCapacity:true); lastOutcome = .flying }
        let available = max(180,flightBounds.height-220)
        var nextScale = min(14,available/max(32,position.y-pad.height+7))
        var centre = Vector(position.x+(pad.x-position.x)*0.1,pad.height+(flightBounds.height/2-110)/nextScale)
        if !game.autoCamera { nextScale = flightBounds.height/(210/game.zoom); centre = Vector(position.x,position.y-20) }
        if game.phase == .title { nextScale = min(flightBounds.width/1_240,flightBounds.height/310); centre = Vector(590,115) }
        let blend = reset ? 1 : 1-exp(-dt*9)
        cameraCentre = cameraCentre+(centre-cameraCentre)*blend
        scale += (nextScale-scale)*(reset ? 1 : 1-exp(-dt*7))
        if !w.outcome.active { scale += (nextScale-scale)*blend }
    }
    private func random() -> Double {
        seed = seed &* 6364136223846793005 &+ 1
        return Double((seed >> 32)&0xFFFFFF)/Double(0xFFFFFF)
    }
    private func updateParticles(dt:Double) {
        let w = game.world
        let evolving = game.running || !w.outcome.active
        guard evolving else { return }
        for i in particles.indices {
            particles[i].p = particles[i].p+particles[i].v*dt
            particles[i].v.y -= dt*0.8
            particles[i].life -= dt
        }
        particles.removeAll {$0.life <= 0}
        let ground = game.sector.height(at:w.position.x)
        if game.running && w.position.y-ground < 30 && w.enginePower[0]>0.04 {
            dustRemainder += dt*min(2,w.enginePower[0])*45
            while dustRemainder >= 1 {
                dustRemainder -= 1
                let speed = 5+random()*15
                particles.append(.init(p:Vector(w.position.x+(random()-0.5)*3,ground+0.1),v:Vector((random()<0.5 ? -1:1)*speed,random()*4),life:1.2,initial:1.2,hot:false))
            }
        }
        if w.outcome != lastOutcome {
            if w.outcome == .crashed || w.outcome == .settling {
                let crash = w.outcome == .crashed
                for _ in 0..<(crash ? 65:24) {
                    let a = random()*Double.pi*2, speed = (crash ? 16.0:7.0)*(0.2+random())
                    let life = 0.5+random()*1.3
                    particles.append(.init(p:w.position+Vector(0,crash ? 0:-3),v:Vector(cos(a)*speed,abs(sin(a))*speed),life:life,initial:life,hot:crash))
                }
            }
            lastOutcome = w.outcome
        }
        if particles.count > 200 { particles.removeFirst(particles.count-200) }
    }
    private func point(_ p:Vector) -> CGPoint {
        .init(x:flightBounds.midX+(p.x-cameraCentre.x)*scale,y:flightBounds.midY+(p.y-cameraCentre.y)*scale)
    }
    override func draw(_ dirtyRect:NSRect) {
        guard let c = NSGraphicsContext.current?.cgContext else { return }
        let start = CACurrentMediaTime()
        c.setFillColor(LunarArt.ink); c.fill(bounds)
        c.saveGState(); c.translateBy(x:0,y:120); c.clip(to:flightBounds)
        c.drawLinearGradient(LunarArt.skyGradient,start:.init(x:0,y:0),end:.init(x:0,y:flightBounds.height),options:[])
        drawSky(c)
        drawTerrain(c)
        drawParticles(c)
        drawCraft(c)
        c.restoreGState()
        cockpit.draw(c)
        if profiling {
            if let lastDraw { frameIntervals.append(start-lastDraw) }
            lastDraw = start; drawCosts.append(CACurrentMediaTime()-start)
            if frameIntervals.count >= 300 {
                let ordered = frameIntervals.sorted(), costs = drawCosts.sorted()
                print(String(format:"NATIVE running=%d t=%.1f frames=%d mean=%.2fms p95=%.2fms max=%.2fms drawP95=%.2fms",game.running ? 1:0,game.world.elapsed,ordered.count,ordered.reduce(0,+)/Double(ordered.count)*1000,ordered[Int(Double(ordered.count)*0.95)]*1000,ordered.last!*1000,costs[Int(Double(costs.count)*0.95)]*1000)); fflush(stdout)
                frameIntervals.removeAll(keepingCapacity:true); drawCosts.removeAll(keepingCapacity:true)
            }
        }
    }
    private func drawSky(_ c:CGContext) {
        for i in 0..<180 {
            let x = Double((i*7919+117)%10000)/10000*flightBounds.width
            let y = Double((i*3571+201)%10000)/10000*flightBounds.height
            let r = i%19 == 0 ? 1.1:0.6
            c.setFillColor(LunarArt.color(0.72,0.84,1,i%7 == 0 ? 0.65:0.22))
            c.fillEllipse(in:.init(x:x,y:y,width:r*2,height:r*2))
        }
        let earth = CGRect(x:flightBounds.width*0.80,y:flightBounds.height*0.69,width:70,height:70)
        c.saveGState()
        c.setShadow(offset:.zero,blur:22,color:LunarArt.color(0.18,0.65,1,0.22))
        c.setFillColor(LunarArt.color(0.17,0.49,0.66)); c.fillEllipse(in:earth)
        c.setShadow(offset:.zero,blur:0,color:nil)
        c.addEllipse(in:earth); c.clip()
        c.drawLinearGradient(LunarArt.earthGradient,start:earth.origin,end:.init(x:earth.maxX,y:earth.maxY),options:[])
        c.translateBy(x:earth.minX,y:earth.minY); c.scaleBy(x:70,y:70)
        LunarArt.polygon(c,[Vector(0.1,0.7),Vector(0.26,0.82),Vector(0.45,0.76),Vector(0.38,0.64),Vector(0.54,0.52),Vector(0.40,0.35),Vector(0.31,0.39),Vector(0.27,0.55),Vector(0.16,0.58)],fill:LunarArt.color(0.52,0.69,0.56,0.9))
        LunarArt.polygon(c,[Vector(0.61,0.29),Vector(0.78,0.48),Vector(0.93,0.46),Vector(0.96,0.25),Vector(0.75,0.16)],fill:LunarArt.color(0.59,0.72,0.60,0.7))
        for i in 0..<4 {
            let y = Double(i)*0.21+0.1
            LunarArt.polygon(c,[Vector(-0.1,y),Vector(0.3,y+0.07),Vector(0.65,y+0.05),Vector(1.1,y+0.15)],fill:nil,stroke:LunarArt.color(0.9,0.97,1,0.4),width:0.035)
        }
        c.setFillColor(LunarArt.color(0.005,0.018,0.035,0.93)); c.fillEllipse(in:.init(x:0.24,y:-0.04,width:0.97,height:1.09))
        c.restoreGState()
    }
    private func drawTerrain(_ c:CGContext) {
        let sector = game.sector
        let terrain = sector.vertices.map {p -> Vector in let q = point(p); return Vector(q.x,q.y)}
        let floor = -max(100,flightBounds.height*2)
        let polygon = [Vector(terrain.first!.x,floor)]+terrain+[Vector(terrain.last!.x,floor)]
        // A distant silhouette provides depth without obscuring collision terrain.
        let distant:[Vector] = stride(from:-300.0,through:1500.0,by:28.0).map {x in
            let y = 52+27*sin(x*0.007+1.2)+18*cos(x*0.019)
            let p = point(Vector(x+(cameraCentre.x-500)*0.16,y))
            return Vector(p.x,p.y)
        }
        LunarArt.polygon(c,[Vector(-100,floor)]+distant+[Vector(flightBounds.width+100,floor)],fill:LunarArt.color(0.06,0.10,0.15),stroke:LunarArt.color(0.23,0.35,0.46,0.5),width:1)
        c.saveGState(); c.addPath(LunarArt.path(polygon,close:true)); c.clip()
        c.drawLinearGradient(LunarArt.terrainGradient,start:.init(x:0,y:0),end:.init(x:0,y:flightBounds.height),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
        for i in 0..<(terrain.count-1) {
            let a = terrain[i], b = terrain[i+1]
            guard max(a.x,b.x)>0 && min(a.x,b.x)<flightBounds.width else { continue }
            let depth = (18+Double(i%7)*6)*scale
            LunarArt.polygon(c,[a,b,Vector((a.x+b.x)/2+Double(i%3-1)*8*scale,min(a.y,b.y)-depth)],fill:LunarArt.color(0.65,0.77,0.8,i%2 == 0 ? 0.065:0.022))
            if i%3 == 0 {
                LunarArt.polygon(c,[a,Vector(a.x+9*scale,a.y-26*scale),Vector(a.x+6*scale,a.y-40*scale)],fill:nil,stroke:LunarArt.color(0,0.015,0.025,0.38),width:1)
            }
        }
        for i in 0..<95 {
            let x = Double((i*113+21)%1200), y = sector.height(at:x)-12-Double(i%9)*8
            let p = point(Vector(x,y)), r = Double(2+i%6)*scale
            guard p.x+r>0 && p.x-r<flightBounds.width && p.y+r>0 && p.y-r<flightBounds.height else { continue }
            let oval = CGRect(x:p.x-r,y:p.y-r*0.26,width:2*r,height:r*0.52)
            c.setFillColor(LunarArt.color(0,0.02,0.04,0.15)); c.fillEllipse(in:oval)
            c.setStrokeColor(LunarArt.color(0.5,0.62,0.65,0.13)); c.setLineWidth(0.8); c.strokeEllipse(in:oval.offsetBy(dx:0,dy:-1))
        }
        c.restoreGState()
        LunarArt.polygon(c,terrain,fill:nil,stroke:LunarArt.color(0.73,0.87,0.89,0.8),width:1.3)
        for pad in sector.sites {
            let a = point(Vector(pad.left,pad.height)), b = point(Vector(pad.right,pad.height))
            guard b.x > -60 && a.x < flightBounds.width+60 else { continue }
            c.saveGState()
            c.setShadow(offset:.zero,blur:9,color:LunarArt.color(0.3,1,0.65,0.7))
            LunarArt.polygon(c,[Vector(a.x,a.y),Vector(b.x,b.y)],fill:nil,stroke:LunarArt.mint,width:2.2)
            c.restoreGState()
            c.setFillColor(LunarArt.color(0.4,0.9,0.67,0.1)); c.fill(.init(x:a.x,y:a.y-7,width:b.x-a.x,height:7))
            for x in stride(from:a.x+6,through:b.x-4,by:13) {
                LunarArt.polygon(c,[Vector(x,a.y-9),Vector(x+5,a.y-14)],fill:nil,stroke:LunarArt.color(0.95,0.62,0.26,0.34),width:1)
            }
            for x in [a.x,b.x] {
                LunarArt.polygon(c,[Vector(x,a.y),Vector(x,a.y+7)],fill:nil,stroke:LunarArt.mint,width:1)
                c.setFillColor(LunarArt.mint); c.fillEllipse(in:.init(x:x-2,y:a.y+6,width:4,height:3))
            }
            let label = "×\(pad.multiplier)"
            LunarArt.text(label,at:.init(x:(a.x+b.x)/2-11,y:a.y+12),size:15,color:NSColor(cgColor:LunarArt.mint)!,weight:.bold)
        }
    }
    private func drawParticles(_ c:CGContext) {
        for particle in particles {
            let p = point(particle.p), alpha = clamp(particle.life/particle.initial,0,1)
            let size = min(8,max(1.5,scale*(particle.hot ? 0.22:0.18)))
            c.setFillColor(particle.hot ? LunarArt.color(1,0.45+alpha*0.4,0.22,alpha) : LunarArt.color(0.7,0.78,0.8,alpha*0.4))
            c.fillEllipse(in:.init(x:p.x-size/2,y:p.y-size/2,width:size,height:size))
        }
    }
    private func drawCraft(_ c:CGContext) {
        let w = game.world, p = point(game.renderedPosition)
        let clearance = max(0,Physics.clearance(w,sector:game.sector))
        let legibility = 1+clamp((clearance-22)/80,0,1)*0.8
        let craftScale = scale*legibility
        let running = game.running && w.outcome == .flying
        c.saveGState(); c.translateBy(x:p.x,y:p.y); c.rotate(by:game.renderedAngle); c.scaleBy(x:craftScale,y:craftScale)
        if w.outcome == .crashed { c.setAlpha(0.35) }
        if running {
            let origins = [Vector(0,-1.9),Vector(0,2.7),Vector(1.9,-0.15),Vector(-1.9,-0.15),Vector(1.65,-1),Vector(-1.65,-1)]
            let directions = [0.0,Double.pi,Double.pi/2,-Double.pi/2,Double.pi/2,-Double.pi/2]
            for i in 0..<6 where w.enginePower[i]>0.001 {
                c.saveGState(); c.translateBy(x:origins[i].x,y:origins[i].y); c.rotate(by:directions[i])
                let pulse = 0.92+0.08*sin(w.elapsed*103+Double(i)*2), power = w.enginePower[i]
                let length = (i == 0 ? 1.6:0.7)+min(2.6,power)*(i == 0 ? 6:2.5)*pulse
                let width = i == 0 ? 0.75:0.22
                LunarArt.polygon(c,[Vector(-width,0),Vector(-width*0.8,-length*0.6),Vector(0,-length),Vector(width*0.8,-length*0.6),Vector(width,0)],fill:LunarArt.color(1,0.37,0.06,0.55))
                LunarArt.polygon(c,[Vector(-width*0.7,0),Vector(0,-length*0.84),Vector(width*0.7,0)],fill:LunarArt.color(1,0.77,0.32,0.95))
                LunarArt.polygon(c,[Vector(-width*0.38,0),Vector(0,-length*0.45),Vector(width*0.38,0)],fill:LunarArt.color(0.94,0.99,1))
                c.restoreGState()
            }
        }
        // Landing struts use the same feet and suspension compression as physics.
        for i in 0..<2 {
            let sign = i == 0 ? -1.0:1.0, y = -3+min(0.9,w.compression[i])
            LunarArt.polygon(c,[Vector(sign*1.3,0.5),Vector(sign*2.6,y),Vector(sign*1.4,-1.3)],fill:nil,stroke:LunarArt.white,width:0.16)
            LunarArt.polygon(c,[Vector(sign*1.55,-0.3),Vector(sign*2.4,y+0.35)],fill:nil,stroke:LunarArt.color(0.72,0.5,0.25),width:0.18)
            LunarArt.polygon(c,[Vector(sign*2.1,y),Vector(sign*3.1,y)],fill:nil,stroke:LunarArt.white,width:0.22)
        }
        LunarArt.polygon(c,Physics.hull,fill:LunarArt.color(0.20,0.28,0.33),stroke:LunarArt.white,width:0.12)
        LunarArt.polygon(c,[Vector(-1.7,-1.5),Vector(1.7,-1.5),Vector(1.9,-0.15),Vector(-1.9,-0.15)],fill:LunarArt.color(0.57,0.38,0.13),stroke:LunarArt.amber,width:0.1)
        for i in 0..<6 {
            let x = -1.65+Double(i)*0.55
            LunarArt.polygon(c,[Vector(x,-0.2),Vector(x+0.55,-1.45),Vector(x,-1.1)],fill:LunarArt.color(1,0.77,0.36,i%2 == 0 ? 0.6:0.25))
        }
        LunarArt.polygon(c,[Vector(-0.6,-1.5),Vector(-0.83,-2.07),Vector(0.83,-2.07),Vector(0.6,-1.5)],fill:LunarArt.color(0.07,0.10,0.12),stroke:LunarArt.white,width:0.1)
        LunarArt.polygon(c,[Vector(-0.76,2.1),Vector(-0.14,2.1),Vector(-0.14,0.79),Vector(-1.22,0.79)],fill:LunarArt.color(0.05,0.19,0.26),stroke:LunarArt.color(0.54,0.84,0.93),width:0.09)
        LunarArt.polygon(c,[Vector(0.76,2.1),Vector(0.14,2.1),Vector(0.14,0.79),Vector(1.22,0.79)],fill:LunarArt.color(0.16,0.40,0.48),stroke:LunarArt.white,width:0.09)
        LunarArt.polygon(c,[Vector(0.31,1.89),Vector(0.63,1.89),Vector(0.97,1.12)],fill:nil,stroke:LunarArt.color(0.7,0.96,1,0.8),width:0.08)
        LunarArt.polygon(c,[Vector(-0.5,2.8),Vector(-0.5,3.8),Vector(-1,3.8),Vector(0,3.8)],fill:nil,stroke:LunarArt.white,width:0.08)
        c.setFillColor(LunarArt.mint); c.fillEllipse(in:.init(x:1.58,y:0.23,width:0.23,height:0.23))
        c.restoreGState()
        if game.phase != .title && clearance > 28 && w.outcome.active {
            c.setStrokeColor(LunarArt.color(0.45,1,0.76,0.28)); c.setLineWidth(0.8)
            let r = max(18,craftScale*4.4)
            for sign in [-1.0,1.0] {
                LunarArt.polygon(c,[Vector(p.x+sign*(r-5),p.y+r),Vector(p.x+sign*r,p.y+r),Vector(p.x+sign*r,p.y+r-5)],fill:nil,stroke:LunarArt.color(0.45,1,0.76,0.28),width:0.8)
                LunarArt.polygon(c,[Vector(p.x+sign*(r-5),p.y-r),Vector(p.x+sign*r,p.y-r),Vector(p.x+sign*r,p.y-r+5)],fill:nil,stroke:LunarArt.color(0.45,1,0.76,0.28),width:0.8)
            }
        }
    }
}
