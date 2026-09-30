import AppKit
import FlightCore
import CoreText

private final class CockpitButton: NSButton {
    var pressed: (() -> Void)?
    init(_ title:String,action:@escaping () -> Void) {
        super.init(frame:.zero)
        self.title = title; pressed = action; target = self; self.action = #selector(invoke)
        isBordered = false; bezelStyle = .regularSquare
        font = .monospacedSystemFont(ofSize:10,weight:.semibold)
        contentTintColor = NSColor(cgColor:LunarArt.white)
        wantsLayer = true; layer?.cornerRadius = 5
        layer?.backgroundColor = LunarArt.color(0.12,0.17,0.20)
    }
    required init?(coder:NSCoder) { fatalError() }
    @objc private func invoke() { pressed?() }
}
private final class CockpitSlider: NSSlider {
    var changed: ((Double) -> Void)?
    init(_ index:Int,action:@escaping (Double) -> Void) {
        super.init(frame:.zero)
        minValue = 0; maxValue = 1; doubleValue = 0; isContinuous = true
        controlSize = .small; target = self; self.action = #selector(invoke); changed = action
        setAccessibilityLabel("K\(index+1) \(ControlAction.engines[index].label)")
    }
    required init?(coder:NSCoder) { fatalError() }
    @objc private func invoke() { changed?((doubleValue*1000).rounded()/1000) }
}

