import XCTest
@testable import HP_Launcher

/// Real setup and launch against a player's own files.
/// Skipped unless HPL_E2E_GAME and HPL_E2E_SOURCE are set. Original also needs HPL_E2E_GRAPHICS and an
/// installed CrossOver; Remastered needs HPL_E2E_REMASTERED (the engine's .app). The player's files are
/// only read, and everything, including the engine's saves, goes into a temporary data folder.
@MainActor
final class EndToEndTests: XCTestCase {
    private var env: [String: String] { ProcessInfo.processInfo.environment }

    private func importGame() async throws -> (GameID, GamePaths, InstallRecord) {
        guard let gameName = env["HPL_E2E_GAME"], let game = GameID(rawValue: gameName), let source = env["HPL_E2E_SOURCE"] else {
            throw XCTSkip("Set HPL_E2E_GAME and HPL_E2E_SOURCE to run against real files.")
        }
        let data = DataRoot(url: URL(filePath: env["HPL_E2E_ROOT"] ?? NSTemporaryDirectory()).appending(path: "HPL-E2E-\(UUID().uuidString)"))
        let paths = GamePaths(game: game, data: data)
        print("E2E data root:", data.url.path)
        let started = Date()
        let record = try await Importer(paths: paths) { print("E2E:", Date().formatted(date: .omitted, time: .standard), $0) }.run(from: URL(filePath: source))
        print("E2E imported \(record.fileCount) files, \(record.bytes) bytes, protected: \(record.copyProtected), in \(Int(Date().timeIntervalSince(started)))s")
        return (game, paths, record)
    }

    private func windowTitles() -> [String] {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.compactMap { $0[kCGWindowName as String] as? String }
    }

    func testSetUpAndLaunchOriginalGame() async throws {
        guard let graphics = env["HPL_E2E_GRAPHICS"] else { throw XCTSkip("Set HPL_E2E_GRAPHICS to run Original.") }
        let crossOver = try XCTUnwrap(CrossOver.discover(), "No usable CrossOver installed.")
        let (game, paths, record) = try await importGame()
        try await Graphics.install(from: URL(filePath: graphics), into: paths)
        XCTAssertTrue(Graphics.isInstalled(paths))
        guard !record.copyProtected else { throw XCTSkip("The supplied copy is disc protected; import and graphics passed.") }

        var launch = GameLaunch(paths: paths, crossOver: crossOver)
        launch.newGame = true
        let process = try await launch.start(record: record)
        try await Task.sleep(for: .seconds(Double(env["HPL_E2E_SECONDS"] ?? "") ?? 30))
        XCTAssertTrue(process.isRunning, "The game exited within 30 seconds. See \(paths.log.path).")
        print("E2E window found:", windowTitles().contains(game.windowTitle))
        process.terminate()
        // Wine leaves the game process behind its wrapper; stop anything still running from this bottle.
        _ = try? await Command.run(crossOver.wine, ["--bottle", game.bottleName, "--debugmsg", "-all", "wineserver", "-k"],
                                   environment: Bottle(paths: paths, crossOver: crossOver).environment)
    }

    func testSetUpAndLaunchRemastered() async throws {
        guard let app = env["HPL_E2E_REMASTERED"] else { throw XCTSkip("Set HPL_E2E_REMASTERED to run Remastered.") }
        let (game, paths, _) = try await importGame()
        let launch = RemasteredLaunch(paths: paths, app: URL(filePath: app))
        // Same program and arguments as RemasteredLaunch.start, with HOME moved so the engine's saves stay in the test folder.
        let process = Process()
        process.executableURL = try XCTUnwrap(Bundle(url: launch.app)?.executableURL)
        process.arguments = launch.arguments
        process.environment = ["HOME": paths.root.path, "PATH": "/usr/bin:/bin"]
        try process.run()
        try await Task.sleep(for: .seconds(Double(env["HPL_E2E_SECONDS"] ?? "") ?? 15))
        XCTAssertTrue(process.isRunning, "The engine exited within 15 seconds.")
        // Window titles are only visible with Screen Recording permission, so this is informational.
        print("E2E remastered window found:", windowTitles().contains(game.windowTitle))
        process.terminate()
    }
}
