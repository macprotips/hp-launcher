import Foundation

/// The games' own .ini files: windowed, Direct3D, and saves where the launcher expects them.
enum GameSettings {
    /// HP1 reads its settings beside the program; HP2 and HP3 from Documents in the bottle.
    static func folder(for game: GameID, paths: GamePaths) -> URL {
        game == .hp1 ? paths.system : paths.documents
    }

    /// Creates the settings from the game's Default.ini on first launch. Existing files, and the key
    /// bindings in them, are never replaced.
    static func seed(for game: GameID, paths: GamePaths) throws {
        let folder = folder(for: game, paths: paths)
        try Files.makeDirectory(folder)
        let settings = folder.appending(path: game.settingsFile)
        if !Files.exists(settings) {
            guard let defaults = shallowestDefaultINI(in: paths.system) else {
                throw LauncherError("Your copy is missing its Default.ini settings file. Choose a complete copy of \(game.title).")
            }
            var text = try INI.read(defaults)
            text = INI.update(text, section: "Engine.Engine", values: [
                "GameRenderDevice": "D3DDrv.D3DRenderDevice", "WindowedRenderDevice": "D3DDrv.D3DRenderDevice", "RenderDevice": "D3DDrv.D3DRenderDevice",
            ])
            switch game {
            case .hp1:
                text = INI.update(text, section: "FirstRun", values: ["FirstRun": "1"])
            case .hp2:
                text = INI.update(text, section: "FirstRun", values: ["FirstRun": "433"])
                text = INI.update(text, section: "WinDrv.WindowsClient", values: [
                    "Brightness": "0.4", "UseDirectInput": "False", "NoFractalAnim": "False", "SkinDetail": "High", "TextureDetail": "High"])
                text = INI.update(text, section: "D3DDrv.D3DRenderDevice", values: [
                    "UsePrecache": "False", "UseVSync": "False", "Use32BitZBuffer": "False", "UseVertexFog": "False",
                    "UseAGPTextures": "False", "UseVideoMemoryVB": "False"])
                text = INI.update(text, section: "HGame.baseConsole", values: ["bDebugMode": "False", "bUseSystemFonts": "True"])
            case .hp3:
                text = INI.update(text, section: "FirstRun", values: ["FirstRun": "2226"])
            }
            try text.write(to: settings, atomically: true, encoding: .utf8)
        }
        let user = folder.appending(path: "User.ini")
        if !Files.exists(user), let defaults = Files.resolve("DefUser.ini", in: paths.system) {
            try FileManager.default.copyItem(at: defaults, to: user)
        }
    }

    /// Rewritten before every launch, so the window and save folder are always what the launcher expects.
    static func configure(for game: GameID, paths: GamePaths, viewport: (width: Int, height: Int), slot: Int = 1) throws {
        let url = folder(for: game, paths: paths).appending(path: game.settingsFile)
        var text = try INI.read(url)
        text = INI.update(text, section: "WinDrv.WindowsClient", values: [
            "StartupFullscreen": "False", "WindowedViewportX": String(viewport.width), "WindowedViewportY": String(viewport.height),
            "WindowedColorBits": "32", "FullscreenColorBits": "32"])
        text = INI.update(text, section: "D3DDrv.D3DRenderDevice", values: ["UseVSync": "False"])
        if game != .hp1 {
            var save = #"C:\users\crossover\Documents\"# + game.documentsFolder + #"\Save"#
            if game == .hp2 {
                save += #"\Slot\#(slot)"#
                text = INI.update(text, section: "FrontEnd", values: ["UseSaveSlot": String(slot)])
            }
            text = INI.update(text, section: "Core.System", values: ["SavePath": save])
            // The game also looks for saves through Paths=…*.usa, which must point at the same folder.
            text = text.components(separatedBy: "\r\n").map { line in
                line.lowercased().hasPrefix("paths=") && line.lowercased().hasSuffix("*.usa") ? "Paths=" + save + #"\*.usa"# : line
            }.joined(separator: "\r\n")
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// HP1 has a Default.ini per language folder; the shallowest is the main one.
    static func shallowestDefaultINI(in system: URL) -> URL? {
        let walker = FileManager.default.enumerator(at: system, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        var best: (URL, Int)?
        while let file = walker?.nextObject() as? URL {
            guard file.lastPathComponent.caseInsensitiveCompare("Default.ini") == .orderedSame else { continue }
            let depth = file.pathComponents.count
            if best == nil || depth < best!.1 { best = (file, depth) }
        }
        return best?.0
    }
}
