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
}

public func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
    min(high, max(low, value))
}

public struct FlightInput {
    public var thrust = 0.0
    public var reverse = 0.0
    public var lateral = 0.0
    public var lateralLeft = 0.0
    public var lateralRight = 0.0
    public var rotationLeft = 0.0
    public var rotationRight = 0.0
    public var turn = 0.0
    public var boost = false
    public var brake = false
    public var stabilize = true
    public var throttle = 1.0
    public var powerLimit = 1.0
    public var lateralPower = 1.0
    public var turnGain = 0.55
    public init() {}
}

public enum FlightOutcome: String, Codable {
    case flying, landed, crashed, escaped
}

public struct World: Codable {
    public var position: Vector
    public var velocity = Vector()
    public var acceleration = Vector()
    public var angle = 0.0
    public var angularVelocity = 0.0
    public var dryMass: Double
    public var fuel: Double
    public var gravity: Double
    /// Quadratic drag coefficient in kg/m; Fdrag = -c |v| v.
    public var drag: Double
    public var elapsed = 0.0
    public var gear = true
    public var thrustForce = Vector()
    public var dragForce = Vector()
    public var outcome: FlightOutcome = .flying
    public var outcomeDetail = ""
    public var mass: Double { dryMass + fuel }
    public var altitude: Double { max(0, position.y - Physics.footHeight) }
    public var kineticEnergy: Double { 0.5 * mass * velocity.length * velocity.length }
    public var potentialEnergy: Double { mass * gravity * altitude }
    public var momentum: Vector { velocity * mass }
    public init(position: Vector = .init(65, 65), dryMass: Double = 1_000,
                fuel: Double = 180, gravity: Double = 1.62, drag: Double = 0) {
        self.position = position; self.dryMass = dryMass; self.fuel = fuel
        self.gravity = gravity; self.drag = drag
    }
}

public struct Mission: Identifiable, Codable {
    public let id: Int
    public let title: String
    public let location: String
    public let concept: String
    public let briefing: String
    public let hint: String
    public let gravity: Double
    public let drag: Double
    public let dryMass: Double
    public let fuel: Double
    public let start: Vector
    public let padX: Double
    public let padWidth: Double
    public let accent: String
    public var isLab: Bool { id == 6 }
    public func makeWorld() -> World {
        World(position: start, dryMass: dryMass, fuel: fuel, gravity: gravity, drag: drag)
    }
    public static let all: [Mission] = [
        .init(id: 0, title: "Primul impuls", location: "STAȚIA VLAD · ANTRENAMENT",
              concept: "Inerție · Legea I a lui Newton",
              briefing: "În absența forțelor, nava își păstrează viteza. Coboară către platforma stației: un impuls pornește mișcarea, iar unul opus o oprește.",
              hint: "Încearcă S pentru a coborî, apoi W pentru a frâna. Când eliberezi clapele, nava continuă să se miște.",
              gravity: 0, drag: 0, dryMass: 1_000, fuel: 240, start: .init(100, 42), padX: 100, padWidth: 55, accent: "cyan"),
        .init(id: 1, title: "Liniște pe Lună", location: "LUNA · MAREA LINIȘTII",
              concept: "Greutate · F = m × a",
              briefing: "Pe Lună, g = 1,62 m/s². Gravitația accelerează nava chiar când motoarele sunt oprite. Aterizează ușor pe platformă.",
              hint: "Motorul trebuie să producă F = m × g pentru a compensa greutatea. Începe frânarea înainte să ajungi aproape de sol.",
              gravity: 1.62, drag: 0, dryMass: 1_000, fuel: 180, start: .init(75, 75), padX: 118, padWidth: 32, accent: "cyan"),
        .init(id: 2, title: "Praful roșu", location: "MARTE · ELYSIUM",
              concept: "Accelerație · Componentele vitezei",
              briefing: "Gravitația marțiană este 3,71 m/s². Controlează separat viteza orizontală și verticală; platforma este mai departe.",
              hint: "Urmărește vx și vy. A și D aplică forțe laterale; nu schimbă direct poziția navei.",
              gravity: 3.71, drag: 0.4, dryMass: 1_000, fuel: 180, start: .init(45, 85), padX: 143, padWidth: 28, accent: "orange"),
        .init(id: 3, title: "Încărcătură prețioasă", location: "LUNA · TRANSPORT ȘTIINȚIFIC",
              concept: "Masă · Impulsul p = m × v",
              briefing: "Masa uscată este dublă. Aceeași forță produce o accelerație mai mică. Livrează instrumentele fără un impact dur.",
              hint: "La aceeași viteză, nava grea are un impuls mai mare. Ai nevoie de mai mult timp pentru frânare.",
              gravity: 1.62, drag: 0, dryMass: 2_000, fuel: 210, start: .init(55, 70), padX: 132, padWidth: 28, accent: "purple"),
        .init(id: 4, title: "Înapoi acasă", location: "PĂMÂNT · ZONA DE RECUPERARE",
              concept: "Energie · Rezistența aerului",
              briefing: "g = 9,81 m/s², iar atmosfera opune rezistență mișcării. Urmărește schimbul dintre energia potențială și cea cinetică.",
              hint: "Rezistența aerului disipă energie. Energia mecanică nu se conservă când motoarele sau frecarea efectuează lucru mecanic.",
              gravity: 9.81, drag: 6, dryMass: 1_000, fuel: 220, start: .init(75, 90), padX: 117, padWidth: 30, accent: "green"),
        .init(id: 5, title: "Ultima picătură", location: "LUNA · CRATERUL KEPLER",
              concept: "Sinteză · Pilotaj eficient",
              briefing: "O platformă îngustă și doar 65 kg de combustibil. Folosește impulsuri scurte și lasă inerția să lucreze pentru tine.",
              hint: "Frânarea asistată consumă combustibil. Pornește-o doar când ai nevoie și urmărește distanța până la platformă.",
              gravity: 1.62, drag: 0, dryMass: 1_000, fuel: 65, start: .init(65, 65), padX: 137, padWidth: 17, accent: "orange"),
        .init(id: 6, title: "Laborator orbital", location: "EXPERIMENT LIBER · FIZICĂ APLICATĂ",
              concept: "Observă → prezice → măsoară",
              briefing: "Schimbă g, masa și rezistența aerului. Repetă experimentul și exportă datele CSV pentru proiectul tău. Modelul folosește un câmp gravitațional local uniform, nu orbite planetare.",
              hint: "Compară două căderi fără aer, cu mase diferite. Accelerația gravitațională rămâne aceeași. Schimbarea parametrilor începe o măsurătoare nouă.",
              gravity: 1.62, drag: 0, dryMass: 1_000, fuel: 240, start: .init(100, 80), padX: 100, padWidth: 45, accent: "purple")
    ]
}

