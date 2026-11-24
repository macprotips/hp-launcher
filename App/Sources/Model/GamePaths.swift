import Foundation

/// ~/Library/Application Support/HP Launcher, or a temporary folder in tests.
struct DataRoot: Sendable {
    let url: URL

    static let standard = DataRoot(url: URL.applicationSupportDirectory.appending(path: "HP Launcher"))

    func game(_ id: GameID) -> URL { url.appending(path: "Games/\(id.rawValue.uppercased())") }
    var preferences: URL { url.appending(path: "Preferences.json") }
}

/// Where one game's files live.
struct GamePaths: Sendable {
    let game: GameID
    let root: URL

    init(game: GameID, data: DataRoot) {
        self.game = game
        root = data.game(game)
    }

    /// The imported copy, shared by both editions. The bottle reaches it through a link at C:\HPx.
    var install: URL { root.appending(path: "Game") }
    var system: URL { install.appending(path: game.systemFolder) }
    var record: URL { root.appending(path: "installation.json") }
    var files: URL { root.appending(path: "imported-files.json") }
    var log: URL { root.appending(path: "Logs/launcher.log") }

    var bottles: URL { root.appending(path: "Bottles") }
    var bottle: URL { bottles.appending(path: game.bottleName) }
    var bottleInstall: URL { bottle.appending(path: "drive_c/\(game.driveFolder)") }
    var documents: URL { bottle.appending(path: "drive_c/users/crossover/Documents/\(game.documentsFolder)") }
    var windowsSystem: String { #"C:\\#(game.driveFolder)\\#(game.systemFolder)"# }
    /// A copy of the player's dgVoodoo ZIP, so other games and repairs don't ask for it again.
    var graphicsArchive: URL { root.appending(path: "Graphics/dgVoodoo.zip") }

    /// The editions keep separate saves. A custom engine keeps its own wherever it likes.
    func saves(_ edition: Edition) -> URL? {
        switch (edition, game) {
        case (.remastered, _): URL.applicationSupportDirectory.appending(path: game.remasteredDataFolder)
        case (.original, .hp1): install.appending(path: "Save")
        case (.original, _): documents.appending(path: "Save")
        case (.custom, _): nil
        }
    }
}
