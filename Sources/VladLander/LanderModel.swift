import AppKit
import SwiftUI
import FlightCore

enum GamePhase { case title, ready, flying, paused, result, gameOver }
final class Telemetry: ObservableObject { @Published var world = World() }
final class EngineDial: ObservableObject { @Published var value = 0.0; @Published var actual = 0.0 }

final class LanderModel: ObservableObject {
    @Published var phase = GamePhase.title
    @Published var score = 0
    @Published var lives = 3
    @Published var best = 0
    @Published var sectorNumber = 1
    @Published var showController = false
    @Published var showHelp = false
    @Published var confirmRetry = false
    @Published var damping = true
    @Published var muted = false
    @Published var autoCamera = true
    @Published var zoom = 1.0
    @Published var precision = 1.0
    @Published var volume = 0.5
    @Published var profile = ControllerProfile()
    @Published var learning: ControlAction?
    @Published var learnMode = KnobMode.relativeTwosComplement
    @Published var learningMessage = "Alege o comandă și mișcă acel control pe AKAI."
    @Published var lastControl: ControlAction?
    @Published var activePad: Int?
    @Published var notice: String?
    let midi = MIDIService(), telemetry = Telemetry()
    let dials = (0..<6).map { _ in EngineDial() }
    var world = World(), sector = MoonSector()
    var flightID = 0
    var command = FlightInput()
    var applied = FlightInput()
    private var router = MIDIRouter()
    private var held = ControlState(), bursts = BurstBank(), response = EngineResponse()
    private var armed: Set<ControlAction> = []
    private var modulation = 1.0, pitch = 0.0, accumulator = 0.0
    private var lastTime: Double?, lastHUD = -1.0
    private var observers: [NSObjectProtocol] = []
    private let defaults: UserDefaults
    private var audio: FlightAudio?
    private var noticeWork: DispatchWorkItem?
    private var padWork: DispatchWorkItem?

