import Foundation

public struct Vector: Codable, Equatable {
    public var x: Double
    public var y: Double
    public init(_ x: Double = 0, _ y: Double = 0) { self.x = x; self.y = y }
    public var length: Double { hypot(x, y) }
    public static func + (a: Self, b: Self) -> Self { .init(a.x + b.x, a.y + b.y) }
    public static func - (a: Self, b: Self) -> Self { .init(a.x - b.x, a.y - b.y) }
    public static func * (a: Self, b: Double) -> Self { .init(a.x * b, a.y * b) }
    public static func / (a: Self, b: Double) -> Self { .init(a.x / b, a.y / b) }
    public func rotated(_ angle: Double) -> Self { .init(x*cos(angle)-y*sin(angle),x*sin(angle)+y*cos(angle)) }
}
public func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double { min(high, max(low, value)) }

public struct LandingSite: Identifiable, Equatable {
    public let id: Int
    public let x, height, width: Double
    public let multiplier: Int
    public var left: Double { x - width/2 }
    public var right: Double { x + width/2 }
}

public struct MoonSector {
    public let number: Int
    public let vertices: [Vector]
    public let sites: [LandingSite]
    public let width = 1_200.0
    public let start: Vector
    public init(number: Int = 1) {
        self.number = max(1,number)
        let n = Double(max(1,number)-1), shrink = max(0.68,1-n*0.04)
        sites = [LandingSite(id:0,x:260,height:35,width:80*shrink,multiplier:1),
                 LandingSite(id:1,x:620,height:72,width:40*shrink,multiplier:3),
                 LandingSite(id:2,x:990,height:42,width:23*shrink,multiplier:5)]
        start = Vector(155,190)
        func ridge(_ x:Double) -> Double {
            55 + 37*sin(x*0.008+n*0.43) + 21*cos(x*0.031+n*0.8) + 13*sin(x*0.057)
        }
        var points: [Vector] = []
        for x in stride(from:0.0,through:1_200,by:24) {
            if !sites.contains(where:{x > $0.left-22 && x < $0.right+22}) {
                points.append(Vector(x,max(8,ridge(x))))
            }
        }
        for site in sites { points += [Vector(site.left,site.height),Vector(site.right,site.height)] }
        vertices = points.sorted { $0.x < $1.x }
    }
    public func height(at x:Double) -> Double {
        if x <= vertices[0].x { return vertices[0].y }
        if x >= vertices.last!.x { return vertices.last!.y }
        var lower = 0, upper = vertices.count-1
        while upper-lower > 1 {
            let middle = (lower+upper)/2
            if vertices[middle].x <= x { lower = middle } else { upper = middle }
        }
        let a = vertices[lower], b = vertices[upper]
        return a.y+(b.y-a.y)*(x-a.x)/(b.x-a.x)
    }
    public func nearestSite(to x:Double) -> LandingSite { sites.min { abs($0.x-x) < abs($1.x-x) }! }
}

public struct FlightInput {
    public var thrust = 0.0, reverse = 0.0, lateralLeft = 0.0, lateralRight = 0.0
    public var rotationLeft = 0.0, rotationRight = 0.0, turn = 0.0
    public var bursts = [Double](repeating:0,count:6)
    public var brake = false, boost = false, stabilize = true
    public init() {}
}
public enum FlightOutcome: String { case flying, settling, landed, crashed, escaped
    public var active:Bool { self == .flying || self == .settling }
}
public struct Touchdown {
    public let vx, vy, angle, rotation, fuel, energy:Double
    public let site:LandingSite?
    public var soft:Bool { vy <= 2 && vx <= 0.8 && angle <= 5 * .pi/180 }
    public var points:Int {
        guard let site else { return 0 }
        let quality = 1-clamp(vy/6,0,1)
        return Int((250+quality*500+clamp(fuel/250,0,1)*250).rounded())*site.multiplier
    }
}
public struct World {
    public var position:Vector
    public var velocity = Vector(), acceleration = Vector(), thrustForce = Vector()
    public var angle = 0.0, angularVelocity = 0.0
    public var fuel:Double
    public let dryMass = 1_000.0
    public let gravity = 1.62
    public var elapsed = 0.0, contactTime = 0.0
    public var compression = [0.0,0.0]
    public var enginePower = [Double](repeating:0,count:6)
    public var outcome = FlightOutcome.flying
    public var detail = ""
    public var touchdown:Touchdown?
    public var mass:Double { dryMass+fuel }
    public var kineticEnergy:Double { 0.5*mass*velocity.length*velocity.length }
    public init(sector:MoonSector = .init(),fuel:Double = 250) {
        position = sector.start; self.fuel = fuel
        velocity = Vector(4,-1)
    }
}

