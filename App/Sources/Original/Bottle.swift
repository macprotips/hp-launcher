import Foundation

/// One CrossOver bottle per game, holding its Windows settings and Original saves.
struct Bottle: Sendable {
    let paths: GamePaths
    let crossOver: CrossOver

    /// The launcher's environment minus anything that would change how Wine runs.
    var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment.filter { key, _ in
            !["WINE", "CX_", "FEX_", "DYLD_"].contains { key.hasPrefix($0) }
        }
        env["CX_BOTTLE_PATH"] = paths.bottles.path
        env["MTL_HUD_ENABLED"] = "0"
        return env
    }

    /// ARM64 and x86 bottles only work with their own kind of CrossOver.
    var existingKind: CrossOver.Kind? {
        guard let config = try? String(contentsOf: paths.bottle.appending(path: "cxbottle.conf"), encoding: .utf8) else { return nil }
        return config.contains(#""WineArch" = "arm64""#) ? .arm64 : .x86
    }

    func requireMatchingKind() throws {
        guard let existing = existingKind, existing != crossOver.kind else { return }
        throw LauncherError(existing == .arm64
            ? "This game’s Original settings and saves were made with CrossOver Preview, and \(crossOver.name) can’t use them. Choose CrossOver Preview again in Settings."
            : "This game’s Original settings and saves were made with a CrossOver release, and \(crossOver.name) can’t use them. Choose that CrossOver again in Settings.")
    }

    /// Creates the bottle on first use. CrossOver links the user folders to the Mac's own; they are
    /// replaced with real folders so saves stay in the bottle.
    func prepare() async throws {
        try Files.makeDirectory(paths.bottles)
        if !Files.exists(paths.bottle.appending(path: "cxbottle.conf")) {
            try await Command.check(crossOver.cxbottle,
                                    ["--bottle", paths.game.bottleName, "--create", "--template", "win10_64"]
                                        + (crossOver.kind == .arm64 ? ["--winearch", "arm64"] : []),
                                    environment: environment, log: paths.log, timeout: 300,
                                    failure: "CrossOver couldn’t create a place for the game. Open the log for details.")
        }
        try requireMatchingKind()
        let user = paths.bottle.appending(path: "drive_c/users/crossover")
        for name in ["Documents", "Downloads", "Music", "Pictures", "Videos", "Desktop"] {
            let folder = user.appending(path: name)
            if Files.isSymlink(folder) { try FileManager.default.removeItem(at: folder) }
            try Files.makeDirectory(folder)
        }
        // Relative, so the data folder can move.
        if !Files.exists(paths.bottleInstall) && !Files.isSymlink(paths.bottleInstall) {
            try FileManager.default.createSymbolicLink(atPath: paths.bottleInstall.path, withDestinationPath: "../../../Game")
        }
    }

    @discardableResult
    func wine(_ arguments: [String], timeout: TimeInterval = 180, failure: String) async throws -> Command.Result {
        try await Command.check(crossOver.wine, ["--bottle", paths.game.bottleName] + arguments,
                                environment: environment, log: paths.log, timeout: timeout, failure: failure)
    }

    func setRegistry(_ key: String, _ name: String, type: String, value: String) async throws {
        try await wine(["--debugmsg", "-all", "reg", "add", key, "/v", name, "/t", type, "/d", value, "/f"],
                       failure: "CrossOver couldn’t update the game’s settings.")
    }
}
