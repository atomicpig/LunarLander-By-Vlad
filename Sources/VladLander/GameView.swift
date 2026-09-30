import SwiftUI
import FlightCore

enum Theme {
    static let ink = Color(red:0.025,green:0.039,blue:0.060)
    static let panel = Color(red:0.055,green:0.076,blue:0.096)
    static let mint = Color(red:0.62,green:0.94,blue:0.79)
    static let amber = Color(red:1,green:0.69,blue:0.35)
    static let dim = Color(red:0.47,green:0.59,blue:0.61)
    static let white = Color(red:0.9,green:0.94,blue:0.91)
}

struct GameView:View {
    @ObservedObject var game:LanderModel
    var body:some View {
        VStack(spacing:0) {
            topBar
            ZStack {
                LunarCanvas(game:game)
                VStack(spacing:0) {
                    FlightHUD(telemetry:game.telemetry,sector:game.sector).padding(22)
                    if let text = game.notice {
                        Text(text).font(.system(size:11,weight:.medium,design:.monospaced))
                            .foregroundStyle(Theme.amber).padding(9).background(Theme.ink.opacity(0.9),in:Capsule())
                    }
                    Spacer()
                    HStack(alignment:.bottom) {
                        MiniMap(telemetry:game.telemetry,sector:game.sector).frame(width:220,height:70)
                        Spacer()
                        ApproachReadout(telemetry:game.telemetry,sector:game.sector)
                    }.padding(20)
                }.allowsHitTesting(false)
                if game.phase != .flying { phaseOverlay }
            }.clipped()
            Cockpit(game:game)
        }.background(Theme.ink).foregroundStyle(Theme.white).preferredColorScheme(.dark)
            .frame(minWidth:1120,minHeight:760)
            .sheet(isPresented:$game.showController,onDismiss:{game.learning = nil; game.clearInput()}) { ControllerSheet(game:game,midi:game.midi) }
            .sheet(isPresented:$game.showHelp) { Instructions(game:game) }
            .alert("Abandonezi zborul?",isPresented:$game.confirmRetry) {
                Button("Continuă pregătirea",role:.cancel) {}
                Button("Reîncearcă · −1 viață",role:.destructive) { game.retry() }
            } message: { Text("Motoarele sunt oprite. Reluarea unui zbor neterminat costă o viață.") }
    }
    private var topBar:some View {
        HStack(spacing:20) {
            HStack(spacing:9) {
                Image(systemName:"moonphase.waning.crescent").foregroundStyle(Theme.mint)
                Text("LUNAR LANDER").font(.system(size:13,weight:.black,design:.monospaced)).tracking(2)
                Text("/ VLAD").font(.system(size:10,design:.monospaced)).foregroundStyle(Theme.dim)
            }
            Spacer()
            Text(String(format:"SECTOR %02d",game.sectorNumber)).foregroundStyle(Theme.dim)
            Text(String(format:"SCOR %06d",game.score)).foregroundStyle(Theme.mint)
            HStack(spacing:5) { ForEach(0..<3) { i in Image(systemName:i<game.lives ? "diamond.fill":"diamond").foregroundStyle(i<game.lives ? Theme.amber:Theme.dim) } }
                .accessibilityLabel("\(game.lives) vieți")
            Button { game.openController() } label: { Label("AKAI",systemImage:game.hasController ? "cable.connector":"keyboard") }.buttonStyle(ConsoleButton())
            Button { game.pause(); game.showHelp = true } label: { Image(systemName:"questionmark") }.buttonStyle(ConsoleButton()).accessibilityLabel("Instrucțiuni")
            Button { game.togglePause() } label: { Image(systemName:game.running ? "pause.fill":"play.fill") }.buttonStyle(ConsoleButton()).accessibilityLabel("Pauză sau continuă")
        }.font(.system(size:11,weight:.medium,design:.monospaced)).padding(.horizontal,20).frame(height:56)
            .background(Theme.ink).overlay(alignment:.bottom) { Rectangle().fill(Theme.mint.opacity(0.13)).frame(height:1) }
    }
    @ViewBuilder private var phaseOverlay:some View {
        if game.phase == .title {
            HStack {
                VStack(alignment:.leading,spacing:18) {
                    Text("O SINGURĂ LUNĂ. O SINGURĂ ÎNCERCARE PERFECTĂ.")
                        .font(.system(size:9,weight:.semibold,design:.monospaced)).tracking(1.4).foregroundStyle(Theme.amber)
                    Text("LUNAR\nLANDER").font(.system(size:67,weight:.black,design:.rounded)).tracking(-3).lineSpacing(-6)
                    Text("Simte inerția. Dozează motoarele.\nAlege o pistă și aterizează pe picioare.")
                        .font(.system(size:15)).lineSpacing(5).foregroundStyle(Theme.dim)
                    HStack(spacing:12) {
                        Button("LANSEAZĂ  →") { game.newGame(); game.togglePause() }.buttonStyle(LaunchButton())
                        Button("Cum pilotezi") { game.showHelp = true }.buttonStyle(ConsoleButton())
                    }.padding(.top,6)
                    Text(String(format:"RECORD LOCAL  %06d",game.best)).font(.system(size:10,design:.monospaced)).foregroundStyle(Theme.mint)
                    Text("K1–K6 · motoare fine     PAD 1–6 · impulsuri puternice\nTastatură: W S A D Q E · impulsuri 1–6")
                        .font(.system(size:10,design:.monospaced)).lineSpacing(5).foregroundStyle(Theme.dim)
                }.padding(34).background(Theme.ink.opacity(0.84),in:RoundedRectangle(cornerRadius:20))
                Spacer(minLength:0)
            }.padding(.leading,64)
        } else {
            VStack(alignment:.leading,spacing:16) {
                Text(overlayEyebrow).font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(2).foregroundStyle(Theme.amber)
                Text(overlayTitle).font(.system(size:31,weight:.bold,design:.rounded))
                Text(overlayDetail).font(.system(size:13)).foregroundStyle(Theme.dim).lineSpacing(4).fixedSize(horizontal:false,vertical:true)
                if game.phase == .result || game.phase == .gameOver {
                    HStack(spacing:30) {
                        resultMetric("VITEZĂ LA CONTACT",String(format:"%.2f m/s",game.world.touchdown?.vy ?? abs(game.world.velocity.y)))
                        resultMetric("COMBUSTIBIL",String(format:"%.0f kg",game.world.fuel))
                    }
                    if game.world.outcome == .landed {
                        Text("+\(game.world.touchdown?.points ?? 0) PUNCTE  ·  ×\(game.world.touchdown?.site?.multiplier ?? 1)")
                            .font(.system(size:20,weight:.bold,design:.monospaced)).foregroundStyle(Theme.mint)
                        Text("Realimentare: +45 kg în sectorul următor.").font(.system(size:11)).foregroundStyle(Theme.dim)
                    }
                }
                HStack(spacing:10) {
                    Button(primaryLabel) {
                        if game.phase == .gameOver { game.newGame(); game.togglePause() }
                        else { game.togglePause() }
                    }.buttonStyle(LaunchButton())
                    if game.phase == .paused {
                        Button("Reîncearcă") { game.confirmRetry = true }.buttonStyle(ConsoleButton())
                    }
                    Text("SPAȚIU").font(.system(size:9,design:.monospaced)).foregroundStyle(Theme.dim)
                }
            }.padding(28).frame(width:410).background(Theme.panel.opacity(0.98),in:RoundedRectangle(cornerRadius:16))
                .overlay(RoundedRectangle(cornerRadius:16).stroke(Theme.mint.opacity(0.2)))
                .shadow(color:.black.opacity(0.5),radius:30,y:12)
        }
    }
    private var overlayEyebrow:String {
        switch game.phase { case .ready:return "SECTOR \(game.sectorNumber) · PREGĂTIT"; case .paused:return "ZBOR ÎN PAUZĂ"
        case .gameOver:return "SFÂRȘITUL EXPEDIȚIEI"; default:return game.world.outcome == .landed ? "CONTACT CONFIRMAT":"ÎNCERCARE ÎNCHEIATĂ" }
    }
    private var overlayTitle:String {
        switch game.phase { case .ready:return "Alege-ți aterizarea."; case .paused:return "Respiră. Pregătește manevra."
        case .gameOver:return "Încă un zbor?"; default:return game.world.outcome == .landed ? "Luna e a ta.":"Mai aproape data viitoare." }
    }
    private var overlayDetail:String {
        if game.phase == .ready { return "Trei piste. ×1 este generoasă, ×3 cere precizie, ×5 răsplătește riscul. Limite: 6 m/s vertical, 3 m/s lateral și 15°." }
        if game.phase == .paused { return "Motoarele și impulsurile sunt la zero. Spațiu continuă zborul; potențiometrele absolute trebuie readuse întâi la zero." }
        return game.world.detail
    }
    private var primaryLabel:String { game.phase == .gameOver ? "JOC NOU →" : (game.phase == .result ? (game.world.outcome == .landed ? "SECTORUL URMĂTOR →":"REÎNCEARCĂ →") : "CONTINUĂ →") }
    private func resultMetric(_ title:String,_ value:String) -> some View {
        VStack(alignment:.leading,spacing:5) { Text(title).font(.system(size:8,design:.monospaced)).foregroundStyle(Theme.dim); Text(value).font(.system(size:18,weight:.medium,design:.monospaced)) }
    }
}

