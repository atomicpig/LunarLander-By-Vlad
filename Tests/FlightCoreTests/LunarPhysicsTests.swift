import XCTest
@testable import FlightCore

final class LunarPhysicsTests:XCTestCase {
    func testFreeFallAndHorizontalInertiaMatchAnalyticMotion() {
        let sector = MoonSector(); var w = World(); w.position = Vector(200,600); w.velocity = Vector(7,-2)
        var input = FlightInput(); input.stabilize = false
        for _ in 0..<240 { Physics.advance(&w,input:input,sector:sector) }
        XCTAssertEqual(w.position.x,214,accuracy:1e-8)
        XCTAssertEqual(w.position.y,600-4-0.5*1.62*4,accuracy:1e-8)
        XCTAssertEqual(w.velocity.y,-2-1.62*2,accuracy:1e-8)
        XCTAssertEqual(w.fuel,250)
    }
    func testForceOverMassAndOpposingFuelConsumption() {
        var w = World(); let mass = w.mass; var input = FlightInput()
        input.thrust = 0.1; input.reverse = 0.3
        Physics.advance(&w,input:input,sector:MoonSector())
        XCTAssertEqual(w.acceleration.y,-1.62,accuracy:1e-8)
        XCTAssertLessThan(w.fuel,250)
        input.reverse = 0; let m = w.mass
        Physics.advance(&w,input:input,sector:MoonSector())
        XCTAssertEqual(w.acceleration.y,1800/m-1.62,accuracy:1e-8)
        XCTAssertGreaterThan(mass,m)
    }
    func testBurstIsStrongFiniteAndConsumesFuel() {
        var bank = BurstBank(), w = World(); w.velocity = Vector(); var input = FlightInput()
        bank.fire(0)
        for _ in 0..<120 {
            var step = input; bank.apply(to:&step,dt:Physics.step)
            Physics.advance(&w,input:step,sector:MoonSector())
        }
        XCTAssertTrue(bank.remaining.allSatisfy {$0 == 0})
        XCTAssertGreaterThan(w.velocity.y,3)
        XCTAssertLessThan(w.fuel,250)
        input.thrust = 0; Physics.advance(&w,input:input,sector:MoonSector())
        XCTAssertEqual(w.thrustForce.length,0,accuracy:1e-8)
    }
    func testFuelExhaustionCannotKeepFiring() {
        var w = World(fuel:0.001); var input = FlightInput(); input.thrust = 1
        Physics.advance(&w,input:input,sector:MoonSector()); XCTAssertEqual(w.fuel,0)
        Physics.advance(&w,input:input,sector:MoonSector()); XCTAssertEqual(w.thrustForce,Vector())
    }
    func testBrakeChangesVelocityThroughForceAndFuel() {
        var w = World(); w.velocity = Vector(12,-3); let before = w.velocity
        var input = FlightInput(); input.brake = true
        Physics.advance(&w,input:input,sector:MoonSector())
        XCTAssertLessThan(w.velocity.x,before.x); XCTAssertGreaterThan(w.velocity.x,0)
        XCTAssertLessThan(w.fuel,250)
    }
    func testSmallChangesRespondImmediatelyAndBigChangesRamp() {
        var engine = EngineResponse(), input = FlightInput(); input.thrust = 0.005
        XCTAssertEqual(engine.advance(toward:input,dt:Physics.step).thrust,0.005)
        input.thrust = 1
        XCTAssertLessThan(engine.advance(toward:input,dt:Physics.step).thrust,0.03)
        input.thrust = 0; XCTAssertEqual(engine.advance(toward:input,dt:Physics.step).thrust,0)
    }
    func testTerrainAndLandingPadsUseIdenticalHeights() {
        for number in [1,4,20] {
            let s = MoonSector(number:number)
            for pad in s.sites {
                for x in stride(from:pad.left,through:pad.right,by:0.3) { XCTAssertEqual(s.height(at:x),pad.height,accuracy:1e-8) }
            }
            XCTAssertEqual(s.sites.map(\.multiplier),[1,3,5])
        }
    }
    private func touchdown(vy:Double,vx:Double = 0,angle:Double = 0,siteIndex:Int = 0) -> World {
        let s = MoonSector(), site = s.sites[siteIndex]
        var w = World(); w.angle = angle
        let bottom = (Physics.feet+Physics.hull).map {$0.rotated(angle).y}.min()!
        w.position = Vector(site.x,site.height-bottom+0.001); w.velocity = Vector(vx,-vy)
        for _ in 0..<1200 where w.outcome.active { Physics.advance(&w,input:FlightInput(),sector:s) }
        return w
    }
    func testFirmObliqueLandingSettlesOnFeetAndKeepsImpactReport() {
        for index in 0..<3 {
            let w = touchdown(vy:5,vx:0.8,angle:12 * .pi/180,siteIndex:index)
            XCTAssertEqual(w.outcome,.landed,"\(index): \(w.detail)")
            XCTAssertGreaterThan(w.contactTime,0.45)
            XCTAssertEqual(w.touchdown!.vy,5,accuracy:0.001)
            XCTAssertEqual(w.velocity,Vector())
            XCTAssertGreaterThan(w.touchdown!.points,0)
        }
    }
    func testUnsafeVelocityAndHullFirstContactsCrash() {
        XCTAssertEqual(touchdown(vy:6.1).outcome,.crashed)
        XCTAssertEqual(touchdown(vy:2,vx:3.1).outcome,.crashed)
        XCTAssertEqual(touchdown(vy:1,angle:.pi/2).outcome,.crashed)
        XCTAssertEqual(touchdown(vy:1,angle:.pi).outcome,.crashed)
    }
    func testHighSpeedSweepCannotPassThroughGround() {
        let s = MoonSector(); var w = World(); w.position = Vector(260,100); w.velocity = Vector(0,-20_000)
        Physics.advance(&w,input:FlightInput(),sector:s)
        XCTAssertEqual(w.outcome,.crashed)
        XCTAssertEqual(w.position.y,38,accuracy:0.001)
    }
    func testAllThreePadsAreReachableWithNormalSmoothedDialInputs() {
        for sectorNumber in [1,12] {
            let s = MoonSector(number:sectorNumber)
            for pad in s.sites {
                var w = World(sector:s), engine = EngineResponse()
                for _ in 0..<36_000 where w.outcome.active {
                    let dx = pad.x-w.position.x, targetVX = clamp(dx*0.35,-10,10)
                    let aligned = abs(dx)<max(4,pad.width/5)
                    let altitude = max(0,w.position.y-pad.height-3)
                    let targetVY = aligned ? -min(3,max(0.6,altitude*0.22)) : clamp((155-w.position.y)*0.3,-3,3)
                    let fx = (targetVX-w.velocity.x)*w.mass*1.4
                    let fy = ((targetVY-w.velocity.y)*1.4+w.gravity)*w.mass
                    var command = FlightInput()
                    command.thrust = max(0,fy/Physics.mainForce); command.reverse = max(0,-fy/Physics.reverseForce)
                    command.lateralLeft = max(0,-fx/Physics.sideForce); command.lateralRight = max(0,fx/Physics.sideForce)
                    Physics.advance(&w,input:engine.advance(toward:command,dt:Physics.step),sector:s)
                }
                XCTAssertEqual(w.outcome,.landed,"Sector \(sectorNumber), pad \(pad.id): \(w.detail)")
                XCTAssertGreaterThan(w.fuel,0)
            }
        }
    }
    func testPadProfileMigrationPreservesPhysicalAddresses() {
        var old = ControllerProfile(); old.version = 2
        let address = MIDIAddress(port:"Custom pads",channel:9,kind:.note,number:43)
        old.assign(.init(action:.gear,address:address))
        let knob = MIDIAddress(port:"Custom encoders",channel:0,kind:.cc,number:31)
        old.assign(.init(action:.timeScale,address:knob,knobMode:.relativeTwosComplement))
        let migrated = old.upgraded()
        XCTAssertEqual(migrated.binding(for:.burstRight)?.address,address)
        XCTAssertEqual(migrated.binding(for:.sensitivity)?.address,knob)
        XCTAssertEqual(migrated.version,3)
    }
}
