import Foundation

/// Starts the Windows game in its bottle.
struct GameLaunch: Sendable {
    let paths: GamePaths
    let crossOver: CrossOver
    /// HP2 only.
    var slot = 1
    var newGame = false

    static let viewport = (width: 1024, height: 768)

    /// The FEX settings apply only to ARM64 CrossOver: reduced-precision x87 maths and larger
    /// translation blocks took HP2 from about 12 to 60 frames per second.
    var gameEnvironment: String {
        var env = "CX_GRAPHICS_BACKEND=dxmt MTL_HUD_ENABLED=0"
        if crossOver.kind == .arm64 { env += " FEX_X87REDUCEDPRECISION=1 FEX_MAXINST=32" }
        return env
    }

    var arguments: [String] {
        let game = paths.game
        let program = paths.windowsSystem + #"\"# + game.executable
        return ["--bottle", game.bottleName, "--dll", game.dllOverrides, "--env", gameEnvironment,
                "--debugmsg", "-all", "--workdir", paths.windowsSystem, "--no-convert", program]
            + extraArguments
    }

    /// HP2's front end doesn't draw under CrossOver, so it starts straight in the first level or the slot's save.
    private var extraArguments: [String] {
        switch paths.game {
        case .hp1: []
        case .hp2: [newGame ? "PrivetDr.unr" : "-LOADGAME=0", "-NOFRONTEND", "-SAVESLOT=\(slot)"]
        case .hp3: ["-windowed"]
        }
    }

    /// Throws the first thing missing, in words for the player.
    func preflight(record: InstallRecord?) throws {
        let game = paths.game
        guard let record else { throw LauncherError("Set up \(game.title) first.") }
        try require(!record.copyProtected,
                    "Your copy of \(game.title) still has its disc copy protection, which can’t run in CrossOver. Set it up again from a copy without disc protection.")
        try require(Graphics.isInstalled(paths), "Add graphics support in Setup first.")
        try Bottle(paths: paths, crossOver: crossOver).requireMatchingKind()
    }

    func start(record: InstallRecord?) async throws -> Process {
        try preflight(record: record)
        let bottle = Bottle(paths: paths, crossOver: crossOver)
        try await bottle.prepare()
        try GameSettings.seed(for: paths.game, paths: paths)
        try GameSettings.configure(for: paths.game, paths: paths, viewport: Self.viewport, slot: slot)
        try Graphics.updateConfiguration(paths)
        // Retina mode off keeps the 1024 x 768 window that size in points; on, it would be half that on a Retina display.
        try await bottle.setRegistry(#"HKCU\Software\Wine\Mac Driver"#, "RetinaMode", type: "REG_SZ", value: "N")
        return try Command.launch(crossOver.wine, arguments, environment: bottle.environment, log: paths.log)
    }
}
