import SwiftUI
import FlightCore

struct MissionPicker: View {
    @ObservedObject var model: GameModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Jurnalul misiunilor").font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text("\(model.completedCount) din 6 misiuni finalizate · progres salvat pe acest Mac")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Button("Închide") { model.showMissions = false }.buttonStyle(QuietButton())
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Mission.all.prefix(6)) { mission in
                    Button { model.load(mission) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(String(format: "%02d", mission.id + 1)).font(.system(size: 11, design: .monospaced))
                                Spacer()
                                if model.records[String(mission.id)] != nil { Image(systemName: "checkmark.seal.fill") }
                            }.foregroundStyle(Color(nsColor: Palette.planet(mission.accent)))
                            Text(mission.title).font(.system(size: 20, weight: .medium, design: .rounded))
                            Text(mission.concept).font(.system(size: 11)).foregroundStyle(Palette.muted)
                            Text(String(format: "g %.2f m/s²   ·   masă %.0f kg", mission.gravity, mission.dryMass))
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.mission.id == mission.id ? Palette.accent : .white.opacity(0.08)))
                    }.buttonStyle(.plain)
                }
            }
            Button { model.load(Mission.all[6]) } label: {
                HStack(spacing: 16) {
                    Image(systemName: "flask").font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Laborator orbital").font(.system(size: 20, weight: .medium, design: .rounded))
                        Text("Schimbă legile mediului. Măsoară. Compară. Exportă CSV.").font(.system(size: 12))
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                }.foregroundStyle(Palette.accent).padding(20)
                    .background(Palette.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
        }.padding(28).frame(width: 800).background(Palette.background).preferredColorScheme(.dark)
    }
}

