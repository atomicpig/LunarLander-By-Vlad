import XCTest
import Combine
import FlightCore
@testable import VladPhysics

private final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]
    override func data(forKey key: String) -> Data? { values[key] as? Data }
    override func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    override func set(_ value: Any?, forKey key: String) { values[key] = value }
}

final class GameModelTests: XCTestCase {
    private func game() -> GameModel {
        let model = GameModel(defaults: MemoryDefaults(), connectMIDI: false)
        model.installDefaultProfile(["MPK mini IV MIDI Port", "MPK mini IV DAW Port"])
        model.finishOnboarding()
        return model
    }
    private func turn(_ knob: Int, _ value: Int, model: GameModel) {
        model.receive(.init(address: .init(port: "MPK mini IV DAW Port", channel: 0, kind: .cc, number: 23 + knob), value: value))
    }
    func testRealDialMessagesReachPhysicsWithoutHoldingAKey() {
        let model = game()
        model.togglePause()
        turn(1, 16, model: model)
        turn(2, 4, model: model)
        XCTAssertEqual(model.engineLevels[.engineMain] ?? -1, 0.02, accuracy: 1e-8)
        XCTAssertEqual(model.engineLevels[.engineReverse] ?? -1, 0.01, accuracy: 1e-8)
        model.tick(0); model.tick(1.0 / 60)
        XCTAssertGreaterThan(model.world.velocity.y, 0)
        XCTAssertLessThan(model.world.fuel, model.mission.fuel)
        XCTAssertEqual(model.world.thrustForce.y, 300, accuracy: 1e-8)
        model.tick(2.0 / 60)
        XCTAssertEqual(model.world.thrustForce.y, 300, accuracy: 1e-8)
    }
    func testAllSixDialsAreIndependentAndStopOnPause() {
        let model = game(); model.togglePause()
        for knob in 1...6 { turn(knob, knob, model: model) }
        for (index, action) in ControlAction.engines.enumerated() {
            XCTAssertEqual(model.engineLevels[action] ?? -1, sqrt(Double(index + 1)) * 0.005, accuracy: 1e-8)
        }
        model.pause()
        XCTAssertTrue(model.engineLevels.isEmpty)
        XCTAssertEqual(model.flightInput().thrust, 0)
        turn(1, 10, model: model)
        XCTAssertTrue(model.engineLevels.isEmpty)
        model.togglePause(); turn(1, 1, model: model)
        XCTAssertEqual(model.engineLevels[.engineMain] ?? -1, 0.005, accuracy: 1e-8)
    }
    func testEmergencyCutStopsEnginesAndStabilizerWithoutChangingVelocity() {
        let model = game(); model.togglePause(); turn(1, 20, model: model)
        model.tick(0); model.tick(1.0 / 60)
        let velocity = model.world.velocity
        model.trigger(.cutEngines)
        XCTAssertTrue(model.engineLevels.isEmpty)
        XCTAssertFalse(model.stabilize)
        XCTAssertEqual(model.world.velocity, velocity)
    }
    func testLaboratoryParameterChangeStartsNewMeasurement() {
        let model = game(); model.load(Mission.all[6]); model.togglePause()
        model.tick(0); model.tick(0.1)
        model.setAxis(.gravity, 0.5)
        XCTAssertTrue(model.paused)
        XCTAssertEqual(model.world.elapsed, 0)
        XCTAssertEqual(model.world.gravity, 7.5)
        XCTAssertEqual(model.samples.count, 1)
    }
    func testModWheelCannotSilenceDialEngines() {
        let model = game(); model.togglePause()
        model.setAxis(.modulation, 0)
        model.setAxis(.engineMain, 0.2)
        model.setHeld(.right, value: 1, source: "test")
        XCTAssertEqual(model.flightInput().thrust, 0.2)
        XCTAssertEqual(model.flightInput().lateralRight, 0)
        model.tick(0); model.tick(0.1)
        XCTAssertGreaterThan(model.world.thrustForce.y, 0)
    }
    func testFineInputActsNextStepAndFullPowerRampsWithoutLaunchKick() {
        let model = game(); model.togglePause()
        model.setAxis(.engineMain, 0.01)
        model.tick(0); model.tick(Physics.step)
        XCTAssertEqual(model.world.thrustForce.y, 180, accuracy: 1e-8)
        model.setAxis(.engineMain, 1)
        model.tick(2 * Physics.step)
        XCTAssertGreaterThan(model.world.thrustForce.y, 180)
        XCTAssertLessThan(model.world.thrustForce.y, 600)
        for frame in 3...60 { model.tick(Double(frame) * Physics.step) }
        XCTAssertEqual(model.appliedInput.thrust, 1, accuracy: 1e-8)
        model.trigger(.cutEngines)
        model.tick(61 * Physics.step)
        XCTAssertEqual(model.world.thrustForce.y, 0)
    }
    func testSimulationAndRenderStayContinuousAcrossFrameRates() {
        func fly(_ fps: Int) -> World {
            let model = game(); model.togglePause(); model.setAxis(.engineMain, 0.2)
            model.tick(0)
            for frame in 1...(fps * 2) { model.tick(Double(frame) / Double(fps)) }
            return model.world
        }
        let reference = fly(120)
        for fps in [30, 60, 75, 144] {
            let world = fly(fps)
            XCTAssertEqual(world.position.y, reference.position.y, accuracy: 1e-8)
            XCTAssertEqual(world.velocity.y, reference.velocity.y, accuracy: 1e-8)
        }
        let model = game(); model.togglePause(); model.setAxis(.engineMain, 0.2)
        model.tick(0); model.tick(0.1)
        let previous = model.renderedPosition.y
        model.tick(0.1 + Physics.step / 2)
        XCTAssertGreaterThan(model.renderedPosition.y, previous)
        XCTAssertLessThan(model.renderedPosition.y - previous, 0.01)
    }
    func testFlightDoesNotInvalidateTheWholeControlPanelEveryFrame() {
        let model = game(); model.togglePause()
        var rootUpdates = 0, instrumentUpdates = 0
        let root = model.objectWillChange.sink { rootUpdates += 1 }
        let instruments = model.telemetry.objectWillChange.sink { instrumentUpdates += 1 }
        model.tick(0)
        for frame in 1...120 { model.tick(Double(frame) / 120) }
        XCTAssertEqual(rootUpdates, 0)
        XCTAssertGreaterThanOrEqual(instrumentUpdates, 9)
        XCTAssertLessThanOrEqual(instrumentUpdates, 11)
        withExtendedLifetime((root, instruments)) {}
    }
    func testAllMissionsRemainCompletableThroughTheSmoothedDialControls() {
        for mission in Mission.all.prefix(6) {
            let model = game(); model.load(mission); model.togglePause(); model.tick(0)
            for frame in 1...7_200 where model.world.outcome == .flying {
                let world = model.world
                let dx = mission.padX - world.position.x
                let targetVX = clamp(dx * 0.5, -6, 6)
                let aligned = abs(dx) < max(6, mission.padWidth / 5)
                let targetVY = aligned ? -min(3, max(0.45, world.altitude * 0.35)) : clamp((45 - world.position.y) * 0.35, -2, 2)
                let fx = (targetVX - world.velocity.x) * world.mass * 1.8 - world.dragForce.x
                let fy = ((targetVY - world.velocity.y) * 1.8 + world.gravity) * world.mass - world.dragForce.y
                model.setAxis(.engineMain, max(0, fy / Physics.maxMainForce))
                model.setAxis(.engineReverse, max(0, -fy / Physics.maxReverseForce))
                model.setAxis(.engineLeft, max(0, -fx / Physics.maxLateralForce))
                model.setAxis(.engineRight, max(0, fx / Physics.maxLateralForce))
                model.tick(Double(frame) / 60)
            }
            XCTAssertEqual(model.world.outcome, .landed, "Mission \(mission.id): \(model.world.outcomeDetail)")
            XCTAssertGreaterThan(model.world.fuel, 0)
        }
    }
}
