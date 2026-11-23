import Foundation

/// What a PC copy of each game contains. Paths are matched case-insensitively.
extension GameID {
    var executable: String {
        switch self {
        case .hp1: "HP.exe"
        case .hp2: "Game.exe"
        case .hp3: "hppoa.exe"
        }
    }

    /// The name the imported copy uses. HP1 shipped "System", the others "system".
    var systemFolder: String { self == .hp1 ? "System" : "system" }

    /// Files that identify a copy as this game rather than another.
    var identityFiles: [String] {
        switch self {
        case .hp1: ["System/HarryPotter.u", "Maps/Lev_Tut1.unr"]
        case .hp2: ["System/HGame.u", "Maps/PrivetDr.unr"]
        case .hp3: ["System/hppoa.exe", "System/KWGame.u", "Maps/HP_preamble.unr"]
        }
    }

    var requiredFolders: [String] {
        let base = ["System", "Maps", "Textures", "Sounds", "Music"]
        return self == .hp3 ? base + ["Animations", "StaticMeshes", "Movies"] : base
    }

    /// Help holds front-end art; save holds HP1's level thumbnails.
    var optionalFolders: [String] { ["Help", "save"] }

    var requiredFiles: [String] {
        var files = identityFiles + ["System/Core.u", "System/Engine.u", "System/\(executable)"]
        switch self {
        case .hp1: files += ["System/HPBase.u"]
        case .hp2: files += ["System/Engine.dll", "System/Fire.dll"]
        case .hp3: files += ["System/Engine.dll"]
        }
        return Array(Set(files)).sorted()
    }
}
