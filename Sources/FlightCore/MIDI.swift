import Foundation

public enum MIDIKind: String, Codable { case note, cc, pitch, pressure, program }

public struct MIDIAddress: Codable, Hashable {
    public var port: String
    public var channel: Int
    public var kind: MIDIKind
    public var number: Int
    public init(port: String, channel: Int, kind: MIDIKind, number: Int) {
        self.port = port; self.channel = channel; self.kind = kind; self.number = number
    }
}

public struct MIDIEvent {
    public var address: MIDIAddress
    public var value: Int
    public var isRelease: Bool
    public init(address: MIDIAddress, value: Int, isRelease: Bool = false) {
        self.address = address; self.value = value; self.isRelease = isRelease
    }
    public var description: String {
        "\(address.port) · CH \(address.channel + 1) · \(address.kind.rawValue.uppercased()) \(address.number) = \(value)"
    }
}

/// One parser per source. Carries partial messages and running status across packets.
public struct MIDIParser {
    private var status: UInt8 = 0
    private var data: [UInt8] = []
    private var inSysEx = false
    public init() {}
    public mutating func feed(_ bytes: [UInt8], port: String) -> [MIDIEvent] {
        var events: [MIDIEvent] = []
        for byte in bytes {
            if byte >= 0xF8 { continue }
            if byte == 0xF0 { inSysEx = true; status = 0; data = []; continue }
            if byte == 0xF7 { inSysEx = false; continue }
            if inSysEx { continue }
            if byte >= 0x80 {
                data = []
                status = byte < 0xF0 ? byte : 0
                continue
            }
            guard status != 0 else { continue }
            data.append(byte)
            let command = status & 0xF0
            let needed = (command == 0xC0 || command == 0xD0) ? 1 : 2
            guard data.count == needed else { continue }
            let channel = Int(status & 0x0F)
            let first = Int(data[0])
            let second = needed > 1 ? Int(data[1]) : 0
            var kind: MIDIKind?
            var value = second
            var number = first
            var released = false
            switch command {
            case 0x80, 0x90: kind = .note; released = command == 0x80 || second == 0
            case 0xB0: kind = .cc
            case 0xE0: kind = .pitch; number = 0; value = first | (second << 7)
            case 0xA0: kind = .pressure
            case 0xD0: kind = .pressure; number = 0; value = first
            case 0xC0: kind = .program; value = first
            default: break
            }
            if let kind {
                events.append(.init(address: .init(port: port, channel: channel, kind: kind, number: number),
                                    value: value, isRelease: released))
            }
            data = []
        }
        return events
    }
}

