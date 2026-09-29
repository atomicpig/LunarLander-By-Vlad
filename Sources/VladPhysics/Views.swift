import SwiftUI
import FlightCore

struct ContentView: View {
    @ObservedObject var model: GameModel
    let midi: MIDIService
    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            HStack(spacing: 0) {
                flightArea
                Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
                TelemetryPanel(model: model).frame(width: 290)
            }
            ControlsBar(model: model)
        }
        .background(Palette.background).foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .frame(minWidth: 1100, minHeight: 760)
        .sheet(isPresented: $model.showMissions) { MissionPicker(model: model) }
        .sheet(isPresented: $model.showController, onDismiss: { model.closeController() }) {
            ControllerView(model: model, midi: midi)
        }
        .sheet(isPresented: $model.showHelp, onDismiss: { model.finishOnboarding() }) { HelpView(model: model) }
        .alert("Reîncepi încercarea?", isPresented: $model.confirmRestart) {
            Button("Anulează", role: .cancel) {}
            Button("Reîncepe") { model.restart() }
        } message: { Text("Măsurătorile acestei încercări vor fi înlocuite. Poți anula și exporta CSV înainte.") }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "paperplane.fill").font(.system(size: 23)).rotationEffect(.degrees(-15))
                .foregroundStyle(Palette.accent).frame(width: 42, height: 42)
                .background(Palette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text("PROIECTUL DE FIZICĂ AL LUI VLAD").font(.system(size: 14, weight: .bold, design: .rounded)).tracking(1.2)
                Text("Un mic pas pentru pilot. Un salt în înțelegerea fizicii.")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 15)
            Button { model.openController() } label: {
                HStack(spacing: 7) {
                    Circle().fill(model.hasAKAI ? Palette.accent : .orange).frame(width: 6, height: 6)
                    Text(model.hasAKAI ? (model.profile.bindings.count < 24 ? "AKAI · \(model.profile.bindings.count)/24" : "AKAI · Conectat") : "Controller MIDI")
                }.font(.system(size: 11, weight: .medium))
            }.buttonStyle(QuietButton())
            Button { model.pause(); model.showMissions = true } label: { Label("Misiuni", systemImage: "square.grid.2x2") }
                .buttonStyle(QuietButton())
            Button { model.pause(); model.showHelp = true } label: { Image(systemName: "questionmark.circle") }
                .buttonStyle(QuietButton()).help("Instrucțiuni și formule")
        }.padding(.horizontal, 22).frame(height: 78)
    }

    private var flightArea: some View {
        ZStack {
            FlightCanvas(model: model)
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(model.mission.location).font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(2).foregroundStyle(Palette.accent)
                        Text(model.mission.title).font(.system(size: 31, weight: .semibold, design: .rounded))
                        Text(model.mission.concept).font(.system(size: 12)).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(model.mission.isLab ? "LABORATOR" : String(format: "MISIUNEA %02d / 06", model.mission.id + 1))
                            .font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(.white.opacity(0.07), in: Capsule())
                        FlightClock(telemetry: model.telemetry)
                    }
                }.padding(25)
                Spacer()
                if model.showGraphs {
                    LiveGraphs(model: model, telemetry: model.telemetry).frame(height: 155).padding(.horizontal, 20).padding(.bottom, 12)
                }
                if let toast = model.toast {
                    HStack {
                        Text(toast).font(.system(size: 11))
                        Spacer()
                        Button { model.toast = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                    }.padding(12).background(Palette.panel.opacity(0.97), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 20).padding(.bottom, 10)
                }
                HStack {
                    Label(String(format: "g = %.2f m/s²", model.world.gravity), systemImage: "arrow.down")
                    Spacer()
                    Text("← vx ≤ 3 m/s   ↓ vy ≤ 6 m/s   ∠ ≤ 15°")
                }.font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                    .padding(.horizontal, 25).padding(.bottom, 18)
            }
            if model.world.outcome != .flying { outcomeCard }
            else if model.paused && !model.isOverlayOpen { pauseCard }
        }.clipped()
    }

    private var pauseCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(model.world.elapsed == 0 ? "PREGĂTIT DE LANSARE" : "ZBOR ÎN PAUZĂ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(Palette.accent)
                Spacer()
                Image(systemName: model.world.elapsed == 0 ? "sparkle" : "pause.fill").foregroundStyle(Palette.accent)
            }
            Text(model.world.elapsed == 0 ? model.mission.briefing : "Ia-ți un moment. Citește instrumentele și pregătește următoarea manevră.")
                .font(.system(size: 14)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
            Text(model.mission.hint).font(.system(size: 11)).foregroundStyle(Palette.muted)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button { model.togglePause() } label: { Label(model.world.elapsed == 0 ? "Începe zborul" : "Continuă", systemImage: "play.fill") }
                    .buttonStyle(AccentButton())
                Spacer()
                Text("SPAȚIU / PAD 7").font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted)
            }
        }.padding(24).frame(width: 370)
            .background(Palette.panel.opacity(0.97), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.3), radius: 35, y: 12)
    }

    private var outcomeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: model.world.outcome == .landed ? "checkmark.seal.fill" : "arrow.counterclockwise.circle")
                .font(.system(size: 35)).foregroundStyle(model.world.outcome == .landed ? Palette.accent : .orange)
            Text(model.world.outcome == .landed ? "Aterizare reușită." : "Fiecare încercare te învață.")
                .font(.system(size: 25, weight: .semibold, design: .rounded))
            Text(model.world.outcomeDetail).font(.system(size: 13)).lineSpacing(3)
            HStack(spacing: 22) {
                metric("VITEZĂ VERTICALĂ", String(format: "%.2f m/s", abs(model.world.velocity.y)))
                metric("COMBUSTIBIL", String(format: "%.1f kg", model.world.fuel))
            }
            Text(model.mission.hint).font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(3)
            HStack {
                Button("Reîncearcă") { model.restart() }.buttonStyle(QuietButton())
                if model.world.outcome == .landed && model.mission.id < 5 {
                    Button("Următoarea misiune →") { model.load(Mission.all[model.mission.id + 1]) }.buttonStyle(AccentButton())
                } else { Button("Exportă CSV") { model.exportCSV() }.buttonStyle(AccentButton()) }
            }
        }.padding(26).frame(width: 410).background(Palette.panel, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12)))
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
            Text(value).font(.system(size: 18, design: .monospaced))
        }
    }
}