struct FlightHUD:View {
    @ObservedObject var telemetry:Telemetry
    let sector:MoonSector
    var body:some View {
        let w = telemetry.world, altitude = max(0,Physics.clearance(w,sector:sector))
        HStack(alignment:.top,spacing:30) {
            value("ALTITUDINE",String(format:"%05.1f",altitude),"m",color:Theme.white)
            value("COBORÂRE",String(format:"%04.1f",w.velocity.y < -0.05 ? -w.velocity.y : 0.0),"m/s",color:abs(w.velocity.y) > 6 ? Theme.amber:Theme.mint)
            value("LATERAL",String(format:"%+.1f",w.velocity.x),"m/s",color:abs(w.velocity.x) > 3 ? Theme.amber:Theme.mint)
            Spacer()
            VStack(alignment:.trailing,spacing:8) {
                Text("COMBUSTIBIL  \(Int(w.fuel)) kg").font(.system(size:11,weight:.medium,design:.monospaced)).foregroundStyle(w.fuel < 35 ? Theme.amber:Theme.white)
                HStack(spacing:3) { ForEach(0..<25) { i in Rectangle().fill(Double(i)<w.fuel/10 ? Theme.mint:Theme.dim.opacity(0.18)).frame(width:5,height:10) } }
                Text(String(format:"LUNĂ · g 1,62   T+%05.1f",w.elapsed)).font(.system(size:9,design:.monospaced)).foregroundStyle(Theme.dim)
            }
        }.padding(14).background(Theme.ink.opacity(0.7),in:RoundedRectangle(cornerRadius:10)).accessibilityElement(children:.combine)
    }
    private func value(_ title:String,_ text:String,_ unit:String,color:Color) -> some View {
        VStack(alignment:.leading,spacing:5) {
            Text(title).font(.system(size:8,design:.monospaced)).tracking(1.5).foregroundStyle(Theme.dim)
            HStack(alignment:.firstTextBaseline,spacing:5) { Text(text).font(.system(size:25,weight:.medium,design:.monospaced)); Text(unit).font(.system(size:9,design:.monospaced)).foregroundStyle(Theme.dim) }.foregroundStyle(color)
        }
    }
}
struct ApproachReadout:View {
    @ObservedObject var telemetry:Telemetry
    let sector:MoonSector
    var body:some View {
        let w = telemetry.world, pad = sector.nearestSite(to:w.position.x)
        let aligned = Physics.padUnderFeet(w,sector:sector)?.id == pad.id
        VStack(alignment:.trailing,spacing:7) {
            Text(w.outcome == .settling ? "CONTACT · AMORTIZARE" : String(format:"PISTA ×%d   %+.0f m",pad.multiplier,pad.x-w.position.x))
                .font(.system(size:12,weight:.semibold,design:.monospaced)).foregroundStyle(aligned ? Theme.mint:Theme.amber)
            HStack(spacing:13) {
                condition("ALINIERE",aligned)
                condition("VITEZĂ",abs(w.velocity.y)<=6 && abs(w.velocity.x)<=3)
                condition(String(format:"∠ %.0f°",abs(w.angle)*180 / .pi),abs(w.angle)<=15 * .pi/180)
            }
        }.padding(12).background(Theme.ink.opacity(0.82),in:RoundedRectangle(cornerRadius:9))
    }
    private func condition(_ name:String,_ valid:Bool) -> some View {
        Label(name,systemImage:valid ? "checkmark.circle.fill":"circle").font(.system(size:8,design:.monospaced)).foregroundStyle(valid ? Theme.mint:Theme.dim)
    }
}
struct MiniMap:View {
    @ObservedObject var telemetry:Telemetry
    let sector:MoonSector
    var body:some View {
        VStack(alignment:.leading,spacing:5) {
            Text("SECTOR LUNAR / ×1  ×3  ×5").font(.system(size:8,design:.monospaced)).tracking(1).foregroundStyle(Theme.dim)
            Canvas { context,size in
                let sx = size.width/sector.width, sy = size.height/450
                var path = Path()
                for (i,p) in sector.vertices.enumerated() {
                    let pt = CGPoint(x:p.x*sx,y:size.height-p.y*sy)
                    if i == 0 {path.move(to:pt)} else {path.addLine(to:pt)}
                }
                context.stroke(path,with:.color(Theme.dim),lineWidth:1)
                for pad in sector.sites {
                    var line = Path(); line.move(to:.init(x:pad.left*sx,y:size.height-pad.height*sy))
                    line.addLine(to:.init(x:pad.right*sx,y:size.height-pad.height*sy))
                    context.stroke(line,with:.color(Theme.mint),lineWidth:3)
                }
                let w = telemetry.world
                let point = CGPoint(x:clamp(w.position.x*sx,2,size.width-2),y:clamp(size.height-w.position.y*sy,2,size.height-2))
                context.fill(Path(ellipseIn:.init(x:point.x-2,y:point.y-2,width:4,height:4)),with:.color(Theme.amber))
            }
        }.padding(10).background(Theme.ink.opacity(0.8),in:RoundedRectangle(cornerRadius:8))
            .accessibilityLabel("Hartă: poziția navei și cele trei piste")
    }
}

