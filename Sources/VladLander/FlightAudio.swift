import AVFoundation
import FlightCore

/// Small synthesized PCM loops: no bundled recordings, network, or microphone.
final class FlightAudio {
    private var engine: AVAudioPlayer?
    private var contact: AVAudioPlayer?
    init() {
        engine = try? AVAudioPlayer(data: Self.wave(duration: 1, impact: false))
        engine?.numberOfLoops = -1; engine?.volume = 0; engine?.prepareToPlay()
        contact = try? AVAudioPlayer(data: Self.wave(duration: 0.35, impact: true))
        contact?.prepareToPlay()
    }
    func update(world: World, input: FlightInput, running: Bool, volume: Double) {
        let level = world.enginePower.max() ?? 0
        let audible = running && world.outcome == .flying && world.fuel > 0 && volume > 0 && (level > 0 || input.brake || input.boost)
        guard audible else { engine?.pause(); return }
        engine?.volume = Float(volume * (0.04 + min(1,level) * 0.13 + (input.boost ? 0.05:0)))
        if engine?.isPlaying == false { engine?.play() }
    }
    func stop() { engine?.pause(); contact?.stop() }
    func impact(volume: Double) {
        guard volume > 0 else { return }
        contact?.currentTime = 0; contact?.volume = Float(volume * 0.28); contact?.play()
    }
    private static func wave(duration: Double, impact: Bool) -> Data {
        let sampleRate = 22_050, count = Int(duration * Double(sampleRate))
        var pcm = Data(), seed: UInt32 = 19
        for i in 0..<count {
            seed = 1664525 &* seed &+ 1013904223
            let noise = Double(seed & 65535)/32768-1
            let time = Double(i)/Double(sampleRate)
            let envelope = impact ? exp(-time*16) : 1
            let value = (sin(2 * .pi * (impact ? 90:66) * time)*0.4 + noise*0.2)*envelope
            var sample = Int16(clamp(value,-1,1)*32767).littleEndian
            withUnsafeBytes(of:&sample) { pcm.append(contentsOf:$0) }
        }
        var data = Data("RIFF".utf8)
        func append32(_ value:UInt32) { var v=value.littleEndian; withUnsafeBytes(of:&v) { data.append(contentsOf:$0) } }
        func append16(_ value:UInt16) { var v=value.littleEndian; withUnsafeBytes(of:&v) { data.append(contentsOf:$0) } }
        append32(UInt32(36+pcm.count)); data.append(Data("WAVEfmt ".utf8)); append32(16)
        append16(1); append16(1); append32(UInt32(sampleRate)); append32(UInt32(sampleRate*2)); append16(2); append16(16)
        data.append(Data("data".utf8)); append32(UInt32(pcm.count)); data.append(pcm); return data
    }
}