/// Each rising pad edge fires one finite pulse. Note-off cannot latch thrust.
public struct BurstBank {
    public private(set) var remaining = [Double](repeating:0,count:7)
    public init() {}
    public mutating func fire(_ index:Int) {
        guard remaining.indices.contains(index) else { return }
        remaining[index] = index == 6 ? 0.55 : 0.24
    }
    public mutating func clear() { remaining = [Double](repeating:0,count:7) }
    public mutating func apply(to input:inout FlightInput,dt:Double) {
        for i in remaining.indices {
            let fraction = clamp(remaining[i]/dt,0,1)
            if i < 6 { input.bursts[i] = fraction*1.6 } else { input.brake = remaining[i] > 0 }
            remaining[i] = max(0,remaining[i]-dt)
        }
    }
}

public enum Physics {
    public static let step = 1.0/120.0
    public static let mainForce = 18_000.0, reverseForce = 6_000.0, sideForce = 4_000.0, turnTorque = 5_000.0
    public static let feet = [Vector(-2.6,-3),Vector(2.6,-3)]
    public static let hull = [Vector(-1.7,-1.5),Vector(1.7,-1.5),Vector(2,0.8),Vector(0.9,2.8),Vector(-0.9,2.8),Vector(-2,0.8)]
    public static func clearance(_ world:World,sector:MoonSector) -> Double {
        (feet+hull).map { let p = world.position+$0.rotated(world.angle); return p.y-sector.height(at:p.x) }.min()!
    }
    public static func padUnderFeet(_ world:World,sector:MoonSector) -> LandingSite? {
        let points = feet.map {world.position+$0.rotated(world.angle)}
        return sector.sites.first { site in points.allSatisfy {$0.x-0.4 >= site.left && $0.x+0.4 <= site.right} }
    }
    public static func advance(_ w:inout World,input:FlightInput,sector:MoonSector,dt:Double = step) {
        guard dt > 0 && dt.isFinite && w.outcome.active else { return }
        if w.outcome == .settling { settle(&w,sector:sector,dt:dt); return }
        let old = w, mass = w.mass
        let commands = [input.thrust,input.reverse,input.lateralLeft,input.lateralRight,input.rotationLeft,input.rotationRight]
        let p = commands.enumerated().map { clamp($0.element,0,1)+clamp(input.bursts[$0.offset],0,1.6) }
        let up = Vector(0,1).rotated(w.angle), right = Vector(1,0).rotated(w.angle)
        var force = up*(p[0]*mainForce-p[1]*reverseForce)+right*((p[3]-p[2])*sideForce)
        var cost = p[0]*mainForce+p[1]*reverseForce+(p[2]+p[3])*sideForce
        var torque = (p[4]-p[5]+input.turn)*turnTorque
        var torqueCost = (p[4]+p[5]+abs(input.turn))*turnTorque
        var visiblePower = p
        visiblePower[input.turn >= 0 ? 4 : 5] += abs(input.turn)
        if input.stabilize {
            // Rate damping makes small dial corrections controllable. The craft
            // keeps its chosen attitude: this is not an automatic upright pilot.
            let damping = clamp(-w.angularVelocity*9_000,-6_500,6_500)
            torque += damping; torqueCost += abs(damping)
            visiblePower[damping >= 0 ? 4 : 5] += abs(damping)/turnTorque
        }
        if input.brake {
            let wanted = w.velocity*(-mass*2.6)
            let braking = wanted*min(1,22_000/max(1,wanted.length))
            force = force+braking; cost += braking.length
            let local = braking.rotated(-w.angle)
            visiblePower[local.y >= 0 ? 0 : 1] += abs(local.y)/(local.y >= 0 ? mainForce : reverseForce)
            visiblePower[local.x >= 0 ? 3 : 2] += abs(local.x)/sideForce
        }
        let fuelNeeded = (cost+torqueCost/2)*dt/2_200
        let available = fuelNeeded > 0 ? min(1,w.fuel/fuelNeeded) : 0
        w.fuel = max(0,w.fuel-fuelNeeded*available)
        force = force*available; torque *= available
        w.enginePower = visiblePower.map {$0*available}; w.thrustForce = force
        w.acceleration = force/mass+Vector(0,-w.gravity)
        w.position = w.position+w.velocity*dt+w.acceleration*(0.5*dt*dt)
        w.velocity = w.velocity+w.acceleration*dt
        let angular = torque/(mass*4)
        w.angle += w.angularVelocity*dt+0.5*angular*dt*dt
        w.angularVelocity += angular*dt
        w.angle = atan2(sin(w.angle),cos(w.angle)); w.elapsed += dt
        contact(&w,previous:old,sector:sector)
        if w.outcome == .flying && (w.position.x < -20 || w.position.x > sector.width+20 || w.position.y > 800) {
            w.outcome = .escaped; w.detail = "Ai părăsit sectorul. Frânează înainte de marginea hărții."
        }
    }
    private static func contact(_ w:inout World,previous:World,sector:MoonSector) {
        // The highest terrain is below 130 m; skip contact work in open space.
        if min(w.position.y,previous.position.y) > 140 { return }
        let turn = atan2(sin(w.angle-previous.angle),cos(w.angle-previous.angle))
        func at(_ fraction:Double) -> World {
            var point = previous
            point.position = previous.position+(w.position-previous.position)*fraction
            point.angle = previous.angle+turn*fraction; return point
        }
        let samples = min(512,max(1,Int(ceil((w.position-previous.position).length/1.5))))
        var low = 0.0, high:Double?
        for i in 1...samples {
            let f = Double(i)/Double(samples)
            if clearance(at(f),sector:sector) <= 0 { high = f; break }; low = f
        }
        guard var hit = high else { return }
        for _ in 0..<20 {
            let middle = (low+hit)/2
            if clearance(at(middle),sector:sector) > 0 { low = middle } else { hit = middle }
        }
        w.position = previous.position+(w.position-previous.position)*hit
        w.angle = previous.angle+turn*hit
        w.velocity = previous.velocity+(w.velocity-previous.velocity)*hit
        w.angularVelocity = previous.angularVelocity+(w.angularVelocity-previous.angularVelocity)*hit
        let site = padUnderFeet(w,sector:sector)
        let bodyHit = hull.contains { p in let v = w.position+p.rotated(w.angle); return v.y-sector.height(at:v.x) <= 1e-5 }
        w.touchdown = Touchdown(vx:abs(w.velocity.x),vy:abs(w.velocity.y),angle:abs(w.angle),rotation:abs(w.angularVelocity),fuel:w.fuel,energy:w.kineticEnergy,site:site)
        let speedOK = abs(w.velocity.x) <= 3+1e-8 && abs(w.velocity.y) <= 6+1e-8
        let angleOK = abs(w.angle) <= 15 * .pi/180+1e-8 && abs(w.angularVelocity) <= 0.5
        if site != nil && !bodyHit && speedOK && angleOK {
            w.outcome = .settling; w.contactTime = 0
        } else {
            w.outcome = .crashed
            if bodyHit { w.detail = "Carena a lovit solul. Aterizează pe cele două picioare." }
            else if site == nil { w.detail = "Relieful nu este o pistă. Caută o zonă luminată ×1, ×3 sau ×5." }
            else if !speedOK { w.detail = "Impact prea rapid. Frânează mai devreme; folosește impulsul Pad 1 sau Pad 7." }
            else { w.detail = "Prea multă înclinare sau rotație la contact. Corectează cu K5 / K6." }
        }
    }
    private static func settle(_ w:inout World,sector:MoonSector,dt:Double) {
        guard let site = w.touchdown?.site else { return }
        let mass = w.mass, spring = mass*180, damping = 2*sqrt(spring*mass/2)*0.9
        var support = Vector(), torque = 0.0
        for (i,foot) in feet.enumerated() {
            let lever = foot.rotated(w.angle), point = w.position+lever
            let clearance = point.y-site.height
            let v = w.velocity+Vector(-w.angularVelocity*lever.y,w.angularVelocity*lever.x)
            let normal = clearance < 0.0001 ? max(0,-spring*clearance-damping*v.y) : 0
            let force = Vector(clamp(-v.x*mass*5,-normal*0.8,normal*0.8),normal)
            w.compression[i] = max(0,-clearance); support = support+force
            torque += lever.x*force.y-lever.y*force.x
        }
        w.enginePower = [Double](repeating:0,count:6); w.thrustForce = Vector()
        w.acceleration = support/mass+Vector(0,-w.gravity)
        w.position = w.position+w.velocity*dt+w.acceleration*(0.5*dt*dt)
        w.velocity = w.velocity+w.acceleration*dt
        w.angle += w.angularVelocity*dt+torque/(mass*4)*(0.5*dt*dt)
        w.angularVelocity += torque/(mass*4)*dt; w.elapsed += dt; w.contactTime += dt
        let hullHit = hull.contains { (w.position+$0.rotated(w.angle)).y < site.height-0.02 }
        if hullHit || padUnderFeet(w,sector:sector)?.id != site.id || w.contactTime > 8 {
            w.outcome = .crashed; w.detail = "Nava a alunecat sau s-a răsturnat. Redu viteza laterală înainte de contact."
        } else if w.contactTime > 0.45 && w.velocity.length < 0.2 && abs(w.angularVelocity) < 0.08 && abs(w.angle) < 2 * .pi/180 && abs(w.position.y-site.height-3) < 0.12 {
            w.outcome = .landed; w.position.y = site.height+3; w.velocity = Vector(); w.acceleration = Vector()
            w.angle = 0; w.angularVelocity = 0; w.compression = [0,0]
            w.detail = w.touchdown?.soft == true ? "Contact lin. Precizie de pilot." : "Contact ferm, pe picioare. Încărcătura este în siguranță."
        }
    }
}
