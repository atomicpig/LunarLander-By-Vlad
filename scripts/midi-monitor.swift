import Foundation
import CoreMIDI

// Read-only diagnostic: no MIDI output or controller settings are changed.
var client: MIDIClientRef = 0
let status = MIDIClientCreate("Vlad MIDI diagnostic" as CFString, nil, nil, &client)
guard status == noErr else { print("MIDI client error: \(status)"); exit(1) }
var ports: [MIDIPortRef] = []
for index in 0..<MIDIGetNumberOfSources() {
    let endpoint = MIDIGetSource(index)
    var value: Unmanaged<CFString>?
    MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &value)
    let name = value?.takeRetainedValue() as String? ?? "Source \(index)"
    guard name.localizedCaseInsensitiveContains("MPK") else { continue }
    var port: MIDIPortRef = 0
    MIDIInputPortCreateWithBlock(client, name as CFString, &port) { packets, _ in
        let offset = MemoryLayout<MIDIPacketList>.offset(of: \MIDIPacketList.packet)!
        var packet = UnsafeRawPointer(packets).advanced(by: offset).assumingMemoryBound(to: MIDIPacket.self)
        for _ in 0..<packets.pointee.numPackets {
            let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data)!
            let bytes = UnsafeRawPointer(packet).advanced(by: dataOffset).assumingMemoryBound(to: UInt8.self)
            let data = Array(UnsafeBufferPointer(start: bytes, count: Int(packet.pointee.length)))
            if data.first != 0xF8 && data.first != 0xFE {
                print("\(name): " + data.map { String(format: "%02X", $0) }.joined(separator: " "))
                fflush(stdout)
            }
            packet = UnsafePointer(MIDIPacketNext(packet))
        }
    }
    MIDIPortConnectSource(port, endpoint, nil); ports.append(port)
    print("Listening: \(name)")
}
print("READY — rotate K1 through K8, in order, both directions."); fflush(stdout)
RunLoop.current.run(until: Date().addingTimeInterval(Double(CommandLine.arguments.dropFirst().first ?? "45") ?? 45))
for port in ports { MIDIPortDispose(port) }
MIDIClientDispose(client)