struct Cockpit:View {
    @ObservedObject var game:LanderModel
    var body:some View {
        VStack(spacing:12) {
            HStack(spacing:9) {
                Text("MOTOARE").font(.system(size:8,weight:.bold,design:.monospaced)).tracking(1).foregroundStyle(Theme.dim)
                ForEach(0..<6) { i in DialControl(game:game,dial:game.dials[i],index:i,enabled:game.running) }
                VStack(alignment:.leading,spacing:7) {
                    Button(game.precision < 0.5 ? "PRECIZIE · FIN":"PRECIZIE · NORMAL") { game.setPrecision(game.precision < 0.5 ? 1:0.2) }.buttonStyle(.plain)
                    Text(String(format:"K8 · %.1f%% / pas",game.precision*0.5)).foregroundStyle(Theme.dim)
                }.font(.system(size:8,design:.monospaced)).frame(width:116)
            }
            HStack(spacing:7) {
                Text("IMPULSURI").font(.system(size:8,weight:.bold,design:.monospaced)).tracking(1).foregroundStyle(Theme.dim)
                ForEach(0..<8) { i in
                    Button { game.fire(i) } label: {
                        HStack(spacing:6) {
                            Text(String(i+1)).font(.system(size:10,weight:.bold,design:.monospaced))
                                .foregroundStyle(Theme.amber)
                            Text(["↑ FORȚĂ","↓ INVERS","← STÂNGA","→ DREAPTA","↶ ROTIRE","↷ ROTIRE","FRÂNĂ","ZERO"][i])
                                .font(.system(size:8,weight:.semibold,design:.monospaced))
                        }.frame(maxWidth:.infinity).frame(height:31)
                            .background(game.activePad == i ? Theme.amber.opacity(0.25):.white.opacity(0.035),in:RoundedRectangle(cornerRadius:5))
                            .overlay(RoundedRectangle(cornerRadius:5).stroke(Theme.amber.opacity(0.18)))
                    }.buttonStyle(.plain).help("Pad \(i+1) / tasta \(i+1): \(ControlAction.bursts[i].label)")
                }
                Toggle("T · AMORTIZARE",isOn:$game.damping).toggleStyle(.button).font(.system(size:8,design:.monospaced)).controlSize(.mini)
                Button { game.setMuted(!game.muted) } label: { Image(systemName:game.muted ? "speaker.slash":"speaker.wave.1") }.buttonStyle(.plain).accessibilityLabel("Sunete pornite sau oprite")
            }
        }.padding(.horizontal,20).padding(.vertical,14).background(Theme.panel)
            .overlay(alignment:.top) { Rectangle().fill(Theme.mint.opacity(0.16)).frame(height:1) }
    }
}
struct DialControl:View {
    let game:LanderModel
    @ObservedObject var dial:EngineDial
    let index:Int
    let enabled:Bool
    var body:some View {
        VStack(spacing:4) {
            HStack(spacing:3) {
                Text("K\(index+1) \(["PRINCIPAL","INVERS","STÂNGA","DREAPTA","ROT ↶","ROT ↷"][index])").foregroundStyle(Theme.dim)
                Spacer(minLength:0)
                Text(String(format:"%.1f",dial.value*100)).foregroundStyle(dial.value > 0 ? Theme.mint:Theme.dim)
            }.font(.system(size:8,weight:.medium,design:.monospaced))
            Slider(value:Binding(get:{dial.value},set:{game.setEngine(index,$0)}),in:0...1,step:0.001)
                .controlSize(.mini).tint(Theme.mint).disabled(!enabled)
                .accessibilityLabel("K\(index+1) \(ControlAction.engines[index].label)")
            GeometryReader { geo in
                Rectangle().fill(Theme.mint.opacity(0.65)).frame(width:geo.size.width*min(1,dial.actual))
            }.frame(height:2).background(.white.opacity(0.035))
        }.frame(maxWidth:.infinity)
    }
}
struct ConsoleButton:ButtonStyle {
    func makeBody(configuration:Configuration) -> some View {
        configuration.label.font(.system(size:10,weight:.medium,design:.monospaced)).padding(.horizontal,12).padding(.vertical,9)
            .foregroundStyle(Theme.white).background(.white.opacity(configuration.isPressed ? 0.12:0.04),in:RoundedRectangle(cornerRadius:5))
            .overlay(RoundedRectangle(cornerRadius:5).stroke(Theme.dim.opacity(0.25)))
    }
}
struct LaunchButton:ButtonStyle {
    func makeBody(configuration:Configuration) -> some View {
        configuration.label.font(.system(size:12,weight:.bold,design:.monospaced)).tracking(0.5).padding(.horizontal,20).padding(.vertical,14)
            .foregroundStyle(Theme.ink).background(Theme.mint.opacity(configuration.isPressed ? 0.7:1),in:RoundedRectangle(cornerRadius:6))
    }
}