public enum Physics {
    public static let step = 1.0 / 120.0
    public static let footHeight = 3.0
    public static let halfWidth = 3.0
    public static let maxMainForce = 18_000.0
    public static let maxReverseForce = 6_000.0
    public static let maxLateralForce = 4_000.0
    public static let maxManualTorque = 1_800.0
    public static let landingVerticalSpeed = 6.0
    public static let landingHorizontalSpeed = 3.0
    public static let landingAngle = 15.0 * Double.pi / 180
    public static let landingAngularSpeed = 0.5

    public static func advance(_ world: inout World, input: FlightInput, mission: Mission, dt: Double = step) {
        guard world.outcome == .flying, dt > 0, dt.isFinite else { return }
        let mass = max(1, world.mass)
        let up = Vector(-sin(world.angle), cos(world.angle))
        let right = Vector(cos(world.angle), sin(world.angle))
        let main = maxMainForce * clamp(input.powerLimit, 0.1, 1)
        let rcs = maxLateralForce * clamp(input.lateralPower, 0.1, 1)
        let throttle = clamp(input.throttle, 0, 1)
        let forwardForce = clamp(input.thrust, 0, 1) * main * throttle
        let reverseForce = clamp(input.reverse, 0, 1) * maxReverseForce * throttle
        let leftForce = clamp(input.lateralLeft, 0, 1) * rcs * throttle
        let rightForce = clamp(input.lateralRight, 0, 1) * rcs * throttle
        let lateralForce = clamp(input.lateral, -1, 1) * rcs * throttle
        let sideForce = lateralForce + rightForce - leftForce
        var fuelForce = forwardForce + reverseForce + leftForce + rightForce + abs(lateralForce)
        var force = up * (forwardForce - reverseForce) + right * sideForce
        if input.boost { force = force + up * (main * 1.3); fuelForce += main * 1.3 }
        if input.brake {
            let desired = world.velocity * (-mass * 1.8)
            if desired.length > 0 {
                let braking = desired * min(1, 22_000 / desired.length)
                force = force + braking; fuelForce += braking.length
            }
        }
        let leftTorque = clamp(input.rotationLeft, 0, 1) * maxManualTorque * throttle
        let rightTorque = clamp(input.rotationRight, 0, 1) * maxManualTorque * throttle
        let manualTorque = clamp(input.turn, -1, 1) * maxManualTorque * clamp(input.turnGain, 0.1, 1)
        var torque = manualTorque + leftTorque - rightTorque
        var torqueConsumption = abs(manualTorque) + leftTorque + rightTorque
        if input.stabilize && abs(input.turn) < 0.02 && input.rotationLeft == 0 && input.rotationRight == 0 {
            let stabilizingTorque = clamp(-world.angle * 3.5 - world.angularVelocity * 4, -1, 1) * 6_500
            torque += stabilizingTorque
            torqueConsumption += abs(stabilizingTorque)
        }
        // Rotational thrusters have a two-metre lever arm. Exhaust speed is 2200 m/s.
        let consumption = (fuelForce + torqueConsumption / 2) / 2_200 * dt
        let available = consumption > 0 ? min(1, world.fuel / consumption) : (world.fuel > 0 ? 1.0 : 0.0)
        force = force * available
        torque *= available
        world.fuel = max(0, world.fuel - consumption * available)
        let drag = world.velocity * (-max(0, world.drag) * world.velocity.length)
        world.thrustForce = force
        world.dragForce = drag
        world.acceleration = (force + drag) / mass + Vector(0, -world.gravity)
        let previous = world.position
        let previousVelocity = world.velocity
        world.position = world.position + world.velocity * dt + world.acceleration * (0.5 * dt * dt)
        world.velocity = world.velocity + world.acceleration * dt
        let angularAcceleration = torque / (mass * 5)
        world.angle += world.angularVelocity * dt + angularAcceleration * 0.5 * dt * dt
        world.angularVelocity += angularAcceleration * dt
        world.angle = atan2(sin(world.angle), cos(world.angle))
        world.elapsed += dt

        // Sweep the contact plane so a fast ship cannot pass through the surface.
        if world.position.y <= footHeight {
            let fraction = clamp((previous.y - footHeight) / max(0.000001, previous.y - world.position.y), 0, 1)
            world.position = previous + (world.position - previous) * fraction
            world.position.y = footHeight
            world.velocity = previousVelocity + world.acceleration * (dt * fraction)
            let onPad = abs(world.position.x - mission.padX) + halfWidth <= mission.padWidth / 2
            let speedOK = abs(world.velocity.x) <= landingHorizontalSpeed && abs(world.velocity.y) <= landingVerticalSpeed
            let angleOK = abs(world.angle) <= landingAngle && abs(world.angularVelocity) <= landingAngularSpeed
            if onPad && world.gear && speedOK && angleOK {
                world.outcome = .landed
                world.outcomeDetail = abs(world.velocity.y) > 2 || abs(world.velocity.x) > 1
                    ? "Aterizare fermă, pe picioare! Trenul de aterizare a absorbit șocul."
                    : "Contact lin, pe picioare. Nava și încărcătura sunt în siguranță."
            } else {
                world.outcome = .crashed
                if !onPad { world.outcomeDetail = "Ai atins solul în afara platformei." }
                else if !world.gear { world.outcomeDetail = "Trenul de aterizare era retras." }
                else if !speedOK { world.outcomeDetail = "Viteza la contact a depășit limita de aterizare." }
                else { world.outcomeDetail = "Nava era prea înclinată sau se rotea prea repede." }
            }
        } else if world.position.x < -30 || world.position.x > 230 || world.position.y > 230 {
            world.outcome = .escaped
            world.outcomeDetail = "Ai părăsit zona de zbor. Frânează mai devreme la următoarea încercare."
        }
    }
}

public struct TelemetrySample: Codable {
    public let time, x, altitude, vx, vy, ax, ay, mass, fuel, gravity, drag, kinetic, potential: Double
    public init(_ world: World) {
        time = world.elapsed; x = world.position.x; altitude = world.altitude
        vx = world.velocity.x; vy = world.velocity.y; ax = world.acceleration.x; ay = world.acceleration.y
        mass = world.mass; fuel = world.fuel; gravity = world.gravity; drag = world.drag
        kinetic = world.kineticEnergy; potential = world.potentialEnergy
    }
    public static func csv(_ samples: [Self]) -> String {
        let header = "time_s,x_m,altitude_m,vx_m_s,vy_m_s,ax_m_s2,ay_m_s2,mass_kg,fuel_kg,gravity_m_s2,drag_kg_m,kinetic_J,potential_J"
        return header + "\n" + samples.map { s in
            [s.time,s.x,s.altitude,s.vx,s.vy,s.ax,s.ay,s.mass,s.fuel,s.gravity,s.drag,s.kinetic,s.potential]
                .map { String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), $0) }.joined(separator: ",")
        }.joined(separator: "\n") + "\n"
    }
}
