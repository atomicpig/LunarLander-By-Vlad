import AppKit
import SwiftUI
import FlightCore
import UniformTypeIdentifiers

struct MissionRecord: Codable {
    var bestFuel: Double
    var time: Double
    var attempts: Int
}

final class FlightTelemetry: ObservableObject {
    @Published var world = Mission.all[0].makeWorld()
}
final class EngineGauge: ObservableObject {
    @Published var level = 0.0
}

final class GameModel: ObservableObject {
    // SpriteKit reads every frame. Small telemetry views refresh at 10 Hz,
    // instead of rebuilding the entire window for every simulation frame.
    var world = Mission.all[0].makeWorld()
    @Published var mission = Mission.all[0]
    @Published var paused = true
    @Published var showMissions = false
    @Published var showController = false
    @Published var showHelp = false
    @Published var showGraphs = false
    @Published var showVectors = true
    @Published var confirmRestart = false
    @Published var stabilize = true
    @Published var muted = false
    @Published var zoom = 1.0
    @Published var timeScale = 1.0
    @Published var power = 1.0
    @Published var rcs = 1.0
    @Published var sensitivity = 0.55
    @Published var modulation = 1.0
    var engineLevels: [ControlAction: Double] = [:]
    var armedEngines: Set<ControlAction> = []
    let engineGauges = Dictionary(uniqueKeysWithValues: ControlAction.engines.map { ($0, EngineGauge()) })
    @Published var profile = ControllerProfile()
    @Published var learning: ControlAction?
    @Published var learnMode: KnobMode = .absolute
    @Published var learnMessage = "Selectează o comandă pentru asociere."
    @Published var lastControl: ControlAction?
    @Published var observed: Set<ControlAction> = []
    var samples: [TelemetrySample] = []
    @Published var records: [String: MissionRecord] = [:]
    @Published var toast: String?
    let midi = MIDIService()
    let telemetry = FlightTelemetry()
    private var router = MIDIRouter()
    private var controls = ControlState()
    private var pitch = 0.0
    private var accumulator = 0.0
    private var lastSampleTime = -1.0
    private var lastFrameTime: TimeInterval?
    private var lastHUDTime = -1.0
    private var engineResponse = EngineResponse()
    var appliedInput: FlightInput { engineResponse.output }
    private var lastSound = Date.distantPast
    private var observers: [NSObjectProtocol] = []
    private let defaults: UserDefaults
    private var learningAll = false
    private var lastLearnedAt = Date.distantPast

