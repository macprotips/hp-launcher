import Foundation

/// dgVoodoo 2.79.3 turns the games' old Direct3D into Direct3D 11 for CrossOver to run on Metal.
/// Players supply the ZIP; only this exact release is accepted.
enum Graphics {
    static let archiveSize = 5_201_822
    static let archiveSHA256 = "6b9775b20379cb49c604948afa58b5f0337d38f72efd0e6990b5f2fe4f57f23b"
    static let dllSHA256 = [
        "DDraw.dll": "247fec70c9ab5ca94448c3c4eded5bcab4d088ef462e5df6efbced46af001036",
        "D3DImm.dll": "dcac7eee656c660b081430ed2c6142726fd608e7a335f3dd9651619d42a0408e",
        "D3D8.dll": "6468ed640dc78facd2479d59618a41af2deb59d92dabc99f0f79d283e942d729",
    ]

    /// Every DLL the game needs is present and unmodified.
    static func isInstalled(_ paths: GamePaths) -> Bool {
        paths.game.wrapperDLLs.allSatisfy { name in
            guard let file = Files.resolve(name, in: paths.system) else { return false }
            return (try? Files.sha256(file)) == dllSHA256[name]
        }
    }

    static func install(from archive: URL, into paths: GamePaths) async throws {
        let size = (try? archive.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        try require(size == archiveSize && (try Files.sha256(archive)) == archiveSHA256,
                    "That isn’t the dgVoodoo 2.79.3 ZIP. Download version 2.79.3 from its author and choose the ZIP file itself.")
        let work = paths.root.appending(path: ".Graphics-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: work) }
        try await Command.check(URL(filePath: "/usr/bin/ditto"), ["-x", "-k", archive.path, work.path],
                                log: paths.log, failure: "The dgVoodoo ZIP couldn’t be opened. Download it again from its author.")
        for name in paths.game.wrapperDLLs {
            guard let dll = Files.resolve("MS/x86/\(name)", in: work), try Files.sha256(dll) == dllSHA256[name] else {
                throw LauncherError("The dgVoodoo ZIP is incomplete. Download it again from its author.")
            }
            if let existing = Files.resolve(name, in: paths.system) { try FileManager.default.removeItem(at: existing) }
            try FileManager.default.copyItem(at: dll, to: paths.system.appending(path: name))
        }
        let template = Files.resolve("dgVoodoo.conf", in: work).flatMap { try? INI.read($0) } ?? ""
        try configuration(template, game: paths.game)
            .write(to: paths.system.appending(path: "dgVoodoo.conf"), atomically: true, encoding: .utf8)
        try Files.makeDirectory(paths.graphicsArchive.deletingLastPathComponent())
        if !Files.exists(paths.graphicsArchive) { try FileManager.default.copyItem(at: archive, to: paths.graphicsArchive) }
        try require(isInstalled(paths), "Graphics support couldn’t be installed. Open the log for details.")
    }

    /// Rewritten before each launch, so a hand-edited or older file can't break the game.
    static func updateConfiguration(_ paths: GamePaths) throws {
        let url = paths.system.appending(path: "dgVoodoo.conf")
        let text = Files.exists(url) ? try INI.read(url) : ""
        try configuration(text, game: paths.game).write(to: url, atomically: true, encoding: .utf8)
    }

    /// Windowed, aspect-correct scaling, no watermark or forced vsync.
    static func configuration(_ text: String, game: GameID) -> String {
        let frameLimit = game.defaultFrameLimit
        var c = INI.update(text, section: "General", values: [
            "OutputAPI": "d3d11_fl11_0", "FullScreenMode": "false", "ScalingMode": "stretched_ar", "KeepWindowAspectRatio": "true"])
        if game == .hp3 {
            c = INI.update(c, section: "GeneralExt", values: ["FPSLimit": String(frameLimit), "WindowedAttributes": ""])
            return INI.update(c, section: "DirectX", values: [
                "AppControlledScreenMode": "false", "DisableAltEnterToToggleScreenMode": "true", "Resolution": "unforced",
                "ForceVerticalSync": "false", "dgVoodooWatermark": "false", "Antialiasing": "off"])
        }
        c = INI.update(c, section: "GeneralExt", values: ["FullscreenAttributes": "fake", "WindowedAttributes": "", "FPSLimit": String(frameLimit)])
        c = INI.update(c, section: "Glide", values: ["Antialiasing": "off"])
        return INI.update(c, section: "DirectX", values: [
            "AppControlledScreenMode": "true", "DisableAltEnterToToggleScreenMode": "true", "Resolution": "unforced",
            "ForceVerticalSync": "false", "dgVoodooWatermark": "false", "Antialiasing": "off",
            "VideoCard": "geforce_fx_5700_ultra", "FastVideoMemoryAccess": "true"])
    }
}
