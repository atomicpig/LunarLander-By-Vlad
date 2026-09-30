import SwiftUI
import AppKit

@main
struct VladLanderApp: App {
    @StateObject private var game = LanderModel()
    var body:some Scene {
        WindowGroup("Lunar Lander · Vlad") {
            GameView(game:game).onAppear { KeyboardInput.shared.attach(game) }
        }
        .defaultSize(width:1280,height:820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing:.newItem) { Button("Joc nou") { game.newGame() } }
            CommandGroup(replacing:.help) { Button("Cum pilotezi") { game.pause(); game.showHelp = true } }
            CommandMenu("Zbor") {
                Button("Pauză") { game.pause() }
                Button("Controller AKAI") { game.openController() }
                Button("Oprește motoarele") { game.cut() }
            }
        }
    }
}
final class KeyboardInput {
    static let shared = KeyboardInput()
    private var monitor:Any?
    private weak var game:LanderModel?
    func attach(_ game:LanderModel) {
        self.game = game
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps:true)
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.keyUp]) { [weak self] event in
            guard let game = self?.game, !game.overlay, NSApp.modalWindow == nil,
                  !event.modifierFlags.contains(.command), !event.modifierFlags.contains(.control),
                  NSApp.keyWindow?.sheetParent == nil else { return event }
            return game.key(event.keyCode,down:event.type == .keyDown,repeated:event.isARepeat) ? nil:event
        }
    }
}
