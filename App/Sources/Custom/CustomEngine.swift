import AppKit

/// Another developer's engine, such as a decompilation or recompilation, chosen by the player for one game.
struct CustomEngine: Codable, Equatable, Sendable {
    /// A Mac app or a command-line program.
    var path: String
    /// Optional; `{game}` stands for the game folder.
    var arguments = ""

    var url: URL { URL(filePath: path) }
    var name: String { url.deletingPathExtension().lastPathComponent }
    var isApp: Bool { url.pathExtension == "app" }
    var exists: Bool { isApp ? Files.isDirectory(url) : FileManager.default.isExecutableFile(atPath: path) }

    /// OpenHP1 (github.com/SplittyDev/openhp1), the open-source Sorcerer's Stone engine. It ignores the
    /// folder it starts in and reads the game's location from its own OpenHP1.ini.
    var isOpenHP1: Bool { url.lastPathComponent == "openhp1-game" }

    /// Downloaded from the internet and not yet opened: macOS will block it the first time until the
    /// player chooses Open Anyway in Privacy & Security. Flag 0x40 marks a file the player has approved.
    var needsApproval: Bool {
        var value = [UInt8](repeating: 0, count: 128)
        let length = getxattr(path, "com.apple.quarantine", &value, value.count, 0, 0)
        guard length > 0, let flags = UInt32(String(decoding: value.prefix(length).prefix(4), as: UTF8.self), radix: 16) else { return false }
        return flags & 0x40 == 0
    }

    /// Splits on spaces, keeping "quoted text" together, then fills in `{game}`.
    func argumentList(game: URL) -> [String] {
        var parts: [String] = [], current = "", quoted = false, started = false
        for char in arguments {
            if char == "\"" { quoted.toggle(); started = true }
            else if char == " " && !quoted { if started { parts.append(current) }; current = ""; started = false }
            else { current.append(char); started = true }
        }
        if started { parts.append(current) }
        return parts.map { $0.replacingOccurrences(of: "{game}", with: game.path) }
    }
}

/// Starts a custom engine in the game folder. Apps go through Launch Services, so macOS can ask the
/// player to approve an engine downloaded from the internet the first time.
struct CustomLaunch {
    let paths: GamePaths
    let engine: CustomEngine

    struct Running: Sendable {
        let wait: @Sendable () async -> Void
        let stop: @Sendable () -> Void
    }

    func start() async throws -> Running {
        try require(engine.exists, "\(engine.name) isn’t where it was. Choose it again in Setup.")
        let arguments = engine.argumentList(game: paths.install)
        Log.append("", to: paths.log, command: ([engine.name] + arguments).joined(separator: " "))
        if engine.isApp {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = arguments
            configuration.createsNewApplicationInstance = true
            let app = try await NSWorkspace.shared.openApplication(at: engine.url, configuration: configuration)
            return Running(wait: { while !app.isTerminated { try? await Task.sleep(for: .seconds(2)) } }, stop: { app.terminate() })
        }
        let process = Process()
        process.currentDirectoryURL = paths.install
        process.executableURL = engine.url
        process.arguments = arguments
        if engine.isOpenHP1 { process.environment = try openHP1Environment() }
        let handle = try FileHandle(forWritingTo: paths.log)
        defer { try? handle.close() }
        _ = try handle.seekToEnd()
        process.standardOutput = handle
        process.standardError = handle
        try process.run()
        return Running(wait: { process.waitUntilExit() }, stop: { process.terminate() })
    }

    /// OpenHP1 gets a settings folder of its own here, with Root set to the imported copy. Its saves
    /// and other settings live there too, apart from any standalone OpenHP1 setup.
    private func openHP1Environment() throws -> [String: String] {
        let settings = paths.root.appending(path: "Custom/OpenHP1")
        try Files.makeDirectory(settings)
        let ini = settings.appending(path: "OpenHP1.ini")
        let text = Files.exists(ini) ? try INI.read(ini) : ""
        try INI.update(text, section: "OpenHP1.GameData", values: ["Root": paths.install.path]).write(to: ini, atomically: true, encoding: .utf8)
        return ProcessInfo.processInfo.environment.merging(["OPENHP1_SETTINGS_DIR": settings.path]) { $1 }
    }
}