struct ControllerView: View {
    @ObservedObject var model: GameModel
    @ObservedObject var midi: MIDIService
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Pupitrul tău de comandă").font(.system(size: 27, weight: .semibold, design: .rounded))
                    Text("AKAI MPK mini IV · \(model.profile.bindings.count)/24 comenzi asociate · \(model.observed.count)/24 observate în această sesiune")
                        .font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Button("Gata") { model.closeController() }.buttonStyle(AccentButton())
            }
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: midi.sources.isEmpty ? "cable.connector.slash" : "cable.connector").foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(midi.sources.isEmpty ? "Niciun port MIDI. Conectează AKAI prin USB și apasă Reîmprospătează." : midi.sources.joined(separator: "  •  "))
                        .font(.system(size: 10)).foregroundStyle(Palette.muted)
                    Text(midi.error ?? midi.lastMessage).font(.system(size: 10, design: .monospaced)).lineLimit(2)
                }
                Spacer()
                Button("Reîmprospătează") { midi.refresh() }.buttonStyle(QuietButton())
            }.padding(12).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))

            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    Text("Profil automat: pe AKAI alege modul DAW (butonul PLUGIN/DAW). K1–K8 trimit CC 24–31 relative pe portul DAW; clapele și padurile folosesc portul MIDI. Oprește ARP / LATCH / NOTE REPEAT / CHORDS / SCALES. Pentru un USER preset personalizat, folosește asocierea manuală de mai jos. Jocul nu modifică presetul sau firmware-ul.")
                        .font(.system(size: 11)).lineSpacing(3).foregroundStyle(Palette.muted)
                    HStack {
                        Text("2. Modul potențiometrelor:").font(.system(size: 11))
                        Picker("Mod potențiometre", selection: $model.learnMode) {
                            ForEach(KnobMode.allCases) { mode in Text(mode.label).tag(mode) }
                        }.labelsHidden().frame(width: 210)
                        Spacer()
                        Button("Asociază toate · 24 pași") { model.startLearning(.thrust, all: true) }.buttonStyle(AccentButton())
                    }
                    Text("Rotește un K în ambele direcții și citește valorile de mai sus. Valori care cresc/scad în intervalul 0–127: Absolut. Valori mici la dreapta și 127, 65 sau 63 la stânga: alege modul relativ corespunzător. Modul ales se salvează la asocierea fiecărui K.")
                        .font(.system(size: 10)).lineSpacing(3).foregroundStyle(Palette.muted)
                    HStack {
                        Image(systemName: model.learning == nil ? "hand.tap" : "antenna.radiowaves.left.and.right")
                        Text(model.learnMessage).font(.system(size: 12)).lineSpacing(3)
                        Spacer()
                        if model.learning != nil {
                            Button("Oprește") { model.learning = nil }.buttonStyle(QuietButton())
                        }
                    }.foregroundStyle(Palette.accent).padding(14)
                        .background(Palette.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))

                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("8 PADURI · ACȚIUNI", icon: "square.grid.2x2")
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                                ForEach(Array(ControlAction.hardwareActions[6..<14])) { action in controlCard(action, shape: "pad") }
                            }
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("8 POTENȚIOMETRE · REGLAJE", icon: "dial.medium")
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                                ForEach(Array(ControlAction.hardwareActions[14..<22])) { action in controlCard(action, shape: "knob") }
                            }
                        }
                    }
                    sectionTitle("6 CLAPE ALBE CONSECUTIVE · PROPULSOARE", icon: "pianokeys")
                    HStack(spacing: 6) {
                        ForEach(Array(ControlAction.hardwareActions.prefix(6))) { action in controlCard(action, shape: "key") }
                        ForEach(Array(ControlAction.hardwareActions.suffix(2))) { action in controlCard(action, shape: "wheel") }
                    }
                    Text("Apasă un card pentru asociere individuală. Click dreapta → Șterge pentru a elibera un control. În timpul configurării, zborul rămâne oprit. Verde = ultimul control observat; bifa = asociere salvată. Un pad și o clapă cu aceeași notă trebuie să folosească canale MIDI diferite.")
                        .font(.system(size: 10)).lineSpacing(3).foregroundStyle(Palette.muted)
                    Text("Nu ai AKAI? Apasă Gata: poți parcurge întregul joc cu tastatura și mouse-ul.")
                        .font(.system(size: 11)).foregroundStyle(Palette.accent)
                }
            }
        }.padding(26).frame(width: 940, height: 710).background(Palette.background).preferredColorScheme(.dark)
    }

    private func controlCard(_ action: ControlAction, shape: String) -> some View {
        let binding = model.profile.binding(for: action)
        let selected = model.learning == action
        let observed = model.lastControl == action
        return Button { model.startLearning(action) } label: {
            VStack(spacing: 7) {
                HStack(spacing: 4) {
                    if shape == "knob" { Image(systemName: "dial.min") }
                    Text(action.hardware).font(.system(size: 11, weight: .semibold, design: .monospaced))
                    if binding != nil { Image(systemName: "checkmark").font(.system(size: 8)) }
                }.foregroundStyle(selected || observed ? Palette.accent : .white)
                Text(action.label).font(.system(size: 9)).multilineTextAlignment(.center).lineLimit(2).frame(height: 25)
                Text(binding.map { "CH \($0.address.channel + 1) · \($0.address.kind.rawValue) \($0.address.number)" } ?? "De asociat")
                    .font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted).lineLimit(1)
                if action.isLabOnly { Text("LABORATOR").font(.system(size: 7, weight: .bold)).foregroundStyle(.purple) }
            }.padding(9).frame(maxWidth: .infinity).frame(height: 90)
                .background(selected || observed ? Palette.accent.opacity(0.10) : .white.opacity(0.035), in: RoundedRectangle(cornerRadius: shape == "knob" ? 16 : 7))
                .overlay(RoundedRectangle(cornerRadius: shape == "knob" ? 16 : 7).stroke(selected ? Palette.accent : .white.opacity(0.09)))
        }.buttonStyle(.plain).contextMenu {
            Button("Șterge asocierea") { model.removeBinding(action) }
        }
    }
}