struct TelemetryPanel: View {
    @ObservedObject var model: GameModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                FlightInstruments(telemetry: model.telemetry, initialFuel: model.mission.fuel)
                Divider().overlay(.white.opacity(0.03))
                HStack(spacing: 6) {
                    status("Tren", on: model.world.gear, action: .gear)
                    status("Stabilizare", on: model.stabilize, action: .stabilize)
                }
                sectionTitle("6 MOTOARE · CONTROL DIRECT", icon: "slider.horizontal.3")
                Text(model.paused ? "Pornește zborul pentru a regla motoarele." : "Puterea se menține până revii la zero. X / Pad 8 oprește toate motoarele.")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
                VStack(spacing: 8) {
                    ForEach(ControlAction.engines) { action in
                        EngineAdjustment(model: model, gauge: model.engineGauges[action]!, action: action)
                    }
                }
                HoverReadout(telemetry: model.telemetry)
                adjustment("K7 · Zoom", value: model.zoom, range: 0.75...2, format: "%.2f×") { model.setAxis(.zoom, ($0 - 0.75) / 1.25) }
                adjustment("K8 · Viteza simulării", value: model.timeScale, range: 0.25...2, format: "%.2f×") { model.setAxis(.timeScale, ($0 - 0.25) / 1.75) }
                adjustment("Mod · Putere la apăsare", value: model.modulation, range: 0...1, format: "%.0f %%", multiplier: 100) { model.setAxis(.modulation, $0) }
                if model.mission.isLab {
                    Divider()
                    sectionTitle("PARAMETRII EXPERIMENTULUI", icon: "flask")
                    adjustment("Gravitație", value: model.world.gravity, range: 0...15, format: "%.2f m/s²") { model.setAxis(.gravity, $0 / 15) }
                    adjustment("Masă uscată", value: model.world.dryMass, range: 500...3_000, format: "%.0f kg") { model.setAxis(.mass, ($0 - 500) / 2_500) }
                    adjustment("Rezistența aerului", value: model.world.drag, range: 0...15, format: "%.2f kg/m") { model.setAxis(.drag, $0 / 15) }
                    Text("Schimbarea parametrilor resetează măsurătoarea și pune zborul pe pauză. K8 schimbă doar viteza redării.")
                        .font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("F = m · a").font(.system(size: 23, weight: .medium, design: .serif)).foregroundStyle(Palette.accent)
                    Text("Forța rezultantă schimbă viteza. Fără forță rezultantă, mișcarea continuă uniform.")
                        .font(.system(size: 11)).lineSpacing(3).foregroundStyle(Palette.muted)
                    EnergyReadout(telemetry: model.telemetry)
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.accent.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                Button { model.exportCSV() } label: { Label("Exportă măsurătorile CSV", systemImage: "square.and.arrow.up") }
                    .buttonStyle(QuietButton())
            }.padding(20)
        }.background(Palette.panel.opacity(0.6))
    }
    private func status(_ text: String, on: Bool, action: ControlAction) -> some View {
        Button { model.trigger(action) } label: {
            HStack(spacing: 5) { Circle().fill(on ? Palette.accent : Palette.muted).frame(width: 5, height: 5); Text(text) }
                .font(.system(size: 10)).padding(9).frame(maxWidth: .infinity)
                .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain)
    }
    private func adjustment(_ text: String, value: Double, range: ClosedRange<Double>, format: String,
                            multiplier: Double = 1, set: @escaping (Double) -> Void) -> some View {
        VStack(spacing: 3) {
            HStack { Text(text).foregroundStyle(Palette.muted); Spacer(); Text(String(format: format, value * multiplier)).monospacedDigit() }
                .font(.system(size: 10))
            Slider(value: Binding(get: { value }, set: set), in: range).controlSize(.mini).tint(Palette.accent)
                .accessibilityLabel(text)
        }
    }
}

