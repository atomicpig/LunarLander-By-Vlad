import SwiftUI
import FlightCore

struct ControllerSheet:View {
    @ObservedObject var game:LanderModel
    @ObservedObject var midi:MIDIService
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {
                VStack(alignment:.leading,spacing:5) {
                    Text("PUPITRU AKAI").font(.system(size:25,weight:.bold,design:.monospaced))
                    Text("Profilul vechi este păstrat; padurile au acum impulsuri de zbor.").font(.system(size:12)).foregroundStyle(Theme.dim)
                }
                Spacer(); Button("Gata") { game.showController = false }.buttonStyle(LaunchButton())
            }
            Text(midi.sources.isEmpty ? "Conectează MPK mini IV prin USB sau joacă din tastatură." : midi.sources.joined(separator:" · "))
                .font(.system(size:10,design:.monospaced)).foregroundStyle(Theme.mint)
            Text("AKAI: modul DAW. Dezactivează ARP, LATCH, NOTE REPEAT, CHORDS și SCALES. K1–K8 folosesc portul DAW; clapele și padurile folosesc portul MIDI. Click pe o comandă pentru reasociere; click dreapta pentru ștergere.")
                .font(.system(size:11)).foregroundStyle(Theme.dim).fixedSize(horizontal:false,vertical:true)
            HStack {
                Picker("Encodere",selection:$game.learnMode) { ForEach(KnobMode.allCases) { Text($0.label).tag($0) } }.frame(width:300)
                Spacer(); Button("Reîmprospătează") { midi.refresh() }.buttonStyle(ConsoleButton())
            }
            Text(game.learningMessage).font(.system(size:12)).foregroundStyle(Theme.amber)
            ScrollView {
                LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:4),spacing:8) {
                    ForEach(ControlAction.hardwareActions) { action in
                        Button { game.learn(action) } label: {
                            VStack(alignment:.leading,spacing:6) {
                                HStack { Text(action.hardware).font(.system(size:12,weight:.bold,design:.monospaced)); Spacer(); if game.profile.binding(for:action) != nil { Image(systemName:"checkmark") } }
                                Text(action.label).font(.system(size:10))
                                Text(game.profile.binding(for:action).map { "CH \($0.address.channel+1) · \($0.address.kind.rawValue) \($0.address.number)" } ?? "De asociat")
                                    .font(.system(size:9,design:.monospaced)).foregroundStyle(Theme.dim)
                            }.padding(12).frame(maxWidth:.infinity,alignment:.leading).frame(height:75)
                                .foregroundStyle(Theme.white).background(game.learning == action || game.lastControl == action ? Theme.mint.opacity(0.16):Theme.panel,in:RoundedRectangle(cornerRadius:8))
                        }.buttonStyle(.plain).contextMenu {
                            Button("Șterge asocierea") { game.profile.bindings.removeAll {$0.action == action}; game.saveProfile() }
                        }
                    }
                }
            }
            HStack {
                Text(midi.error ?? midi.lastMessage).font(.system(size:10,design:.monospaced)).foregroundStyle(Theme.dim).lineLimit(2)
                Spacer(); if game.learning != nil { Button("Anulează asocierea") { game.learning = nil }.buttonStyle(ConsoleButton()) }
            }
        }.padding(26).frame(width:850,height:710).background(Theme.ink).foregroundStyle(Theme.white).preferredColorScheme(.dark)
    }
}
struct Instructions:View {
    @ObservedObject var game:LanderModel
    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            HStack { Text("MIC GHID DE ASELENIZARE").font(.system(size:23,weight:.bold,design:.monospaced)); Spacer(); Button("Gata") { game.showHelp = false }.buttonStyle(LaunchButton()) }
            ScrollView {
                VStack(alignment:.leading,spacing:21) {
                    block("01 / ZBOR CU INERȚIE","Motoarele schimbă viteza, nu poziția. K1 împinge în sus, K2 în jos, K3/K4 lateral, K5/K6 rotesc. Puterile rămân active până le reduci. K1 la aproximativ 10–11% compensează gravitația lunară când nava este verticală; sub acest prag încă accelerezi în jos.")
                    block("02 / PADURI PENTRU CORECȚII","Padurile 1–6 dau impulsuri independente, puternice, de 0,24 s în aceleași direcții ca K1–K6. Eliberarea padului nu întrerupe impulsul. Pad 7 / B frânează timp de 0,55 s folosind combustibil. Pad 8 / X oprește toate motoarele, impulsurile și amortizarea imediat. Frânarea nu anulează instantaneu viteza.")
                    block("03 / PRECIZIE","K8 schimbă sensibilitatea encoderelor: 0,1–1% pe mesaj lent. P comută între fin și normal. K7 trece la zoom manual; C reactivează camera automată. T activează amortizarea rotației: consumă combustibil și păstrează unghiul ales, fără pilot automat de redresare.")
                    block("04 / PE PICIOARE","Pistele luminoase ×1 / ×3 / ×5 sunt singurele zone sigure. La contact: viteză verticală ≤ 6 m/s, laterală ≤ 3 m/s, unghi ≤ 15°, rotație ≤ 0,5 rad/s. Așteaptă stabilizarea pe picioare. Un contact sub 2 m/s aduce mai multe puncte; pistele înguste multiplică scorul.")
                    block("05 / EXPEDIȚIA","Ai trei vieți și 250 kg de combustibil la început. Aterizarea deschide un sector nou și adaugă 45 kg. Un accident costă o viață; următoarea navă primește minimum 70 kg pentru a putea continua. Pistele se îngustează treptat. Recordul se salvează pe acest Mac.")
                    block("FĂRĂ AKAI","W/S: principal/invers; A/D: lateral; Q/E: rotație. Tastele 1–8 reproduc padurile. Spațiu: pauză/continuă; Esc: pauză; R: reia cu confirmare și cost de o viață. Cursoarele de jos reglează motoarele în pași de 0,1%; săgețile tastaturii țin propulsoarele. Pitch: rotație fină; Mod: puterea clapelor, fără să afecteze dials sau paduri.")
                    HStack {
                        Text("Zoom manual")
                        Slider(value:Binding(get:{game.zoom},set:{game.zoom = $0; game.autoCamera = false}),in:0.75...1.5).frame(width:150)
                        Toggle("Cameră automată",isOn:$game.autoCamera)
                    }.font(.system(size:12))
                    HStack {
                        Text("Precizie encodere")
                        Slider(value:Binding(get:{game.precision},set:{game.setPrecision($0)}),in:0.2...2).frame(width:150)
                        Text(String(format:"%.1f%% pe pas lent",game.precision*0.5))
                    }.font(.system(size:12))
                    HStack {
                        Text("Volum"); Slider(value:$game.volume,in:0...1).frame(width:220)
                        Toggle("Sunete oprite",isOn:Binding(get:{game.muted},set:{game.setMuted($0)}))
                    }.font(.system(size:12))
                }
            }
        }.padding(28).frame(width:770,height:680).background(Theme.ink).foregroundStyle(Theme.white).preferredColorScheme(.dark)
    }
    private func block(_ title:String,_ text:String) -> some View {
        VStack(alignment:.leading,spacing:7) {
            Text(title).font(.system(size:11,weight:.bold,design:.monospaced)).foregroundStyle(Theme.mint)
            Text(text).font(.system(size:13)).lineSpacing(4).foregroundStyle(Theme.dim).fixedSize(horizontal:false,vertical:true)
        }
    }
}