    init(defaults: UserDefaults = .standard, connectMIDI: Bool = true) {
        self.defaults = defaults
        learnMessage = "Selectează o comandă, apoi atinge controlul corespunzător pe AKAI."
        if let data = defaults.data(forKey: "controller.v2") ?? defaults.data(forKey: "controller.v1"),
           let saved = try? JSONDecoder().decode(ControllerProfile.self, from: data), saved.version <= 2 {
            profile = saved.upgraded(); router.profile = profile
        }
        if let data = defaults.data(forKey: "records.v1"),
           let saved = try? JSONDecoder().decode([String: MissionRecord].self, from: data) { records = saved }
        muted = defaults.bool(forKey: "muted")
        samples = [TelemetrySample(world)]
        midi.onEvent = { [weak self] event in self?.receive(event) }
        midi.onDisconnect = { [weak self] in
            self?.pause(); self?.toast = "Controller deconectat. Reconectează-l sau continuă cu tastatura."
        }
        midi.onSourcesChanged = { [weak self] sources in self?.installDefaultProfile(sources) }
        if connectMIDI { midi.start() }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main) { [weak self] _ in self?.pause() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main) { [weak self] _ in self?.pause() })
        if !defaults.bool(forKey: "onboarded.v1") { showHelp = true }
    }

    var activeActions: Set<ControlAction> {
        controls.activeActions
    }
    var completedCount: Int { records.keys.filter { $0 != "6" }.count }
    var hasAKAI: Bool { midi.sources.contains { $0.localizedCaseInsensitiveContains("MPK") } }
    var isOverlayOpen: Bool { showController || showMissions || showHelp || confirmRestart }

    func load(_ selected: Mission) {
        mission = selected
        world = selected.makeWorld()
        telemetry.world = world
        stabilize = true; paused = true; timeScale = 1; zoom = 1
        clearInput(); samples = [TelemetrySample(world)]; lastSampleTime = 0
        lastFrameTime = nil; accumulator = 0; toast = nil
        showMissions = false
        syncAxes()
    }

    func restart() {
        let g = world.gravity, mass = world.dryMass, drag = world.drag, speed = timeScale
        let selected = mission
        load(selected)
        if selected.isLab {
            world.gravity = g; world.dryMass = mass; world.drag = drag; timeScale = speed
            samples = [TelemetrySample(world)]
            telemetry.world = world
        }
        confirmRestart = false
        syncAxes()
    }

    func clearInput() {
        controls.clear(); pitch = 0; engineLevels = [:]; armedEngines = []
        for gauge in engineGauges.values where gauge.level != 0 { gauge.level = 0 }
        engineResponse.reset()
        router.clear(); syncAxes()
    }
    func pause() { paused = true; clearInput(); accumulator = 0; lastFrameTime = nil }
    func togglePause() {
        guard world.outcome == .flying, !isOverlayOpen else { return }
        clearInput(); paused.toggle(); lastFrameTime = nil
    }
    func openController() { pause(); showController = true }
    func finishOnboarding() { defaults.set(true, forKey: "onboarded.v1"); showHelp = false }
    func setMuted(_ value: Bool) { muted = value; defaults.set(value, forKey: "muted") }

    func tick(_ time: TimeInterval) {
        defer { lastFrameTime = time }
        guard let previous = lastFrameTime, !paused, !isOverlayOpen, world.outcome == .flying else { return }
        accumulator += min(max(time - previous, 0), 0.1) * timeScale
        var next = world
        let input = flightInput()
        while accumulator + 1e-12 >= Physics.step && next.outcome == .flying {
            let applied = engineResponse.advance(toward: input, dt: Physics.step)
            Physics.advance(&next, input: applied, mission: mission)
            accumulator = max(0, accumulator - Physics.step)
            if next.elapsed - lastSampleTime >= 0.1 {
                samples.append(TelemetrySample(next)); lastSampleTime = next.elapsed
                if samples.count > 18_000 { samples.removeFirst(600) }
            }
        }
        world = next
        if time - lastHUDTime >= 1.0 / 10 || next.outcome != .flying {
            telemetry.world = next; lastHUDTime = time
        }
        if next.outcome != .flying {
            samples.append(TelemetrySample(next))
            pause()
            if next.outcome == .landed {
                let key = String(mission.id)
                let old = records[key]
                records[key] = MissionRecord(bestFuel: max(old?.bestFuel ?? 0, next.fuel),
                                             time: min(old?.time ?? .infinity, next.elapsed), attempts: (old?.attempts ?? 0) + 1)
                if let data = try? JSONEncoder().encode(records) { defaults.set(data, forKey: "records.v1") }
                sound("Glass")
            } else { sound("Basso") }
        }
    }

    func flightInput() -> FlightInput {
        func value(_ action: ControlAction) -> Double { controls.value(action) * modulation }
        var input = FlightInput()
        input.thrust = max(value(.thrust), engineLevels[.engineMain] ?? 0)
        input.reverse = max(value(.reverse), engineLevels[.engineReverse] ?? 0)
        input.lateralLeft = max(value(.left), engineLevels[.engineLeft] ?? 0)
        input.lateralRight = max(value(.right), engineLevels[.engineRight] ?? 0)
        input.rotationLeft = max(value(.rotateLeft) * 0.55, engineLevels[.engineRotateLeft] ?? 0)
        input.rotationRight = max(value(.rotateRight) * 0.55, engineLevels[.engineRotateRight] ?? 0)
        input.turn = -pitch
        input.boost = controls.value(.boost) > 0; input.brake = controls.value(.brake) > 0
        input.stabilize = stabilize; input.throttle = 1
        input.powerLimit = 1; input.lateralPower = 1; input.turnGain = 0.55
        return input
    }

    /// Advance only the rendered pose through the sub-step remainder. The
    /// authoritative simulation and measurements still use exactly 1/120 s.
    var renderedPosition: Vector {
        guard !paused, world.outcome == .flying else { return world.position }
        return world.position + world.velocity * accumulator + world.acceleration * (0.5 * accumulator * accumulator)
    }
    var renderedAngle: Double {
        world.angle + (paused ? 0 : world.angularVelocity * accumulator)
    }
    var hoverPower: Double { clamp(world.mass * world.gravity / Physics.maxMainForce, 0, 1) }

    func setHeld(_ action: ControlAction, value: Double, source: String) {
        guard !paused, !isOverlayOpen, world.outcome == .flying else {
            if value == 0 { controls.set(action, value: 0, source: source) }
            return
        }
        if controls.value(action) != value { objectWillChange.send() }
        controls.set(action, value: value, source: source)
    }

    func trigger(_ action: ControlAction) {
        if action == .cutEngines {
            clearInput(); stabilize = false
            toast = "Motoare oprite. Inerția și gravitația continuă să acționeze. K1–K6: revino la 0 pentru rearmare."
            return
        }
        if action == .pause { togglePause(); return }
        guard !isOverlayOpen else { return }
        switch action {
        case .stabilize: stabilize.toggle()
        case .gear: objectWillChange.send(); world.gear.toggle()
        case .vectors: showVectors.toggle()
        case .graphs: showGraphs.toggle()
        case .restart: pause(); confirmRestart = true
        default: break
        }
    }

    func setAxis(_ action: ControlAction, _ normalized: Double, fromMIDI: Bool = false) {
        let value = clamp(normalized, 0, 1)
        if action.isEngine {
            guard !paused, !isOverlayOpen, world.outcome == .flying else {
                toast = "Pornește zborul, apoi rotește K1–K6. Motoarele rămân oprite în pauză."
                return
            }
            let relative = profile.binding(for: action)?.knobMode != .absolute
            if fromMIDI && !armedEngines.contains(action) && !relative && value > 0.025 {
                toast = "\(action.hardware): rotește întâi la 0%, apoi crește puterea."
                router.setAxis(action, value: 0)
                return
            }
            armedEngines.insert(action)
            engineLevels[action] = value
            if engineGauges[action]?.level != value { engineGauges[action]?.level = value }
            router.setAxis(action, value: value)
            return
        }
        switch action {
        case .power: power = 0.1 + value * 0.9
        case .rcs: rcs = 0.1 + value * 0.9
        case .sensitivity: sensitivity = 0.1 + value * 0.9
        case .zoom: zoom = 0.75 + value * 1.25
        case .pitch: pitch = paused ? 0 : (abs(normalized) < 0.04 ? 0 : normalized)
        case .modulation: modulation = value
        case .gravity where mission.isLab: resetExperiment(gravity: value * 15)
        case .mass where mission.isLab: resetExperiment(mass: 500 + value * 2_500)
        case .drag where mission.isLab: resetExperiment(drag: value * 15)
        case .timeScale: timeScale = 0.25 + value * 1.75
        default: break
        }
        router.setAxis(action, value: value)
    }

    func resetExperiment(gravity: Double? = nil, mass: Double? = nil, drag: Double? = nil) {
        guard mission.isLab else { return }
        let g = gravity ?? world.gravity, m = mass ?? world.dryMass, d = drag ?? world.drag
        pause()
        world = mission.makeWorld(); world.gravity = g; world.dryMass = m; world.drag = d
        telemetry.world = world
        samples = [TelemetrySample(world)]; lastSampleTime = 0
        toast = "Parametru schimbat: experiment nou. Apasă Spațiu pentru a porni."
    }

    func syncAxes() {
        for action in ControlAction.engines { router.setAxis(action, value: engineLevels[action] ?? 0) }
        for (action, value) in [(ControlAction.power, (power - 0.1) / 0.9), (.rcs, (rcs - 0.1) / 0.9),
                               (.sensitivity, (sensitivity - 0.1) / 0.9), (.zoom, (zoom - 0.75) / 1.25),
                               (.gravity, world.gravity / 15), (.mass, (world.dryMass - 500) / 2_500),
                               (.drag, world.drag / 15), (.timeScale, (timeScale - 0.25) / 1.75)] {
            router.setAxis(action, value: value)
        }
    }

    func startLearning(_ action: ControlAction, all: Bool = false) {
        pause(); learning = action; learningAll = all
        learnMessage = "\(action.hardware): \(action.label). \(action.isAxis ? "Mișcă acel control." : "Apasă, apoi eliberează.")"
    }

    func receive(_ event: MIDIEvent) {
        if let action = learning {
            guard !event.isRelease, Date().timeIntervalSince(lastLearnedAt) > 0.3 else { return }
            if action == .pitch && (event.address.kind != .pitch || abs(event.value - 8192) < 1000) { return }
            if (action.isKnob || action == .modulation) && event.address.kind != .cc { return }
            if !action.isAxis && !(event.address.kind == .note || event.address.kind == .cc) { return }
            if !action.isAxis && event.value == 0 { return }
            if let existing = profile.bindings.first(where: { $0.address == event.address && $0.action != action }) {
                learnMessage = "Acest control este asociat cu „\(existing.action.label)”. Folosește alt control sau șterge asocierea veche."
                return
            }
            profile.assign(.init(action: action, address: event.address, knobMode: action.isKnob ? learnMode : .absolute))
            saveProfile(); observed.insert(action); lastControl = action
            lastLearnedAt = Date()
            if learningAll, let index = ControlAction.hardwareActions.firstIndex(of: action), index + 1 < ControlAction.hardwareActions.count {
                learning = ControlAction.hardwareActions[index + 1]
                learnMessage = "Salvat. Urmează \(learning!.hardware): \(learning!.label)."
            } else {
                learning = nil; learningAll = false
                learnMessage = "Asociere salvată. Poți testa controalele: cardurile se aprind când primesc mesaje."
            }
            return
        }
        if let binding = profile.bindings.first(where: { $0.address == event.address }) {
            if lastControl != binding.action { lastControl = binding.action }
            if !observed.contains(binding.action) { observed.insert(binding.action) }
        }
        // Observe while configuring, but never let a configuration gesture fly the ship.
        guard !showController else { return }
        guard let routed = router.route(event) else { return }
        switch routed {
        case .held(let action, let value): setHeld(action, value: value, source: "midi")
        case .trigger(let action): trigger(action)
        case .axis(let action, let value): if !isOverlayOpen { setAxis(action, value, fromMIDI: true) }
        }
    }

    func removeBinding(_ action: ControlAction) {
        profile.bindings.removeAll { $0.action == action }; saveProfile()
    }
    func saveProfile() {
        router.profile = profile; clearInput()
        if let data = try? JSONEncoder().encode(profile) { defaults.set(data, forKey: "controller.v2") }
    }
    func installDefaultProfile(_ sources: [String]) {
        objectWillChange.send()
        if profile.addMPKDefaults(sources: sources) {
            saveProfile()
            learnMessage = "Profil MPK mini IV instalat: K1–K8 pe portul DAW, mod relativ. Pornește zborul și rotește un K."
        }
    }
    func closeController() { learning = nil; learningAll = false; showController = false; clearInput() }

    func exportCSV() {
        pause()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "Vlad-experiment-\(mission.id + 1).csv"
        panel.title = "Salvează măsurătorile"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try TelemetrySample.csv(samples).write(to: url, atomically: true, encoding: .utf8)
            toast = "Măsurătorile au fost salvate în \(url.lastPathComponent)."
        } catch { toast = "Exportul nu a reușit: \(error.localizedDescription)" }
    }

    func key(_ code: UInt16, down: Bool, repeated: Bool = false) -> Bool {
        let flight: [UInt16: ControlAction] = [13: .thrust, 1: .reverse, 0: .left, 2: .right,
                                              12: .rotateLeft, 14: .rotateRight, 48: .boost, 11: .brake,
                                              126: .thrust, 125: .reverse, 123: .left, 124: .right]
        if let action = flight[code] {
            setHeld(action, value: down ? 1 : 0, source: "key\(code)"); return true
        }
        if down && !repeated {
            let actions: [UInt16: ControlAction] = [49: .pause, 15: .restart, 5: .gear, 9: .vectors, 3: .graphs, 17: .stabilize, 7: .cutEngines]
            if let action = actions[code] { trigger(action); return true }
            if code == 53 { pause(); return true }
        }
        return false
    }

    func sound(_ name: String) {
        guard !muted, Date().timeIntervalSince(lastSound) > 0.15 else { return }
        NSSound(named: NSSound.Name(name))?.play(); lastSound = Date()
    }
}