func sectionTitle(_ title: String, icon: String) -> some View {
    HStack(spacing: 7) { Image(systemName: icon); Text(title).tracking(1.1) }
        .font(.system(size: 9, weight: .semibold)).foregroundStyle(Palette.muted)
}

struct ControlsBar: View {
    @ObservedObject var model: GameModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("COMENZI DE ZBOR", icon: "pianokeys")
                Text("Clape: ține apăsat · K1–K6: putere continuă · X: oprire motoare")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
                Spacer()
                Button { model.setMuted(!model.muted) } label: { Image(systemName: model.muted ? "speaker.slash" : "speaker.wave.2") }
                    .buttonStyle(.plain).foregroundStyle(Palette.muted).help("Sunete pornite / oprite")
            }
            HStack(spacing: 6) {
                ForEach(Array(zip([ControlAction.thrust, .reverse, .left, .right, .rotateLeft, .rotateRight, .boost, .brake],
                                  ["W ↑", "S ↓", "A ←", "D →", "Q ↶", "E ↷", "TAB", "B"])), id: \.0) { action, key in
                    HoldControl(model: model, action: action, key: key)
                }
                Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 32).padding(.horizontal, 6)
                actionButton("Vectori", key: "V", action: .vectors, selected: model.showVectors)
                actionButton("Grafice", key: "F", action: .graphs, selected: model.showGraphs)
                actionButton("Oprire", key: "X", action: .cutEngines, selected: false)
                actionButton(model.paused ? "Pornește" : "Pauză", key: "SPAȚIU", action: .pause, selected: false)
                actionButton("Reia", key: "R", action: .restart, selected: false)
            }
        }.padding(.horizontal, 22).padding(.vertical, 16)
            .background(Palette.panel)
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }
    private func actionButton(_ label: String, key: String, action: ControlAction, selected: Bool) -> some View {
        Button { model.trigger(action) } label: {
            VStack(spacing: 5) {
                Text(key).font(.system(size: 9, weight: .semibold, design: .monospaced))
                Text(label).font(.system(size: 9))
            }.frame(maxWidth: .infinity).frame(height: 43)
                .background(selected ? Palette.accent.opacity(0.13) : .white.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(selected ? Palette.accent : .white)
        }.buttonStyle(.plain)
    }
}

struct HoldControl: View {
    @ObservedObject var model: GameModel
    let action: ControlAction
    let key: String
    var body: some View {
        VStack(spacing: 5) {
            Text(key).font(.system(size: 12, weight: .medium, design: .monospaced))
            Text(action.hardware).font(.system(size: 8)).foregroundStyle(Palette.muted)
        }.frame(maxWidth: .infinity).frame(height: 43)
            .background(model.activeActions.contains(action) ? Palette.accent.opacity(0.25) : .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(model.activeActions.contains(action) ? Palette.accent : .white.opacity(0.08)))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in model.setHeld(action, value: 1, source: "mouse") }
                .onEnded { _ in model.setHeld(action, value: 0, source: "mouse") })
            .help(action.label).accessibilityLabel(action.label)
    }
}

