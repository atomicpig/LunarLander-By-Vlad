import XCTest
@testable import FlightCore

final class PhysicsTests: XCTestCase {
    private func freeInput() -> FlightInput { var input = FlightInput(); input.stabilize = false; return input }
    private func run(_ world: inout World, seconds: Double, input: FlightInput, mission: Mission = Mission.all[6]) {
        for _ in 0..<Int(seconds / Physics.step) { Physics.advance(&world, input: input, mission: mission) }
    }
    func testInertiaWithoutExternalForces() {
        var world = World(position: .init(60, 60), gravity: 0)
        world.velocity = .init(2, -1)
        run(&world, seconds: 5, input: freeInput())
        XCTAssertEqual(world.position.x, 70, accuracy: 1e-8)
        XCTAssertEqual(world.position.y, 55, accuracy: 1e-8)
        XCTAssertEqual(world.velocity, .init(2, -1))
        XCTAssertEqual(world.fuel, 180)
    }
    func testFreeFallMatchesAnalyticSolutionForDifferentMasses() {
        for mass in [500.0, 2_000] {
            var world = World(position: .init(100, 90), dryMass: mass, gravity: 9.81)
            run(&world, seconds: 2, input: freeInput())
            XCTAssertEqual(world.velocity.y, -19.62, accuracy: 1e-8)
            XCTAssertEqual(world.position.y, 90 - 0.5 * 9.81 * 4, accuracy: 1e-8)
        }
    }
    func testForceAndMassSetAcceleration() {
        var light = World(position: .init(100, 40), dryMass: 1_000, fuel: 100, gravity: 0)
        var heavy = World(position: .init(100, 40), dryMass: 2_100, fuel: 100, gravity: 0)
        var input = freeInput(); input.thrust = 1
        Physics.advance(&light, input: input, mission: Mission.all[6])
        Physics.advance(&heavy, input: input, mission: Mission.all[6])
        XCTAssertEqual(light.acceleration.y, Physics.maxMainForce / 1_100, accuracy: 1e-8)
        XCTAssertEqual(light.acceleration.y / heavy.acceleration.y, 2, accuracy: 1e-8)
        XCTAssertLessThan(light.fuel, 100)
        XCTAssertEqual(light.mass, 1_000 + light.fuel)
    }
    func testFuelExhaustionScalesFinalImpulseAndStopsEngine() {
        var world = World(position: .init(100, 60), fuel: 0.01, gravity: 0)
        var input = freeInput(); input.thrust = 1; input.boost = true
        Physics.advance(&world, input: input, mission: Mission.all[6])
        XCTAssertEqual(world.fuel, 0)
        XCTAssertLessThan(world.thrustForce.length, 92_000)
        let velocity = world.velocity
        Physics.advance(&world, input: input, mission: Mission.all[6])
        XCTAssertEqual(world.velocity, velocity)
        XCTAssertEqual(world.thrustForce, .init())
    }
    func testBrakeUsesFuelAndDoesNotTeleportVelocity() {
        var world = World(position: .init(80, 60), gravity: 0)
        world.velocity = .init(8, 0)
        var input = freeInput(); input.brake = true
        Physics.advance(&world, input: input, mission: Mission.all[6])
        XCTAssertGreaterThan(world.velocity.x, 0)
        XCTAssertLessThan(world.velocity.x, 8)
        XCTAssertLessThan(world.fuel, 180)
        run(&world, seconds: 3, input: input)
        XCTAssertLessThan(world.velocity.length, 0.1)
    }
    func testOpposingThrustersStillConsumeFuel() {
        var world = World(position: .init(100, 60), gravity: 0)
        var input = freeInput(); input.thrust = Physics.maxReverseForce / Physics.maxMainForce; input.reverse = 1
        Physics.advance(&world, input: input, mission: Mission.all[6])
        XCTAssertEqual(world.acceleration.length, 0, accuracy: 1e-8)
        XCTAssertLessThan(world.fuel, 180)
    }
    func testSixAnalogEnginesHaveIndependentFractionalPower() {
        var world = World(position: .init(100, 80), gravity: 0)
        let mass = world.mass
        var input = freeInput()
        input.thrust = 0.123; input.reverse = 0.04
        input.lateralLeft = 0.2; input.lateralRight = 0.5
        input.rotationLeft = 0.1; input.rotationRight = 0.03
        Physics.advance(&world, input: input, mission: Mission.all[6])
        XCTAssertEqual(world.acceleration.y, (Physics.maxMainForce * 0.123 - Physics.maxReverseForce * 0.04) / mass, accuracy: 1e-8)
        XCTAssertEqual(world.acceleration.x, Physics.maxLateralForce * 0.3 / mass, accuracy: 1e-8)
        XCTAssertEqual(world.angularVelocity, Physics.maxManualTorque * 0.07 / (mass * 5) * Physics.step, accuracy: 1e-8)
    }
    func testStabilizerUsesTorqueAndFuel() {
        var world = World(position: .init(100, 60), gravity: 0)
        world.angle = 0.3
        let input = FlightInput()
        run(&world, seconds: 5, input: input)
        XCTAssertLessThan(abs(world.angle), 0.02)
        XCTAssertLessThan(world.fuel, 180)
        XCTAssertEqual(world.velocity, .init())
    }
    func testDragDissipatesKineticEnergy() {
        var world = World(position: .init(100, 80), gravity: 0, drag: 15)
        world.velocity = .init(0, -5)
        let energy = world.kineticEnergy
        run(&world, seconds: 2, input: freeInput())
        XCTAssertLessThan(world.kineticEnergy, energy)
        XCTAssertGreaterThan(world.velocity.y, -5)
    }
    func testEnergyConservationWithoutDragOrThrust() {
        var world = World(position: .init(100, 90), gravity: 1.62)
        let energy = world.kineticEnergy + world.potentialEnergy
        run(&world, seconds: 5, input: freeInput())
        XCTAssertEqual(world.kineticEnergy + world.potentialEnergy, energy, accuracy: 1e-5)
    }
    func testContactLimitsAndContinuousGroundCollision() {
        let mission = Mission.all[6]
        func land(x: Double = 100, vy: Double = -1, vx: Double = 0, angle: Double = 0, gear: Bool = true) -> World {
            var world = World(position: .init(x, 3.001), gravity: 0)
            world.velocity = .init(vx, vy); world.angle = angle; world.gear = gear
            Physics.advance(&world, input: freeInput(), mission: mission)
            return world
        }
        XCTAssertEqual(land().outcome, .landed)
        XCTAssertEqual(land(vy: -6, vx: 3).outcome, .landed)
        XCTAssertTrue(land(vy: -5).outcomeDetail.contains("pe picioare"))
        XCTAssertEqual(land(vy: -6.01).outcome, .crashed)
        XCTAssertEqual(land(vx: 3.01).outcome, .crashed)
        XCTAssertEqual(land(gear: false).outcome, .crashed)
        XCTAssertEqual(land(angle: 14 * .pi / 180).outcome, .landed)
        XCTAssertEqual(land(angle: 16 * .pi / 180).outcome, .crashed)
        XCTAssertEqual(land(angle: .pi / 2).outcome, .crashed)
        XCTAssertEqual(land(x: 20).outcome, .crashed)
        let fast = land(vy: -1_000)
        XCTAssertEqual(fast.position.y, Physics.footHeight)
        XCTAssertEqual(fast.outcome, .crashed)
    }
    func testAllSixMissionsCanBeCompletedUsingOnlyFlightInputs() {
        for mission in Mission.all.prefix(6) {
            var world = mission.makeWorld()
            for _ in 0..<14_400 where world.outcome == .flying {
                let dx = mission.padX - world.position.x
                let targetVX = clamp(dx * 0.5, -6, 6)
                let aligned = abs(dx) < max(6, mission.padWidth / 5)
                let targetVY = aligned ? -min(3, max(0.45, world.altitude * 0.35)) : clamp((45 - world.position.y) * 0.35, -2, 2)
                let fx = (targetVX - world.velocity.x) * world.mass * 1.8 - world.dragForce.x
                let fy = ((targetVY - world.velocity.y) * 1.8 + world.gravity) * world.mass - world.dragForce.y
                var input = FlightInput()
                input.lateral = clamp(fx / Physics.maxLateralForce, -1, 1)
                input.thrust = clamp(fy / Physics.maxMainForce, 0, 1)
                input.reverse = clamp(-fy / Physics.maxReverseForce, 0, 1)
                Physics.advance(&world, input: input, mission: mission)
            }
            XCTAssertEqual(world.outcome, .landed, "Mission \(mission.id): \(world.outcomeDetail), fuel \(world.fuel), x \(world.position.x), y \(world.position.y)")
            XCTAssertGreaterThan(world.fuel, 0)
        }
    }
    func testTelemetryCSVUsesStableSIColumnsAndDecimalPoint() {
        let world = World(position: .init(100, 80))
        let csv = TelemetrySample.csv([TelemetrySample(world)])
        let rows = csv.split(separator: "\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].split(separator: ",").count, 13)
        XCTAssertEqual(rows[1].split(separator: ",").count, 13)
        XCTAssertTrue(csv.contains("1.620000"))
    }
}
