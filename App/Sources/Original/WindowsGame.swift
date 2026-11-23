import Foundation

/// How each Windows game is run under CrossOver.
extension GameID {
    var bottleName: String { rawValue }

    /// The game's folder on the bottle's C: drive, C:\HP2 and so on.
    var driveFolder: String { rawValue.uppercased() }

    /// Where HP2 and HP3 keep settings and saves, under the bottle user's Documents.
    var documentsFolder: String {
        switch self {
        case .hp1: "Harry Potter"
        case .hp2: "Harry Potter II"
        case .hp3: "Harry Potter and the Prisoner of Azkaban"
        }
    }

    var settingsFile: String {
        switch self {
        case .hp1: "HP.ini"
        case .hp2: "Game.ini"
        case .hp3: "hppoa.ini"
        }
    }

    var windowTitle: String {
        switch self {
        case .hp1: "Harry Potter and the Sorcerer's Stone"
        case .hp2: "Harry Potter and the Chamber of Secrets"
        case .hp3: "Harry Potter and the Prisoner of Azkaban"
        }
    }

    /// dgVoodoo DLLs: HP1 and HP2 draw with Direct3D 7, HP3 with Direct3D 8.
    var wrapperDLLs: [String] { self == .hp3 ? ["D3D8.dll"] : ["DDraw.dll", "D3DImm.dll"] }

    /// Old Direct3D goes to dgVoodoo, which outputs Direct3D 11 for CrossOver's DXMT to run on Metal.
    var dllOverrides: String {
        self == .hp3 ? "d3d8=n;d3d11,dxgi,winemetal=b;winemenubuilder=" : "ddraw,d3dimm=n;d3d11,dxgi,winemetal=b;winemenubuilder="
    }

    /// The frame cap written to dgVoodoo.conf.
    var defaultFrameLimit: Int { self == .hp2 ? 120 : 60 }
}