/// Fixed frames, direct drawing and AppKit controls. Numeric readouts never
/// enter a SwiftUI layout graph or trigger intrinsic-size negotiations.
final class NativeCockpit {
    private unowned let view:LunarFlightView
    private let game:LanderModel
    private var buttons:[String:CockpitButton] = [:]
    private var sliders:[CockpitSlider] = []
    private var metricLabels:[NSTextField] = []
    private var lastHUD = -1.0
    private var previousPhase:GamePhase?
    private var size = CGSize.zero
    private let white = NSColor(cgColor:LunarArt.white)!
    private let mint = NSColor(cgColor:LunarArt.mint)!
    private let dim = NSColor(red:0.51,green:0.63,blue:0.68,alpha:1)
    private let amber = NSColor(cgColor:LunarArt.amber)!
    init(view:LunarFlightView,game:LanderModel) { self.view = view; self.game = game }
    private func add(_ key:String,_ label:String,_ action:@escaping () -> Void) {
        let button = CockpitButton(label,action:action)
        buttons[key] = button; view.addSubview(button)
    }
    func install() {
        add("akai","AKAI") { [weak game] in game?.openController() }
        add("help","?") { [weak game] in game?.pause(); game?.showHelp = true }
        add("pause","Ⅱ") { [weak game] in game?.togglePause() }
        add("precision","P · NORMAL") { [weak game] in guard let game else { return }; game.setPrecision(game.precision < 0.5 ? 1:0.2) }
        add("damping","T · AMORTIZARE") { [weak game] in game?.damping.toggle() }
        add("sound","♪") { [weak game] in guard let game else {return}; game.setMuted(!game.muted) }
        for i in 0..<8 {
            let label = ["1  ↑ FORȚĂ","2  ↓ INVERS","3  ← STÂNGA","4  → DREAPTA","5  ↶ ROTIRE","6  ↷ ROTIRE","7  FRÂNĂ","8  ZERO"][i]
            add("pad\(i)",label) { [weak game] in game?.fire(i) }
            buttons["pad\(i)"]?.setAccessibilityLabel("Pad \(i+1): \(ControlAction.bursts[i].label)")
        }
        add("primary","LANSEAZĂ →") { [weak game] in
            guard let game else { return }
            if game.phase == .title || game.phase == .gameOver { game.newGame(); game.togglePause() }
            else { game.togglePause() }
        }
        add("secondary","Cum pilotezi") { [weak game] in
            guard let game else { return }
            if game.phase == .paused { game.confirmRetry = true }
            else { game.pause(); game.showHelp = true }
        }
        buttons["primary"]?.layer?.backgroundColor = LunarArt.mint
        buttons["primary"]?.contentTintColor = NSColor(cgColor:LunarArt.ink)
        for i in 0..<6 {
            let slider = CockpitSlider(i) { [weak game] in game?.setEngine(i,$0) }
            sliders.append(slider); view.addSubview(slider)
        }
        for _ in 0..<3 {
            let label = NSTextField(labelWithString:"")
            label.font = .monospacedSystemFont(ofSize:27,weight:.medium)
            label.textColor = white
            metricLabels.append(label); view.addSubview(label)
        }
        refresh(); layout()
    }
    private func setTitle(_ key:String,_ title:String) {
        if buttons[key]?.title != title { buttons[key]?.title = title }
    }
    func refresh() {
        let phaseChanged = previousPhase != game.phase
        if phaseChanged {
            previousPhase = game.phase
            buttons["primary"]?.isHidden = game.phase == .flying
            buttons["secondary"]?.isHidden = ![GamePhase.title,.paused].contains(game.phase)
            let label:String
            switch game.phase {
            case .title: label = "LANSEAZĂ →"
            case .gameOver: label = "JOC NOU →"
            case .result: label = game.world.outcome == .landed ? "SECTORUL URMĂTOR →":"REÎNCEARCĂ →"
            default: label = "CONTINUĂ →"
            }
            setTitle("primary",label)
            setTitle("secondary",game.phase == .paused ? "Reîncearcă":"Cum pilotezi")
            setTitle("pause",game.phase == .flying ? "Ⅱ":"▶")
            layout()
        }
        setTitle("precision",game.precision < 0.5 ? "P · FIN":"P · NORMAL")
        setTitle("damping",game.damping ? "● T · AMORTIZARE":"○ T · AMORTIZARE")
        setTitle("sound",game.muted ? "♪ ×":"♪")
        for i in 0..<6 {
            if sliders[i].doubleValue != game.dials[i].value { sliders[i].doubleValue = game.dials[i].value }
            if sliders[i].isEnabled != game.running { sliders[i].isEnabled = game.running }
        }
        let time = ProcessInfo.processInfo.systemUptime
        if time-lastHUD >= 0.08 || phaseChanged {
            lastHUD = time
            let w = game.world
            let values = [String(format:"%05.1f m",max(0,Physics.clearance(w,sector:game.sector))),String(format:"%04.1f m/s",w.velocity.y < -0.05 ? -w.velocity.y:0),String(format:"%+.1f m/s",w.velocity.x)]
            for i in 0..<3 where metricLabels[i].stringValue != values[i] { metricLabels[i].stringValue = values[i] }
            metricLabels[1].textColor = abs(w.velocity.y)>6 ? amber:mint
            metricLabels[2].textColor = abs(w.velocity.x)>3 ? amber:mint
        }
    }
    private var card:NSRect {
        let b = view.bounds
        if game.phase == .title { return .init(x:56,y:210,width:460,height:min(440,b.height-350)) }
        return .init(x:game.phase == .result ? 40:(b.width-430)/2,y:210,width:430,height:320)
    }
    func layout() {
        let w = view.bounds.width, h = view.bounds.height
        buttons["akai"]?.frame = .init(x:w-184,y:h-43,width:65,height:30)
        buttons["help"]?.frame = .init(x:w-105,y:h-43,width:35,height:30)
        buttons["pause"]?.frame = .init(x:w-55,y:h-43,width:35,height:30)
        let engineWidth = (w-212)/6
        for i in 0..<6 { sliders[i].frame = .init(x:80+Double(i)*engineWidth,y:60,width:engineWidth-12,height:22) }
        buttons["precision"]?.frame = .init(x:w-125,y:68,width:107,height:28)
        let padWidth = (w-250)/8
        for i in 0..<8 { buttons["pad\(i)"]?.frame = .init(x:80+Double(i)*padWidth,y:15,width:padWidth-7,height:32) }
        buttons["damping"]?.frame = .init(x:w-167,y:15,width:122,height:32)
        buttons["sound"]?.frame = .init(x:w-39,y:15,width:24,height:32)
        let r = card
        buttons["primary"]?.frame = .init(x:r.minX+26,y:r.minY+28,width:game.phase == .title ? 155:200,height:42)
        buttons["secondary"]?.frame = .init(x:r.minX+(game.phase == .title ? 198:236),y:r.minY+28,width:137,height:42)
        for i in 0..<3 { metricLabels[i].frame = .init(x:36+Double(i)*185,y:h-133,width:180,height:35) }
        size = view.bounds.size
    }
    private func text(_ value:String,_ x:Double,_ y:Double,_ font:Double = 11,_ color:NSColor? = nil,_ weight:NSFont.Weight = .medium) {
        LunarArt.text(value,at:.init(x:x,y:y),size:font,color:color ?? white,weight:weight)
    }
    private func wrapped(_ value:String,_ rect:NSRect,_ font:Double = 13,_ color:NSColor? = nil) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let attributes:[NSAttributedString.Key:Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String):LunarArt.font(font,bold:false),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):(color ?? dim).cgColor
        ]
        let setter = CTFramesetterCreateWithAttributedString(NSAttributedString(string:value,attributes:attributes))
        let frame = CTFramesetterCreateFrame(setter,CFRange(location:0,length:0),CGPath(rect:rect,transform:nil),nil)
        context.saveGState(); context.textMatrix = .identity; CTFrameDraw(frame,context); context.restoreGState()
    }
    private func panel(_ c:CGContext,_ rect:CGRect,_ alpha:Double = 0.86) {
        c.setFillColor(LunarArt.color(0.025,0.045,0.065,alpha)); c.addPath(CGPath(roundedRect:rect,cornerWidth:9,cornerHeight:9,transform:nil)); c.fillPath()
    }
    func draw(_ c:CGContext) {
        if size != view.bounds.size { layout() }
        let w = view.bounds.width, h = view.bounds.height, world = game.world
        c.setFillColor(LunarArt.color(0.025,0.044,0.063)); c.fill(.init(x:0,y:0,width:w,height:120)); c.fill(.init(x:0,y:h-56,width:w,height:56))
        text("☾  LUNAR LANDER",20,h-34,14,white,.bold); text("/ VLAD",190,h-32,10,dim)
        text(String(format:"SECTOR %02d",game.sectorNumber),w-530,h-32,11,dim)
        text(String(format:"SCOR %06d",game.score),w-417,h-32,11,mint)
        text(String(repeating:"◆ ",count:max(0,game.lives)),w-280,h-33,14,amber)
        panel(c,.init(x:20,y:h-150,width:w-40,height:78),0.78)
        for (i,label) in ["ALTITUDINE","COBORÂRE","LATERAL"].enumerated() { text(label,36+Double(i)*185,h-94,9,dim) }
        text("COMBUSTIBIL  \(Int(world.fuel)) kg",w-222,h-95,11)
        for i in 0..<25 {
            c.setFillColor(Double(i)<world.fuel/10 ? LunarArt.mint:LunarArt.color(0.15,0.25,0.28)); c.fill(.init(x:w-222+Double(i)*7,y:h-116,width:5,height:9))
        }
        text(String(format:"LUNĂ · g 1,62   T+%05.1f",world.elapsed),w-222,h-136,9,dim)
        text("MOTOARE",15,81,9,dim)
        let engineWidth = (w-212)/6
        for i in 0..<6 {
            let x = 80+Double(i)*engineWidth
            text("K\(i+1) \(["PRINCIPAL","INVERS","STÂNGA","DREAPTA","ROT ↶","ROT ↷"][i])",x,98,9,dim)
            text(String(format:"%.1f%%",game.dials[i].value*100),x+engineWidth-54,98,9,game.dials[i].value > 0 ? mint:dim)
            c.setFillColor(LunarArt.color(0.35,0.92,0.68,0.65)); c.fill(.init(x:x,y:56,width:(engineWidth-12)*(game.running ? min(1,world.enginePower[i]):0),height:2))
        }
        text(String(format:"K8  %.1f%% / pas",game.precision*0.5),w-124,54,9,dim)
        text("IMPULSURI",15,27,9,dim)
        drawMap(c)
        let pad = game.currentSite, aligned = Physics.padUnderFeet(world,sector:game.sector)?.id == pad.id
        panel(c,.init(x:w-272,y:140,width:252,height:62))
        text(String(format:"PISTA ×%d   %+.0f m",pad.multiplier,pad.x-world.position.x),w-254,177,13,aligned ? mint:amber,.bold)
        text("\(aligned ? "●":"○") ALINIERE   \(abs(world.velocity.y)<=6 && abs(world.velocity.x)<=3 ? "●":"○") VITEZĂ",w-254,157,9,dim)
        text(String(format:"∠ %.0f°",abs(world.angle)*180 / .pi),w-81,157,10,abs(world.angle)<=15 * .pi/180 ? mint:amber)
        if let notice = game.notice { panel(c,.init(x:230,y:h-192,width:w-460,height:28)); text(notice,244,h-183,10,amber) }
        if game.phase != .flying { drawCard(c) }
    }
    private func drawMap(_ c:CGContext) {
        let rect = CGRect(x:20,y:140,width:220,height:65)
        panel(c,rect); text("SECTOR LUNAR / ×1  ×3  ×5",30,rect.maxY-19,9,dim)
        let points = game.sector.vertices.map {Vector(30+$0.x/1200*200,rect.minY+10+$0.y/450*35)}
        LunarArt.polygon(c,points,fill:nil,stroke:LunarArt.color(0.4,0.6,0.66),width:1)
        for p in game.sector.sites {
            LunarArt.polygon(c,[Vector(30+p.left/1200*200,rect.minY+10+p.height/450*35),Vector(30+p.right/1200*200,rect.minY+10+p.height/450*35)],fill:nil,stroke:LunarArt.mint,width:2)
        }
        let p = game.world.position
        c.setFillColor(LunarArt.amber); c.fillEllipse(in:.init(x:28+clamp(p.x/1200*200,0,200),y:rect.minY+8+clamp(p.y/450*35,0,37),width:4,height:4))
    }
    private func drawCard(_ c:CGContext) {
        let r = card
        panel(c,r,0.94)
        if game.phase == .title {
            text("O SINGURĂ LUNĂ. ATÂTEA ATERIZĂRI.",r.minX+26,r.maxY-35,10,amber)
            text("LUNAR",r.minX+23,r.maxY-116,68,white,.heavy)
            text("LANDER",r.minX+23,r.maxY-189,68,white,.heavy)
            wrapped("Simte inerția. Dozează motoarele.\nAlege o pistă și aterizează pe picioare.",.init(x:r.minX+26,y:r.minY+116,width:r.width-52,height:65),15)
            text("K1–K6: motoare fine · PAD 1–6: impulsuri",r.minX+26,r.minY+96,10,dim)
            text(String(format:"RECORD  %06d",game.best),r.minX+26,r.minY+77,10,mint)
            return
        }
        let title:String, detail:String, eyebrow:String
        switch game.phase {
        case .ready:
            title = "Alege-ți aterizarea."; eyebrow = "SECTOR \(game.sectorNumber) · PREGĂTIT"
            detail = "Trei piste: ×1, ×3, ×5.\nContact pe picioare: ≤ 6 m/s vertical, ≤ 3 m/s lateral și ≤ 15°."
        case .paused:
            title = "Zbor în pauză."; eyebrow = "MOTOARE LA ZERO"
            detail = "Spațiu continuă. Potențiometrele absolute trebuie readuse la zero înainte de zbor."
        case .gameOver:
            title = "Încă un zbor?"; eyebrow = "SFÂRȘITUL EXPEDIȚIEI"; detail = game.world.detail
        default:
            title = game.world.outcome == .landed ? "Luna e a ta.":"Mai încearcă."
            eyebrow = game.world.outcome == .landed ? "CONTACT CONFIRMAT":"ÎNCERCARE ÎNCHEIATĂ"
            detail = game.world.detail
        }
        text(eyebrow,r.minX+26,r.maxY-34,10,amber)
        text(title,r.minX+26,r.maxY-82,28,white,.bold)
        wrapped(detail,.init(x:r.minX+26,y:r.maxY-161,width:r.width-52,height:62),13)
        if game.phase == .result || game.phase == .gameOver {
            text(String(format:"CONTACT %.2f m/s · %.0f kg",worldImpact,game.world.fuel),r.minX+26,r.minY+122,12,dim)
            if game.world.outcome == .landed {
                text("+\(game.world.touchdown?.points ?? 0) PUNCTE  ·  +45 kg",r.minX+26,r.minY+90,18,mint,.bold)
            }
        } else { text("SPAȚIU · CONTINUĂ",r.minX+26,r.minY+102,10,dim) }
    }
    private var worldImpact:Double { game.world.touchdown?.vy ?? abs(game.world.velocity.y) }
}
