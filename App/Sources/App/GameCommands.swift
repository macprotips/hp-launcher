import SwiftUI

/// The Game menu: the window's choices, plus Finder shortcuts for the selected game.
struct GameCommands: Commands {
    let library: Library

    var body: some Commands {
        CommandMenu("Game") {
            let game = library.selected
            let edition = library.state(game).edition
            ForEach(Array(GameID.allCases.enumerated()), id: \.element) { index, id in
                Button(id.title) { library.selected = id }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            }
            Divider()
            ForEach(Edition.allCases, id: \.self) { choice in
                Toggle(choice.title, isOn: Binding(get: { edition == choice }, set: { if $0 { library.setEdition(choice, for: game) } }))
                    .disabled(!library.available(choice, for: game))
            }
            if library.offersNewGame(game) {
                Button("Start a New Game") { library.start(game, newGame: true) }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(!library.isReady(game) || library.activity != nil || library.running != nil)
            }
            Button("Set Up \(game.title)…") { library.showingSetup = true }
                .keyboardShortcut("u", modifiers: .command)
                .disabled(library.activity != nil)
            Divider()
            let saves = library.paths(game).saves(edition)
            Button("Show Saved Games in Finder") { saves.map { NSWorkspace.shared.activateFileViewerSelecting([$0]) } }
                .disabled(!(saves.map(Files.exists) ?? false))
            Button("Show Game Files in Finder") { NSWorkspace.shared.activateFileViewerSelecting([library.paths(game).install]) }
                .disabled(!library.isInstalled(game))
            Button("Show Log in Finder") { NSWorkspace.shared.activateFileViewerSelecting([library.paths(game).log]) }
                .disabled(!Files.exists(library.paths(game).log))
        }
    }
}

struct HelpCommand: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("HP Launcher Help") { openWindow(id: "help") }.keyboardShortcut("?", modifiers: .command)
    }
}
