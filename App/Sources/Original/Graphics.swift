import Foundation

/// dgVoodoo 2 turns the games' old Direct3D into Direct3D 11 for CrossOver to run on Metal. Players
/// supply the ZIP. Only 2.79.3 works: 2.87.7 crashes HP2 at startup, because CrossOver's DXMT can't
/// create its swapchain ("cross-process swapchain not supported yet").
enum Graphics {
    static let supportedVersion = "2.79.3"
    /// The author no longer hosts 2.79.3. This is the unmodified ZIP in a public archive of releases, pinned
    /// to one commit; its size matches the original (5,201,822 bytes). dgVoodoo's terms forbid bundling it
    /// in a launcher, so the player downloads it and chooses it in Setup.
    static let download = "https://github.com/masterotaku/dgVoodoo-binaries/raw/538ea501d0f4c14b17b3752694059b54a4e3a13e/dgVoodoo2_79_3.zip"

    static func isInstalled(_ paths: GamePaths) -> Bool { installedVersion(paths) == supportedVersion }

    /// The dgVoodoo release of the installed DLLs, if every one the game needs is present and they agree.
    static func installedVersion(_ paths: GamePaths) -> String? {
        let versions = paths.game.wrapperDLLs.map { Files.resolve($0, in: paths.system).flatMap(version(of:)) }
        guard let first = versions.first ?? nil, versions.allSatisfy({ $0 == first }) else { return nil }
        return first
    }

    /// dgVoodoo DLLs carry their release as UTF-16 text, such as "2.79.3". nil for anything else.
    static func version(of dll: URL) -> String? {
        guard (try? Executable.isWindows32(dll)) == true, let data = try? Data(contentsOf: dll, options: .mappedIfSafe),
              data.count < 16 << 20 else { return nil }
        return utf16Version(in: [UInt8](data))
    }

    /// The first "2.NN" or "2.NN.N" written as UTF-16, at any byte offset.
    private static func utf16Version(in bytes: [UInt8]) -> String? {
        func char(_ i: Int) -> UInt8? { i + 1 < bytes.count && bytes[i + 1] == 0 ? bytes[i] : nil }
        func digit(_ i: Int) -> Bool { char(i).map { $0 >= 48 && $0 <= 57 } ?? false }
        var i = 0
        while i + 8 < bytes.count {
            if char(i) == 50, char(i + 2) == 46, digit(i + 4), digit(i + 6), !digit(i + 8) || char(i + 8) == 46 {
                var end = i + 8
                if char(end) == 46, digit(end + 2) { end += 2; while digit(end) { end += 2 } }
                return String(decoding: stride(from: i, to: end, by: 2).map { bytes[$0] }, as: UTF8.self)
            }
            i += 1
        }
        return nil
    }

    static func install(from archive: URL, into paths: GamePaths) async throws {
        let size = Int64((try? archive.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        try require(size > 0 && size < 64 << 20, "That isn’t a dgVoodoo ZIP. Download dgVoodoo 2 from its author and choose the ZIP file itself.")
        let work = paths.root.appending(path: ".Graphics-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: work) }
        try await Command.check(URL(filePath: "/usr/bin/ditto"), ["-x", "-k", archive.path, work.path],
                                log: paths.log, failure: "The dgVoodoo ZIP couldn’t be opened. Download it again from its author.")
        var found: [(name: String, dll: URL)] = []
        for name in paths.game.wrapperDLLs {
            guard let dll = Files.resolve("MS/x86/\(name)", in: work) else {
                throw LauncherError("That isn’t a dgVoodoo 2 ZIP, or it’s incomplete. Download dgVoodoo 2 from its author and choose the ZIP file itself.")
            }
            guard let version = version(of: dll) else {
                throw LauncherError("That isn’t a dgVoodoo 2 ZIP. Download dgVoodoo 2.79.3 from its author and choose the ZIP file itself.")
            }
            try require(version == supportedVersion,
                        "That’s dgVoodoo \(version). These games need 2.79.3, because newer releases crash them under CrossOver. Use the Download link in this step to get it.")
            found.append((name, dll))
        }
        for (name, dll) in found {
            if let existing = Files.resolve(name, in: paths.system) { try FileManager.default.removeItem(at: existing) }
            try FileManager.default.copyItem(at: dll, to: paths.system.appending(path: name))
        }
        let template = Files.resolve("dgVoodoo.conf", in: work).flatMap { try? INI.read($0) } ?? ""
        try configuration(template, game: paths.game)
            .write(to: paths.system.appending(path: "dgVoodoo.conf"), atomically: true, encoding: .utf8)
        if archive.standardizedFileURL != paths.graphicsArchive.standardizedFileURL {
            try Files.makeDirectory(paths.graphicsArchive.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: paths.graphicsArchive)
            try FileManager.default.copyItem(at: archive, to: paths.graphicsArchive)
        }
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