struct HelpView: View {
    @ObservedObject var model: GameModel
    @State private var page = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bun venit la bord, Vlad.").font(.system(size: 29, weight: .semibold, design: .rounded))
                    Text("Un laborator de fizică pe care îl pilotezi.").font(.system(size: 14)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "sparkles").font(.system(size: 33)).foregroundStyle(Palette.accent)
            }
            Picker("Ghid", selection: $page) {
                Text("Primul zbor").tag(0); Text("Comenzi").tag(1); Text("Fizica modelului").tag(2)
            }.pickerStyle(.segmented)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if page == 0 {
                        help("01", "Conectează și pilotează", "Conectează MPK mini IV prin USB și alege modul DAW pe controller. Profilul cu K1–K8 relative se încarcă automat. Pentru un preset personalizat, Controller MIDI permite asocierea individuală sau a tuturor celor 24 de comenzi. Poți începe și fără controller.")
                        help("02", "Pilotează din potențiometre", "Apasă Spațiu pentru a începe. K1–K6 controlează independent puterea celor șase motoare: principal, invers, stânga, dreapta, rotație stânga, rotație dreapta. Motoarele rămân pornite la puterea aleasă. Rotirea lentă schimbă puterea cu 0,5% pe pas; rotirea rapidă are accelerație temperată. X sau Pad 8 oprește toate motoarele. Mod reglează numai clapele, fără să blocheze K1–K6.")
                        help("03", "Aterizează pe picioare", "Trenul absoarbe și un contact mai ferm: |vx| ≤ 3 m/s, |vy| ≤ 6 m/s, înclinare ≤ 15° și rotație ≤ 0,5 rad/s. Picioarele trebuie să fie coborâte și deasupra platformei. Aterizarea pe lateral, cu trenul retras sau la viteze mai mari provoacă o prăbușire. T stabilizează; B frânează folosind combustibil.")
                        help("04", "Transformă zborul într-un experiment", "Din Misiuni poți alege oricare dintre cele șase provocări sau Laboratorul. V afișează vectorii, F graficele. Exportă CSV pentru a analiza măsurătorile într-un tabel. Totul funcționează offline.")
                    } else if page == 1 {
                        help("⌨", "Tastatură", "W/S sau ↑/↓: propulsie principală/inversă. A/D sau ←/→: lateral. Q/E: rotație. Tab: impuls suplimentar. B: frână. T: stabilizare. G: tren. V: vectori. F: grafice. X: oprește toate motoarele. Spațiu: pornește/pauză. R: reia cu confirmare. Esc: pauză.")
                        help("♫", "AKAI", "Șase clape albe C–A: propulsie principală, inversă, stânga, dreapta, rotație stânga, rotație dreapta. Intensitatea lovirii clapei influențează puterea. Pitch controlează fin rotația; Mod reglează puterea la apăsare.")
                        help("▦", "Cele opt paduri", "1: impuls suplimentar (ținut). 2: frână (ținut). 3: stabilizare. 4: tren. 5: vectori. 6: grafice. 7: pauză. 8: oprește toate motoarele și stabilizarea, fără să anuleze viteza navei. Repetarea notelor trebuie oprită.")
                        help("◉", "Putere granulară, independentă", "K1: motor principal. K2: invers. K3/K4: lateral stânga/dreapta. K5/K6: rotație stânga/dreapta. K7: zoom. K8: viteza simulării. Fiecare motor are 0–100%, fără clapă ținută. Cursoarele și butoanele ± permit pași de 0,1%. Motoarele opuse consumă combustibil chiar dacă forțele se anulează.")
                    } else {
                        help("F", "Dinamica translației", "ΣF = m·a. Propulsoarele, greutatea G = m·g și rezistența aerului schimbă viteza. Motorul principal dezvoltă până la 40 kN. Înclinarea navei schimbă direcția propulsiei; forțele laterale sunt relative la navă.")
                        help("p", "Impuls și combustibil", "p = m·v. Masa totală = masă uscată + combustibil. Propulsia și stabilizarea consumă combustibil, astfel că masa scade. Nava singură este un sistem deschis: pentru conservarea impulsului trebuie incluse gazele evacuate.")
                        help("E", "Energie", "Ec = ½mv²; Ep = mgh, cu h măsurat deasupra poziției de contact. Energia mecanică se conservă aproximativ doar fără propulsie, fără rezistență și la masă constantă. Fără aer, mase diferite cad cu aceeași accelerație.")
                        help("≈", "Limitele modelului", "Model educativ 2D: gravitație locală uniformă, F_aer = −c·|v|·v, sol plan și corp rigid simplificat. Pas de calcul 1/120 s. Nu simulează orbite, aerodinamică completă sau deformarea navei. Vectorii au scări vizuale diferite, indicate prin v, F și G.")
                    }
                }.padding(.vertical, 8)
            }
            HStack {
                Text("Mac Apple Silicon · offline · fără cont").font(.system(size: 10)).foregroundStyle(Palette.muted)
                Spacer()
                Button("Încep cu tastatura") { model.finishOnboarding() }.buttonStyle(QuietButton())
                Button("Configurează AKAI") {
                    model.finishOnboarding()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { model.openController() }
                }.buttonStyle(AccentButton())
            }
        }.padding(30).frame(width: 760, height: 590).background(Palette.background).preferredColorScheme(.dark)
    }
    private func help(_ number: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 17) {
            Text(number).font(.system(size: 18, weight: .medium, design: .monospaced)).foregroundStyle(Palette.accent).frame(width: 32)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(body).font(.system(size: 12)).lineSpacing(4).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
