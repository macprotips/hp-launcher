import Foundation

/// The native engines, built separately and embedded in Contents/Helpers by tools/build.sh.
extension GameID {
    var remasteredApp: String? {
        switch self {
        case .hp1: nil
        case .hp2: "HP2.app"
        case .hp3: "HP3 Native.app"
        }
    }

    /// The engine's own folder under Application Support, for saves and settings.
    var remasteredDataFolder: String { self == .hp3 ? "HP3 Native" : "HP2 Native" }

    /// The HP3 engine accepts only the North American hppoa.exe it was built against.
    var remasteredExecutableSHA256: String? {
        self == .hp3 ? "4324b8a4b1b8c873b82428a06bba4bd782bf6a7a2c2f40aa858121baebf9e81a" : nil
    }

    /// Why Remastered can't play this imported copy, or nil if it can.
    func remasteredProblem(with record: InstallRecord?) -> String? {
        guard let expected = remasteredExecutableSHA256, record?.executableSHA256 != expected else { return nil }
        return "Remastered supports the North American PC release of \(title), and this copy is a different one. Original can still play it."
    }
}

/// Starts an embedded engine on the imported copy, which it only reads.
struct RemasteredLaunch: Sendable {
    let paths: GamePaths
    let app: URL

    var arguments: [String] {
        switch paths.game {
        case .hp3: [paths.install.path, "HP_Preamble"]   // the first map, which opens the main menu
        default: ["-gamePath", paths.install.path]
        }
    }

    func start() throws -> Process {
        guard let program = Bundle(url: app)?.executableURL, Files.exists(program) else {
            throw LauncherError("The Remastered engine is damaged. Download HP Launcher again.")
        }
        return try Command.launch(program, arguments, log: paths.log)
    }
}
