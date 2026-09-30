import Foundation
import CoreMIDI
import FlightCore

final class MIDIService: ObservableObject {
    @Published var sources: [String] = []
    @Published var lastMessage = "Apasă o clapă sau rotește un potențiometru."
    @Published var error: String?
    var onEvent: ((MIDIEvent) -> Void)?
    var onDisconnect: (() -> Void)?
    var onSourcesChanged: (([String]) -> Void)?
    private var client: MIDIClientRef = 0
    private var inputs: [MIDIEndpointRef: MIDIPortRef] = [:]
    private var parsers: [String: MIDIParser] = [:]

    func start() {
        guard client == 0 else { return }
        let result = MIDIClientCreateWithBlock("Vlad Lunar Lander" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        }
        guard result == noErr else {
            error = "Serviciul MIDI nu este disponibil (\(result)). Poți folosi tastatura și încerca din nou."
            return
        }
        refresh()
    }

    func refresh() {
        guard client != 0 else { start(); return }
        var endpoints: [MIDIEndpointRef: String] = [:]
        for index in 0..<MIDIGetNumberOfSources() {
            let source = MIDIGetSource(index)
            var value: Unmanaged<CFString>?
            if MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &value) == noErr,
               let name = value?.takeRetainedValue() as String? {
                endpoints[source] = name
            }
        }
        let removed = inputs.keys.filter { endpoints[$0] == nil }
        for endpoint in removed {
            if let port = inputs.removeValue(forKey: endpoint) { MIDIPortDispose(port) }
        }
        if !removed.isEmpty { parsers.removeAll(); onDisconnect?() }
        for (endpoint, name) in endpoints where inputs[endpoint] == nil {
            var port: MIDIPortRef = 0
            let result = MIDIInputPortCreateWithBlock(client, "Vlad · \(name)" as CFString, &port) { [weak self] list, _ in
                let offset = MemoryLayout<MIDIPacketList>.offset(of: \MIDIPacketList.packet)!
                var packet = UnsafeRawPointer(list).advanced(by: offset).assumingMemoryBound(to: MIDIPacket.self)
                var bytes: [UInt8] = []
                for _ in 0..<list.pointee.numPackets {
                    let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data)!
                    let data = UnsafeRawPointer(packet).advanced(by: dataOffset).assumingMemoryBound(to: UInt8.self)
                    bytes.append(contentsOf: UnsafeBufferPointer(start: data, count: Int(packet.pointee.length)))
                    packet = UnsafePointer(MIDIPacketNext(packet))
                }
                let received = bytes
                DispatchQueue.main.async {
                    guard let self else { return }
                    var parser = self.parsers[name] ?? MIDIParser()
                    let events = parser.feed(received, port: name)
                    self.parsers[name] = parser
                    for event in events {
                        self.lastMessage = event.description
                        self.onEvent?(event)
                    }
                }
            }
            if result == noErr {
                let connected = MIDIPortConnectSource(port, endpoint, nil)
                if connected == noErr { inputs[endpoint] = port }
                else { MIDIPortDispose(port); error = "Nu am putut conecta portul \(name) (\(connected))." }
            } else { error = "Nu am putut deschide portul \(name) (\(result))." }
        }
        sources = endpoints.values.sorted()
        onSourcesChanged?(sources)
    }

    deinit {
        for port in inputs.values { MIDIPortDispose(port) }
        if client != 0 { MIDIClientDispose(client) }
    }
}