    init(defaults:UserDefaults = .standard,connectMIDI:Bool = true) {
        self.defaults = defaults
        let legacy = connectMIDI ? UserDefaults(suiteName:"ro.vlad.physics") : nil
        if let data = defaults.data(forKey:"lander.controller.v3") ?? defaults.data(forKey:"controller.v2") ?? defaults.data(forKey:"controller.v1") ?? legacy?.data(forKey:"controller.v2"),
           let saved = try? JSONDecoder().decode(ControllerProfile.self,from:data), saved.version <= 3 {
            profile = saved.upgraded(); router.profile = profile
        }
        best = defaults.integer(forKey:"lander.best")
        muted = defaults.bool(forKey:"lander.muted")
        midi.onEvent = { [weak self] in self?.receive($0) }
        midi.onDisconnect = { [weak self] in self?.pause(); self?.announce("AKAI deconectat. Zbor în pauză; poți continua cu tastatura.") }
        midi.onSourcesChanged = { [weak self] sources in
            guard let self else { return }
            if self.profile.addMPKDefaults(sources:sources) { self.saveProfile() }
        }
        if connectMIDI { midi.start(); audio = FlightAudio() }
        observers.append(NotificationCenter.default.addObserver(forName:NSApplication.didResignActiveNotification,object:nil,queue:.main) { [weak self] _ in self?.pause() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.willSleepNotification,object:nil,queue:.main) { [weak self] _ in self?.pause() })
    }
    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer); NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        noticeWork?.cancel(); padWork?.cancel()
    }
    var running:Bool { phase == .flying && !showController && !showHelp && !confirmRetry }
    var overlay:Bool { showController || showHelp || confirmRetry }
    var hasController:Bool { !midi.sources.isEmpty }
    var currentSite:LandingSite { sector.nearestSite(to:world.position.x) }

    func newGame() {
        score = 0; lives = 3; sectorNumber = 1; damping = true
        launch(sector:MoonSector(),fuel:250)
    }
    private func launch(sector:MoonSector,fuel:Double) {
        clearInput(); self.sector = sector; world = World(sector:sector,fuel:fuel)
        telemetry.world = world; flightID += 1; lastTime = nil; accumulator = 0
        phase = .ready; notice = nil; autoCamera = true; zoom = 1
    }
    func continueGame() {
        guard phase == .result else { return }
        if world.outcome == .landed {
            sectorNumber += 1
            launch(sector:MoonSector(number:sectorNumber),fuel:min(250,world.fuel+45))
        } else { launch(sector:sector,fuel:max(70,world.fuel)) }
    }
    func retry() {
        confirmRetry = false
        guard phase != .title else { return }
        if world.outcome.active { lives -= 1 }
        if lives <= 0 { clearInput(); phase = .gameOver; return }
        launch(sector:sector,fuel:max(70,world.fuel))
    }
    func togglePause() {
        guard !overlay else { return }
        if phase == .title || phase == .gameOver { newGame(); return }
        if phase == .result { continueGame(); return }
        if phase == .ready || phase == .paused { clearInput(); lastTime = nil; phase = .flying; notice = nil }
        else { pause() }
    }
    func pause() { if phase == .flying { phase = .paused }; clearInput(); accumulator = 0; lastTime = nil }
    func clearInput() {
        held.clear(); bursts.clear(); response.reset(); router.clear(); armed = []
        command = FlightInput(); applied = FlightInput(); pitch = 0; activePad = nil
        for dial in dials { if dial.value != 0 { dial.value = 0 }; if dial.actual != 0 { dial.actual = 0 } }
        audio?.stop()
        router.setAxis(.sensitivity,value:(precision-0.2)/1.8)
        router.setAxis(.zoom,value:(zoom-0.75)/0.75)
    }
    func cut() { clearInput(); damping = false; announce("Motoare la zero. Inerția continuă.") }
    func setEngine(_ index:Int,_ value:Double,fromMIDI:Bool = false) {
        guard dials.indices.contains(index), running, world.outcome == .flying else { return }
        let action = ControlAction.engines[index], value = clamp(value,0,1)
        let absolute = profile.binding(for:action)?.knobMode == .absolute
        if fromMIDI && absolute && !armed.contains(action) && value > 0.025 {
            router.setAxis(action,value:0); announce("\(action.hardware): revino la 0%, apoi crește puterea."); return
        }
        armed.insert(action); dials[index].value = value; router.setAxis(action,value:value)
    }
    func fire(_ index:Int) {
        guard index >= 0 && index < 8 else { return }
        if index == 7 { cut(); return }
        guard running, world.outcome == .flying else { return }
        bursts.fire(index); activePad = index
        padWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.activePad = nil }; padWork = work
        DispatchQueue.main.asyncAfter(deadline:.now()+0.24,execute:work)
    }
    func hold(_ action:ControlAction,down:Bool,source:String,value:Double = 1) {
        if !down { held.set(action,value:0,source:source); return }
        guard running, world.outcome == .flying else { return }
        held.set(action,value:value,source:source)
    }
    func tick(_ time:Double) {
        defer { lastTime = time }
        guard let previous = lastTime, running, world.outcome.active else { return }
        accumulator += min(0.1,max(0,time-previous))
        let keys:[ControlAction] = [.thrust,.reverse,.left,.right,.rotateLeft,.rotateRight]
        let levels = keys.enumerated().map { max(dials[$0.offset].value,held.value($0.element)*modulation) }
        command.thrust = levels[0]; command.reverse = levels[1]; command.lateralLeft = levels[2]; command.lateralRight = levels[3]
        command.rotationLeft = levels[4]; command.rotationRight = levels[5]; command.turn = -pitch*0.45; command.stabilize = damping
        let oldOutcome = world.outcome
        while accumulator+1e-12 >= Physics.step && world.outcome.active {
            applied = response.advance(toward:command,dt:Physics.step)
            bursts.apply(to:&applied,dt:Physics.step)
            Physics.advance(&world,input:applied,sector:sector)
            accumulator = max(0,accumulator-Physics.step)
        }
        if world.outcome == .settling && oldOutcome == .flying { clearInput(); audio?.impact(volume:muted ? 0:volume) }
        if time-lastHUD >= 0.1 || world.outcome != oldOutcome {
            telemetry.world = world; lastHUD = time
            for i in dials.indices { dials[i].actual = world.enginePower[i] }
            audio?.update(world:world,input:applied,running:running,volume:muted ? 0:volume)
        }
        if !world.outcome.active {
            clearInput()
            if world.outcome == .landed {
                score += world.touchdown?.points ?? 0
                if score > best { best = score; defaults.set(best,forKey:"lander.best") }
            } else { lives -= 1 }
            phase = lives > 0 ? .result:.gameOver
        }
    }
    var renderedPosition:Vector { running ? world.position+world.velocity*accumulator+world.acceleration*(0.5*accumulator*accumulator) : world.position }
    var renderedAngle:Double { world.angle+(running ? world.angularVelocity*accumulator:0) }
    func announce(_ text:String) {
        notice = text; noticeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.notice = nil }; noticeWork = work
        DispatchQueue.main.asyncAfter(deadline:.now()+4,execute:work)
    }
    func setPrecision(_ value:Double) {
        precision = clamp(value,0.2,2); router.engineSensitivity = precision
        router.setAxis(.sensitivity,value:(precision-0.2)/1.8)
    }
    func setMuted(_ value:Bool) { muted = value; defaults.set(value,forKey:"lander.muted"); if value { audio?.stop() } }
    func openController() { pause(); showController = true }
    func saveProfile() {
        clearInput(); router.profile = profile
        if let data = try? JSONEncoder().encode(profile) { defaults.set(data,forKey:"lander.controller.v3") }
    }
    func learn(_ action:ControlAction) { pause(); learning = action; learningMessage = "\(action.hardware) · \(action.label): atinge controlul." }
    func receive(_ event:MIDIEvent) {
        if let action = learning {
            guard !event.isRelease, event.value > 0 else { return }
            if action == .pitch && (event.address.kind != .pitch || abs(event.value-8192) < 1000) { return }
            if (action.isKnob || action == .modulation) && event.address.kind != .cc { return }
            if !action.isAxis && event.address.kind != .note && event.address.kind != .cc { return }
            if let used = profile.bindings.first(where:{$0.address == event.address && $0.action != action}) {
                learningMessage = "Deja folosit de \(used.action.hardware). Șterge asocierea veche sau alege alt control."; return
            }
            profile.assign(.init(action:action,address:event.address,knobMode:action.isKnob ? learnMode:.absolute))
            saveProfile(); learning = nil; learningMessage = "Salvat: \(action.hardware) · \(action.label)."; return
        }
        if showController {
            if let action = profile.bindings.first(where:{$0.address == event.address})?.action, lastControl != action { lastControl = action }
            return
        }
        guard let routed = router.route(event) else { return }
        switch routed {
        case .held(let action,let value): hold(action,down:value > 0,source:"midi",value:value)
        case .trigger(let action): if let index = ControlAction.bursts.firstIndex(of:action) { fire(index) }
        case .axis(let action,let value):
            if let index = ControlAction.engines.firstIndex(of:action) { setEngine(index,value,fromMIDI:true) }
            else if action == .pitch { pitch = running ? (abs(value) < 0.04 ? 0:value):0 }
            else if action == .modulation { modulation = value }
            else if action == .zoom { autoCamera = false; zoom = 0.75+clamp(value,0,1)*0.75 }
            else if action == .sensitivity { setPrecision(0.2+value*1.8) }
        }
    }
    func key(_ code:UInt16,down:Bool,repeated:Bool = false) -> Bool {
        let keys:[UInt16:ControlAction] = [13:.thrust,1:.reverse,0:.left,2:.right,12:.rotateLeft,14:.rotateRight,126:.thrust,125:.reverse,123:.left,124:.right]
        if let action = keys[code] { hold(action,down:down,source:"key\(code)"); return true }
        guard down && !repeated else { return false }
        if let index = [UInt16(18),19,20,21,23,22,26,28].firstIndex(of:code) { fire(index); return true }
        switch code {
        case 49: togglePause()
        case 53: pause()
        case 7: cut()
        case 11: fire(6)
        case 17: damping.toggle()
        case 35: setPrecision(precision < 0.5 ? 1:0.2)
        case 8: autoCamera.toggle()
        case 15: pause(); confirmRetry = true
        default: return false
        }
        return true
    }
}