public enum ControlAction: String, CaseIterable, Codable, Identifiable {
    case thrust, reverse, left, right, rotateLeft, rotateRight
    case boost, brake, stabilize, gear, vectors, graphs, pause, restart
    case power, rcs, sensitivity, zoom, gravity, mass, drag, timeScale
    case pitch, modulation
    case engineMain, engineReverse, engineLeft, engineRight, engineRotateLeft, engineRotateRight, cutEngines
    case burstMain, burstReverse, burstLeft, burstRight, burstRotateLeft, burstRotateRight, burstBrake
    public static let bursts: [Self] = [.burstMain, .burstReverse, .burstLeft, .burstRight, .burstRotateLeft, .burstRotateRight, .burstBrake, .cutEngines]
    public static let hardwareActions: [Self] = [
        .thrust, .reverse, .left, .right, .rotateLeft, .rotateRight,
        .burstMain, .burstReverse, .burstLeft, .burstRight, .burstRotateLeft, .burstRotateRight, .burstBrake, .cutEngines,
        .engineMain, .engineReverse, .engineLeft, .engineRight, .engineRotateLeft, .engineRotateRight,
        .zoom, .sensitivity, .pitch, .modulation
    ]
    public static let engines: [Self] = [.engineMain, .engineReverse, .engineLeft, .engineRight, .engineRotateLeft, .engineRotateRight]
    public var id: String { rawValue }
    public var isEngine: Bool { Self.engines.contains(self) }
    public var isKnob: Bool { isEngine || [.power, .rcs, .sensitivity, .zoom, .gravity, .mass, .drag, .timeScale].contains(self) }
    public var isAxis: Bool { isKnob || self == .pitch || self == .modulation }
    public var isHeld: Bool { [.thrust, .reverse, .left, .right, .rotateLeft, .rotateRight, .boost, .brake].contains(self) }
    public var isLabOnly: Bool { [.gravity, .mass, .drag].contains(self) }
    public var label: String {
        switch self {
        case .thrust: return "Motor principal"
        case .reverse: return "Motor invers"
        case .left: return "Propulsie spre stânga"
        case .right: return "Propulsie spre dreapta"
        case .rotateLeft: return "Rotație stânga"
        case .rotateRight: return "Rotație dreapta"
        case .boost: return "Impuls suplimentar"
        case .brake: return "Frână prin propulsoare"
        case .stabilize: return "Stabilizare"
        case .gear: return "Tren de aterizare"
        case .vectors: return "Vectori"
        case .graphs: return "Grafice"
        case .pause: return "Pauză / continuă"
        case .restart: return "Reîncepe"
        case .power: return "Limita motorului"
        case .rcs: return "Putere laterală"
        case .sensitivity: return "Precizie potențiometre"
        case .zoom: return "Zoom"
        case .gravity: return "Gravitație"
        case .mass: return "Masă uscată"
        case .drag: return "Rezistența aerului"
        case .timeScale: return "Viteza simulării"
        case .pitch: return "Rotiță: rotație fină"
        case .modulation: return "Rotiță: putere"
        case .engineMain: return "Motor principal"
        case .engineReverse: return "Motor invers"
        case .engineLeft: return "Motor spre stânga"
        case .engineRight: return "Motor spre dreapta"
        case .engineRotateLeft: return "Rotație stânga"
        case .engineRotateRight: return "Rotație dreapta"
        case .cutEngines: return "Oprire motoare"
        case .burstMain: return "Impuls principal"
        case .burstReverse: return "Impuls invers"
        case .burstLeft: return "Impuls stânga"
        case .burstRight: return "Impuls dreapta"
        case .burstRotateLeft: return "Impuls rotație stânga"
        case .burstRotateRight: return "Impuls rotație dreapta"
        case .burstBrake: return "Frânare scurtă"
        }
    }
    public var hardware: String {
        guard let i = Self.hardwareActions.firstIndex(of: self) else { return "" }
        if i < 6 { return ["Clapă C", "Clapă D", "Clapă E", "Clapă F", "Clapă G", "Clapă A"][i] }
        if i < 14 { return "Pad \(i - 5)" }
        if i < 22 { return "K\(i - 13)" }
        return self == .pitch ? "Pitch" : "Mod"
    }
}

public enum KnobMode: String, CaseIterable, Codable, Identifiable {
    case absolute, relativeTwosComplement, relativeSignMagnitude, relativeOffset
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .absolute: return "Absolut · 0…127"
        case .relativeTwosComplement: return "Relativ · +1 / 127"
        case .relativeSignMagnitude: return "Relativ · +1 / 65"
        case .relativeOffset: return "Relativ · 65 / 63"
        }
    }
    public func apply(_ raw: Int, to previous: Double, step: Double = 1.0 / 127) -> Double {
        let value = max(0, min(127, raw))
        switch self {
        case .absolute: return Double(value) / 127
        case .relativeTwosComplement: return clamp(previous + Double(value < 64 ? value : value - 128) * step, 0, 1)
        case .relativeSignMagnitude: return clamp(previous + Double(value < 64 ? value : -(value - 64)) * step, 0, 1)
        case .relativeOffset: return clamp(previous + Double(value - 64) * step, 0, 1)
        }
    }
    /// Tame the encoder's hardware acceleration: slow turns are 0.5% and even
    /// the largest single accelerated message cannot jump more than 4%.
    public func applyEngine(_ raw: Int, to previous: Double, sensitivity: Double = 1) -> Double {
        if self == .absolute { return apply(raw, to: previous) }
        let value = max(0, min(127, raw))
        let delta: Int
        switch self {
        case .relativeTwosComplement: delta = value < 64 ? value : value - 128
        case .relativeSignMagnitude: delta = value < 64 ? value : -(value - 64)
        case .relativeOffset: delta = value - 64
        case .absolute: delta = 0
        }
        let change = sqrt(Double(abs(delta))) * 0.005 * clamp(sensitivity, 0.2, 2) * (delta < 0 ? -1 : 1)
        return clamp(previous + change, 0, 1)
    }
}

public struct ControlBinding: Codable, Equatable {
    public var action: ControlAction
    public var address: MIDIAddress
    public var knobMode: KnobMode
    public init(action: ControlAction, address: MIDIAddress, knobMode: KnobMode = .absolute) {
        self.action = action; self.address = address; self.knobMode = knobMode
    }
}

