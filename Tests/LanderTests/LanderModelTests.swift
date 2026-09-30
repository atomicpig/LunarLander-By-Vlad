import XCTest
import Combine
import FlightCore
@testable import VladLander

private final class MemoryDefaults:UserDefaults {
    var values:[String:Any] = [:]
    override func data(forKey key:String) -> Data? { values[key] as? Data }
    override func bool(forKey key:String) -> Bool { values[key] as? Bool ?? false }
    override func integer(forKey key:String) -> Int { values[key] as? Int ?? 0 }
    override func set(_ value:Any?,forKey key:String) { values[key] = value }
}
final class LanderModelTests:XCTestCase {
    private func game() -> LanderModel {
        let g = LanderModel(defaults:MemoryDefaults(),connectMIDI:false)
        g.profile.addMPKDefaults(sources:["MPK mini IV MIDI Port","MPK mini IV DAW Port"]); g.saveProfile()
        g.newGame(); g.togglePause(); g.tick(0); return g
    }
    func testRealDialPacketsReachSixIndependentEngines() {
        let g = game()
        for i in 0..<6 {
            g.receive(.init(address:.init(port:"MPK mini IV DAW Port",channel:0,kind:.cc,number:24+i),value:1))
        }
        XCTAssertTrue(g.dials.allSatisfy {abs($0.value-0.005)<1e-9})
        g.tick(Physics.step)
        XCTAssertTrue(g.world.enginePower.allSatisfy {$0>0})
        XCTAssertLessThan(g.world.fuel,250)
    }
    func testPadEdgesFireOnePulseAndAllCommandsClearOnPause() {
        let g = game(), address = g.profile.binding(for:.burstMain)!.address
        g.receive(.init(address:address,value:100)); g.tick(Physics.step)
        XCTAssertGreaterThan(g.world.enginePower[0],1)
        for i in 2...80 { g.receive(.init(address:address,value:100)); g.tick(Double(i)*Physics.step) }
        XCTAssertEqual(g.world.enginePower[0],0)
        g.pause(); XCTAssertTrue(g.dials.allSatisfy {$0.value == 0})
        g.receive(.init(address:address,value:0,isRelease:true)); g.receive(.init(address:address,value:100))
        g.togglePause(); g.tick(1); g.tick(1.02)
        XCTAssertEqual(g.world.enginePower[0],0)
    }
    func testFineModeAndModWheelNeverSilenceDialsOrPads() {
        let g = game(); g.setPrecision(0.2)
        g.receive(.init(address:g.profile.binding(for:.modulation)!.address,value:0))
        g.receive(.init(address:g.profile.binding(for:.engineMain)!.address,value:1))
        XCTAssertEqual(g.dials[0].value,0.001,accuracy:1e-8)
        g.tick(Physics.step); XCTAssertGreaterThan(g.world.thrustForce.y,0)
        g.fire(0); g.tick(2*Physics.step); XCTAssertGreaterThan(g.world.enginePower[0],1)
    }
    func testCrashCostsOneLifeAndRetryKeepsSector() {
        let g = game(); g.world.position = Vector(260,38.01); g.world.velocity = Vector(0,-10)
        g.tick(0.02)
        XCTAssertEqual(g.world.outcome,.crashed); XCTAssertEqual(g.lives,2); XCTAssertEqual(g.phase,.result)
        g.tick(0.1); XCTAssertEqual(g.lives,2)
        g.continueGame(); XCTAssertEqual(g.phase,.ready); XCTAssertEqual(g.sectorNumber,1)
    }
    func testSuccessfulLandingScoresOnceAndNextSectorRefuels() {
        let g = game(); g.world.position = Vector(260,38.001); g.world.velocity = Vector(0,-2)
        for i in 1...600 where g.world.outcome.active { g.tick(Double(i)/120) }
        XCTAssertEqual(g.world.outcome,.landed); XCTAssertGreaterThan(g.score,0)
        let score = g.score; g.tick(9); XCTAssertEqual(g.score,score)
        g.continueGame(); XCTAssertEqual(g.sectorNumber,2); XCTAssertEqual(g.world.fuel,250); XCTAssertEqual(g.lives,3)
    }
    func testFrameRatesProduceSameTrajectoryWithoutRootRedraws() {
        func fly(_ fps:Int) -> World {
            let g = game(); g.setEngine(0,0.12)
            for i in 1...(fps*2) {g.tick(Double(i)/Double(fps))}; return g.world
        }
        let reference = fly(120)
        for fps in [30,60,75,144] {
            let w = fly(fps)
            XCTAssertEqual(w.position.x,reference.position.x,accuracy:1e-8)
            XCTAssertEqual(w.position.y,reference.position.y,accuracy:1e-8)
        }
        let g = game(); var updates = 0
        let subscription = g.objectWillChange.sink {updates += 1}
        for i in 1...120 {g.tick(Double(i)/120)}
        XCTAssertEqual(updates,0); withExtendedLifetime(subscription) {}
    }
    func testEmergencyCutStopsBurstsAndDampingWithoutCancellingInertia() {
        let g = game()
        g.world.angularVelocity = 0.2
        g.setEngine(0,0.4); g.fire(0); g.fire(6)
        g.tick(Physics.step)
        let velocity = g.world.velocity, rotation = g.world.angularVelocity, fuel = g.world.fuel
        g.fire(7); g.tick(2*Physics.step)
        XCTAssertFalse(g.damping)
        XCTAssertEqual(g.world.fuel,fuel,accuracy:1e-9)
        XCTAssertEqual(g.world.thrustForce,Vector())
        XCTAssertEqual(g.world.velocity.x,velocity.x,accuracy:1e-9)
        XCTAssertEqual(g.world.angularVelocity,rotation,accuracy:1e-9)
        XCTAssertEqual(g.world.velocity.y,velocity.y-1.62*Physics.step,accuracy:1e-9)
    }
    func testAbsoluteDialRequiresZeroPickupAfterPause() {
        let g = game(), address = g.profile.binding(for:.engineMain)!.address
        g.profile.assign(.init(action:.engineMain,address:address,knobMode:.absolute)); g.saveProfile()
        g.receive(.init(address:address,value:100))
        XCTAssertEqual(g.dials[0].value,0)
        g.receive(.init(address:address,value:0)); g.receive(.init(address:address,value:64))
        XCTAssertGreaterThan(g.dials[0].value,0.5)
        g.pause(); g.togglePause(); g.receive(.init(address:address,value:64))
        XCTAssertEqual(g.dials[0].value,0)
    }
}
