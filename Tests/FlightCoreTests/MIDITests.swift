import XCTest
@testable import FlightCore

final class MIDITests: XCTestCase {
    func testIndependentInputSourcesAndPauseDisconnectClear() {
        var controls = ControlState()
        controls.set(.thrust, value: 0.8, source: "midi")
        controls.set(.thrust, value: 1, source: "keyboard")
        controls.set(.left, value: 1, source: "midi")
        controls.set(.thrust, value: 0, source: "keyboard")
        XCTAssertEqual(controls.value(.thrust), 0.8)
        XCTAssertEqual(controls.value(.left), 1)
        controls.clear()
        XCTAssertEqual(controls.value(.thrust), 0)
        XCTAssertTrue(controls.activeActions.isEmpty)
    }
    func testParserRunningStatusPartialMessagesRealtimeAndNoteOff() {
        var parser = MIDIParser()
        XCTAssertTrue(parser.feed([0x90, 60], port: "AKAI").isEmpty)
        let events = parser.feed([100, 0xF8, 62, 80, 60, 0, 0x80, 62, 25], port: "AKAI")
        XCTAssertEqual(events.count, 4)
        XCTAssertEqual(events[0].address.number, 60)
        XCTAssertEqual(events[1].value, 80)
        XCTAssertTrue(events[2].isRelease)
        XCTAssertTrue(events[3].isRelease)
    }
    func testParserChannelsPitchAndSysEx() {
        var parser = MIDIParser()
        let events = parser.feed([0xF0, 1, 2, 0xF8, 3, 0xF7, 0xB9, 20, 127, 0xE0, 0, 64, 0xC1, 7], port: "MPK")
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].address.channel, 9)
        XCTAssertEqual(events[1].address.kind, .pitch)
        XCTAssertEqual(events[1].value, 8192)
        XCTAssertEqual(events[2].address.kind, .program)
    }
    func testMappingSeparatesPortsChannelsAndTypes() {
        let note = MIDIAddress(port: "Main", channel: 0, kind: .note, number: 60)
        var profile = ControllerProfile()
        profile.assign(.init(action: .thrust, address: note))
        var router = MIDIRouter(profile: profile)
        for address in [MIDIAddress(port: "DAW", channel: 0, kind: .note, number: 60),
                        MIDIAddress(port: "Main", channel: 9, kind: .note, number: 60),
                        MIDIAddress(port: "Main", channel: 0, kind: .cc, number: 60)] {
            XCTAssertNil(router.route(.init(address: address, value: 100)))
        }
        guard case .held(.thrust, let value) = router.route(.init(address: note, value: 100)) else { return XCTFail() }
        XCTAssertEqual(value, 100.0 / 127)
    }
    func testSimultaneousNotesReleaseIndependently() {
        var profile = ControllerProfile()
        let a = MIDIAddress(port: "MPK", channel: 0, kind: .note, number: 60)
        let b = MIDIAddress(port: "MPK", channel: 0, kind: .note, number: 62)
        profile.assign(.init(action: .thrust, address: a)); profile.assign(.init(action: .left, address: b))
        var router = MIDIRouter(profile: profile)
        guard case .held(.thrust, _) = router.route(.init(address: a, value: 127)) else { return XCTFail() }
        guard case .held(.left, _) = router.route(.init(address: b, value: 127)) else { return XCTFail() }
        guard case .held(.thrust, let value) = router.route(.init(address: a, value: 64, isRelease: true)) else { return XCTFail() }
        XCTAssertEqual(value, 0)
    }
    func testToggleOnlyOnRisingEdgeAndResetOnDisconnect() {
        let address = MIDIAddress(port: "MPK", channel: 9, kind: .note, number: 36)
        var profile = ControllerProfile(); profile.assign(.init(action: .pause, address: address))
        var router = MIDIRouter(profile: profile)
        guard case .trigger(.pause) = router.route(.init(address: address, value: 127)) else { return XCTFail() }
        XCTAssertNil(router.route(.init(address: address, value: 100)))
        XCTAssertNil(router.route(.init(address: address, value: 0, isRelease: true)))
        guard case .trigger(.pause) = router.route(.init(address: address, value: 100)) else { return XCTFail() }
        router.clear()
        guard case .trigger(.pause) = router.route(.init(address: address, value: 100)) else { return XCTFail() }
    }
    func testRelativeKnobsBothDirectionsAndClamp() {
        XCTAssertEqual(KnobMode.absolute.apply(127, to: 0), 1)
        for (mode, increment, decrement) in [(KnobMode.relativeTwosComplement, 1, 127),
                                            (.relativeSignMagnitude, 1, 65), (.relativeOffset, 65, 63)] {
            let up = mode.apply(increment, to: 0.5)
            XCTAssertGreaterThan(up, 0.5)
            XCTAssertEqual(mode.apply(decrement, to: up), 0.5, accuracy: 1e-8)
            XCTAssertEqual(mode.apply(increment, to: 1), 1)
            XCTAssertEqual(mode.apply(decrement, to: 0), 0)
        }
    }
    func testProfileRoundTripAndReassignmentHasNoDuplicateAddresses() throws {
        let address = MIDIAddress(port: "MPK mini IV MIDI Port", channel: 2, kind: .cc, number: 16)
        var profile = ControllerProfile()
        profile.assign(.init(action: .power, address: address, knobMode: .relativeOffset))
        let data = try JSONEncoder().encode(profile)
        var saved = try JSONDecoder().decode(ControllerProfile.self, from: data)
        XCTAssertEqual(saved.bindings, profile.bindings)
        saved.assign(.init(action: .zoom, address: address))
        XCTAssertNil(saved.binding(for: .power))
        XCTAssertEqual(saved.bindings.count, 1)
    }
    func testOldControllerProfileMigratesDialsWithoutRelearning() {
        var old = ControllerProfile(); old.version = 1
        let address = MIDIAddress(port: "MPK", channel: 0, kind: .cc, number: 14)
        old.assign(.init(action: .power, address: address, knobMode: .relativeSignMagnitude))
        let updated = old.upgraded()
        XCTAssertEqual(updated.version, 3)
        XCTAssertEqual(updated.binding(for: .engineMain)?.address, address)
        XCTAssertEqual(updated.binding(for: .engineMain)?.knobMode, .relativeSignMagnitude)
        XCTAssertNil(updated.binding(for: .power))
        XCTAssertEqual(ControlAction.hardwareActions.count, 24)
    }
    func testRealMPKDAWKnobMessagesControlAllEightDials() {
        var profile = ControllerProfile()
        XCTAssertTrue(profile.addMPKDefaults(sources: ["MPK mini IV MIDI Port", "MPK mini IV DAW Port"]))
        XCTAssertEqual(profile.bindings.count, 24)
        var parser = MIDIParser()
        var router = MIDIRouter(profile: profile)
        for (index, action) in ControlAction.hardwareActions[14..<22].enumerated() {
            router.setAxis(action, value: 0)
            // Actual packet pattern captured from the user's eight physical encoders.
            let events = parser.feed([0xB0, UInt8(24 + index), 0x01, 0xB0, UInt8(24 + index), 0x7F], port: "MPK mini IV DAW Port")
            guard case .axis(let upAction, let up) = router.route(events[0]),
                  case .axis(let downAction, let down) = router.route(events[1]) else { return XCTFail() }
            XCTAssertEqual(upAction, action); XCTAssertEqual(downAction, action)
            XCTAssertEqual(up, action.isEngine ? 0.005 : 1.0 / 127, accuracy: 1e-8)
            XCTAssertEqual(down, 0, accuracy: 1e-8)
        }
    }
    func testAutomaticPresetDoesNotOverwriteCustomAssociations() {
        var profile = ControllerProfile()
        let custom = MIDIAddress(port: "Custom", channel: 3, kind: .cc, number: 55)
        profile.assign(.init(action: .engineMain, address: custom))
        profile.addMPKDefaults(sources: ["MPK mini IV MIDI Port", "MPK mini IV DAW Port"])
        XCTAssertEqual(profile.binding(for: .engineMain)?.address, custom)
        XCTAssertFalse(profile.addMPKDefaults(sources: ["MPK mini IV MIDI Port", "MPK mini IV DAW Port"]))
    }
    func testEngineEncoderHasImmediateFineResponseWithoutAccelerationSpikes() {
        let mode = KnobMode.relativeTwosComplement
        XCTAssertEqual(mode.applyEngine(1, to: 0), 0.005, accuracy: 1e-10)
        for delta in 1...63 {
            let up = mode.applyEngine(delta, to: 0.5)
            XCTAssertGreaterThan(up, 0.5)
            XCTAssertLessThanOrEqual(up - 0.5, 0.04)
            XCTAssertEqual(mode.applyEngine(128 - delta, to: up), 0.5, accuracy: 1e-10)
        }
    }
}
