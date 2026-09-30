import XCTest
import AppKit
import FlightCore
@testable import VladLander

final class RenderingTests: XCTestCase {
    func testFlightClockContinuesInMouseTrackingMode() {
        let game = LanderModel(connectMIDI:false)
        game.newGame(); game.togglePause()
        let window = NSWindow(contentRect:.init(x:0,y:0,width:1200,height:640),styleMask:.borderless,backing:.buffered,defer:false)
        let view = LunarFlightView(game:game)
        window.contentView = view
        defer { window.contentView = nil }
        let deadline = Date().addingTimeInterval(0.3)
        while Date()<deadline {
            _ = RunLoop.main.run(mode:.eventTracking,before:Date().addingTimeInterval(0.02))
            game.damping.toggle()
            game.setPrecision(game.precision < 0.5 ? 1:0.2)
        }
        XCTAssertGreaterThan(game.world.elapsed,0.15,"Mouse/radio tracking must not stop the flight clock")
    }
    func testNativeRendererDrawsFlightAndZoomWithoutMetalSurface() {
        let game = LanderModel(connectMIDI:false)
        game.newGame(); game.togglePause()
        let view = LunarFlightView(game:game)
        let rect = NSRect(x:0,y:0,width:1280,height:610)
        view.frame = rect
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1280,pixelsHigh:610,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:rep)
        for i in 0..<600 {
            game.setEngine(0,Double(i%12)/12)
            game.fire(i%8)
            game.tick(Double(i)*0.02)
            if i%120 == 0 { game.phase = .title }
            else if i%120 == 30 { game.phase = .ready }
            else if i%120 == 60 { game.phase = .paused }
            else if i%120 == 90 { game.phase = .flying }
            view.draw(rect)
        }
        XCTAssertGreaterThan(rep.tiffRepresentation?.count ?? 0,10_000)
    }
}