public struct ControllerProfile: Codable {
    public var version = 3
    public var bindings: [ControlBinding] = []
    public init() {}
    public mutating func assign(_ binding: ControlBinding) {
        bindings.removeAll { $0.action == binding.action || $0.address == binding.address }
        bindings.append(binding)
    }
    public func binding(for action: ControlAction) -> ControlBinding? { bindings.first { $0.action == action } }
    public func upgraded() -> ControllerProfile {
        var result = self
        if version == 1 {
            let replacement: [ControlAction: ControlAction] = [
                .power: .engineMain, .rcs: .engineReverse, .sensitivity: .engineLeft,
                .zoom: .engineRight, .gravity: .engineRotateLeft, .mass: .engineRotateRight,
                .drag: .zoom, .restart: .cutEngines
            ]
            result.bindings = bindings.map { old in
                var binding = old; binding.action = replacement[old.action] ?? old.action; return binding
            }
        }
        if version < 3 {
            let pads: [ControlAction: ControlAction] = [
                .boost: .burstMain, .brake: .burstReverse, .stabilize: .burstLeft,
                .gear: .burstRight, .vectors: .burstRotateLeft, .graphs: .burstRotateRight,
                .pause: .burstBrake, .timeScale: .sensitivity
            ]
            result.bindings = result.bindings.map { old in
                var binding = old; binding.action = pads[old.action] ?? old.action; return binding
            }
        }
        result.version = 3
        return result
    }
    /// DAW preset observed on a physical MPK mini IV: channel 1, CC 24...31,
    /// signed two's-complement increments. Preserve every user-learned mapping.
    @discardableResult
    public mutating func addMPKDefaults(sources: [String]) -> Bool {
        guard let main = sources.first(where: { $0.localizedCaseInsensitiveContains("MPK mini IV") &&
            $0.localizedCaseInsensitiveContains("MIDI Port") }) else { return false }
        var defaults: [ControlBinding] = []
        let keys = [48, 50, 52, 53, 55, 57]
        for (index, action) in ControlAction.hardwareActions.prefix(6).enumerated() {
            defaults.append(.init(action: action, address: .init(port: main, channel: 0, kind: .note, number: keys[index])))
        }
        let pads = [40, 41, 42, 43, 36, 37, 38, 39]
        for (index, action) in ControlAction.hardwareActions[6..<14].enumerated() {
            defaults.append(.init(action: action, address: .init(port: main, channel: 9, kind: .note, number: pads[index])))
        }
        if let daw = sources.first(where: { $0.localizedCaseInsensitiveContains("MPK mini IV") &&
            $0.localizedCaseInsensitiveContains("DAW") }) {
            for (index, action) in ControlAction.hardwareActions[14..<22].enumerated() {
                defaults.append(.init(action: action, address: .init(port: daw, channel: 0, kind: .cc, number: 24 + index),
                                      knobMode: .relativeTwosComplement))
            }
        }
        defaults.append(.init(action: .pitch, address: .init(port: main, channel: 0, kind: .pitch, number: 0)))
        defaults.append(.init(action: .modulation, address: .init(port: main, channel: 0, kind: .cc, number: 1)))
        var added = false
        for binding in defaults where self.binding(for: binding.action) == nil && !bindings.contains(where: { $0.address == binding.address }) {
            bindings.append(binding); added = true
        }
        return added
    }
}

public enum RoutedInput {
    case held(ControlAction, Double)
    case trigger(ControlAction)
    case axis(ControlAction, Double)
}

public struct MIDIRouter {
    public var profile: ControllerProfile
    public var engineSensitivity = 1.0
    private var pressed: Set<MIDIAddress> = []
    private var axisValues: [ControlAction: Double] = [:]
    public init(profile: ControllerProfile = .init()) { self.profile = profile }
    public mutating func clear() { pressed.removeAll(); axisValues.removeAll() }
    public mutating func setAxis(_ action: ControlAction, value: Double) { axisValues[action] = value }
    public mutating func route(_ event: MIDIEvent) -> RoutedInput? {
        guard let binding = profile.bindings.first(where: { $0.address == event.address }) else { return nil }
        let action = binding.action
        if action.isAxis {
            let value: Double
            if action == .pitch { value = clamp(Double(event.value - 8192) / 8192, -1, 1) }
            else if action == .modulation { value = Double(event.value) / 127 }
            else if action.isEngine { value = binding.knobMode.applyEngine(event.value, to: axisValues[action] ?? 0, sensitivity: engineSensitivity) }
            else { value = binding.knobMode.apply(event.value, to: axisValues[action] ?? 0.5) }
            axisValues[action] = value
            return .axis(action, value)
        }
        let isDown = !event.isRelease && event.value > 0
        if action.isHeld {
            return .held(action, isDown ? Double(event.value) / 127 : 0)
        }
        if isDown {
            guard pressed.insert(event.address).inserted else { return nil }
            return .trigger(action)
        }
        pressed.remove(event.address)
        return nil
    }
}
