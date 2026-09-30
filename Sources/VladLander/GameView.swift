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

struct GameView: View {
    @ObservedObject var game: LanderModel
    var body: some View {
        LunarCanvas(game:game)
            .frame(minWidth:1120,minHeight:760)
            .preferredColorScheme(.dark)
            .sheet(isPresented:$game.showController,onDismiss:{game.learning = nil; game.clearInput()}) {
                ControllerSheet(game:game,midi:game.midi)
            }
            .sheet(isPresented:$game.showHelp) { Instructions(game:game) }
            .alert("Abandonezi zborul?",isPresented:$game.confirmRetry) {
                Button("Continuă pregătirea",role:.cancel) {}
                Button("Reîncearcă · −1 viață",role:.destructive) { game.retry() }
            } message: { Text("Motoarele sunt oprite. Reluarea unui zbor neterminat costă o viață.") }
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