struct GraphPanel: View {
    let samples: [TelemetrySample]
    @State private var mode = 0
    private var series: [(String, Color, [Double])] {
        let points = Array(samples.suffix(300))
        switch mode {
        case 1: return [("vx", .cyan, points.map(\.vx)), ("vy", .orange, points.map(\.vy))]
        case 2: return [("Ec", .cyan, points.map { $0.kinetic / 1000 }), ("Ep", .orange, points.map { $0.potential / 1000 })]
        default: return [("h", Palette.accent, points.map(\.altitude))]
        }
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("TELEMETRIE · ultimele 30 s").font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted)
                Spacer()
                Picker("Grafic", selection: $mode) { Text("h · m").tag(0); Text("v · m/s").tag(1); Text("E · kJ").tag(2) }
                    .pickerStyle(.segmented).frame(width: 230).controlSize(.mini)
            }
            GeometryReader { geo in
                let all = series.flatMap { $0.2 }
                let low = min(0, all.min() ?? 0), high = max(1, all.max() ?? 1)
                Canvas { context, size in
                    for fraction in [0.0, 0.5, 1.0] {
                        var line = Path(); line.move(to: .init(x: 35, y: fraction * size.height))
                        line.addLine(to: .init(x: size.width, y: fraction * size.height))
                        context.stroke(line, with: .color(.white.opacity(0.08)), lineWidth: 1)
                    }
                    for (_, color, values) in series where values.count > 1 {
                        var path = Path()
                        for (index, value) in values.enumerated() {
                            let point = CGPoint(x: 35 + Double(index) / Double(values.count - 1) * (size.width - 35),
                                                y: (1 - (value - low) / (high - low)) * size.height)
                            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                        context.stroke(path, with: .color(color), lineWidth: 1.6)
                    }
                }
                VStack { Text(String(format: "%.0f", high)); Spacer(); Text(String(format: "%.0f", low)) }
                    .font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
            }
            HStack {
                Text(String(format: "%.1f s", samples.suffix(300).first?.time ?? 0))
                Spacer()
                ForEach(series, id: \.0) { name, color, _ in Text("● \(name)").foregroundStyle(color) }
                Spacer()
                Text(String(format: "%.1f s", samples.last?.time ?? 0))
            }.font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
        }.padding(14).background(Palette.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 9)
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.6 : 0.9))
            .background(.white.opacity(configuration.isPressed ? 0.10 : 0.045), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.08)))
    }
}
struct AccentButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold)).padding(.horizontal, 16).padding(.vertical, 11)
            .foregroundStyle(Palette.background)
            .background(Palette.accent.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct FlightInstruments: View {
    @ObservedObject var telemetry: FlightTelemetry
    let initialFuel: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("INSTRUMENTE DE BORD", icon: "waveform.path.ecg")
            InstrumentReadout(world: telemetry.world, initialFuel: initialFuel).frame(height: 233)
        }
    }
}

struct FlightClock: View {
    @ObservedObject var telemetry: FlightTelemetry
    var body: some View {
        Text(String(format: "T + %05.1f s", telemetry.world.elapsed))
            .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted)
    }
}
struct EnergyReadout: View {
    @ObservedObject var telemetry: FlightTelemetry
    var body: some View {
        Text(String(format: "Ec %.1f kJ  ·  Ep %.1f kJ", telemetry.world.kineticEnergy / 1000, telemetry.world.potentialEnergy / 1000))
            .font(.system(size: 9, design: .monospaced))
    }
}
struct HoverReadout: View {
    @ObservedObject var telemetry: FlightTelemetry
    var body: some View {
        if telemetry.world.gravity > 0 {
            Text(String(format: "Plutire ≈ %.1f%% K1, cu nava verticală. Sub acest prag încă există accelerație în jos.",
                        telemetry.world.mass * telemetry.world.gravity / Physics.maxMainForce * 100))
                .font(.system(size: 10)).foregroundStyle(Palette.accent).fixedSize(horizontal: false, vertical: true)
        }
    }
}
struct LiveGraphs: View {
    let model: GameModel
    @ObservedObject var telemetry: FlightTelemetry
    var body: some View { GraphPanel(samples: model.samples) }
}

struct EngineAdjustment: View {
    @ObservedObject var model: GameModel
    @ObservedObject var gauge: EngineGauge
    let action: ControlAction
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(action.hardware) · \(action.label)").foregroundStyle(gauge.level > 0 ? Palette.accent : Palette.muted)
                Spacer()
                Text(String(format: "%.1f%%", gauge.level * 100)).monospacedDigit()
            }.font(.system(size: 10))
            HStack(spacing: 6) {
                Button("−") { model.setAxis(action, max(0, gauge.level - 0.001)) }.buttonStyle(.plain).help("Scade cu 0,1%")
                Slider(value: Binding(get: { model.engineLevels[action] ?? 0 }, set: { model.setAxis(action, $0) }), in: 0...1, step: 0.001)
                    .controlSize(.mini).tint(Palette.accent).accessibilityLabel("\(action.hardware) \(action.label)")
                Button("+") { model.setAxis(action, min(1, gauge.level + 0.001)) }.buttonStyle(.plain).help("Crește cu 0,1%")
            }.disabled(model.paused)
        }
    }
}
