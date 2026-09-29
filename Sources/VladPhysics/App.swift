import SwiftUI
import AppKit

@main
struct VladPhysicsApp: App {
    @StateObject private var model = GameModel()
    var body: some Scene {
        WindowGroup("Proiectul de fizică al lui Vlad") {
            ContentView(model: model, midi: model.midi)
                .onAppear { InputMonitor.shared.attach(model) }
        }
        .defaultSize(width: 1300, height: 850)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {
                Button("Ghid de zbor și fizică") { model.pause(); model.showHelp = true }
            }
            CommandMenu("Zbor") {
                Button("Pauză") { model.pause() }
                Button("Misiuni") { model.pause(); model.showMissions = true }
                Button("Controller AKAI") { model.openController() }
                Button("Exportă CSV") { model.exportCSV() }
            }
        }
    }
}

final class InputMonitor {
    static let shared = InputMonitor()
    private var monitor: Any?
    private weak var model: GameModel?
    func attach(_ model: GameModel) {
        self.model = model
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let model = self?.model, !model.isOverlayOpen,
                  NSApp.modalWindow == nil,
                  !event.modifierFlags.contains(.command), !event.modifierFlags.contains(.control),
                  NSApp.keyWindow?.sheetParent == nil else { return event }
            if model.key(event.keyCode, down: event.type == .keyDown, repeated: event.isARepeat) { return nil }
            return event
        }
    }
}
