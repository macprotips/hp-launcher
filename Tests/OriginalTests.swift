import XCTest
@testable import HP_Launcher

final class OriginalTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "OriginalTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    // MARK: Settings files

    func testINIUpdateReplacesEveryMatchAndKeepsEverythingElse() {
        let text = "; comment\r\n[WinDrv.WindowsClient]\r\nwindowedviewportx=640\r\nKeep=yes\r\nWindowedViewportX=800\r\n[Other]\r\nWindowedViewportX=1\r\n"
        let updated = INI.update(text, section: "WinDrv.WindowsClient", values: ["WindowedViewportX": "1024", "StartupFullscreen": "False"])
        XCTAssertEqual(updated, "; comment\r\n[WinDrv.WindowsClient]\r\nWindowedViewportX=1024\r\nKeep=yes\r\nWindowedViewportX=1024\r\nStartupFullscreen=False\r\n[Other]\r\nWindowedViewportX=1\r\n")
        XCTAssertEqual(INI.value(updated, section: "Other", key: "windowedviewportx"), "1")
    }

    func testINIUpdateAddsMissingSection() {
        let updated = INI.update("[A]\nx=1\n", section: "B", values: ["y": "2"])
        XCTAssertEqual(updated, "[A]\r\nx=1\r\n[B]\r\ny=2\r\n")
    }

    // MARK: Graphics and launch

    func testGraphicsProfilesDifferByGame() {
        let hp2 = Graphics.configuration("", game: .hp2)
        XCTAssertEqual(INI.value(hp2, section: "DirectX", key: "AppControlledScreenMode"), "true")
        XCTAssertEqual(INI.value(hp2, section: "GeneralExt", key: "FPSLimit"), "120")
        let hp3 = Graphics.configuration("", game: .hp3)
        XCTAssertEqual(INI.value(hp3, section: "DirectX", key: "AppControlledScreenMode"), "false")
        XCTAssertEqual(INI.value(hp3, section: "DirectX", key: "dgVoodooWatermark"), "false")
    }

    func testChamberOfSecretsSkipsItsFrontEndAndUsesTheChosenSlot() throws {
        let paths = GamePaths(game: .hp2, data: DataRoot(url: root))
        var launch = GameLaunch(paths: paths, crossOver: CrossOver(app: root.appending(path: "Missing.app")))
        launch.slot = 3
        XCTAssertEqual(launch.arguments.suffix(3), ["-LOADGAME=0", "-NOFRONTEND", "-SAVESLOT=3"])
        launch.newGame = true
        XCTAssertEqual(launch.arguments.suffix(3), ["PrivetDr.unr", "-NOFRONTEND", "-SAVESLOT=3"])

        try FileManager.default.createDirectory(at: paths.documents, withIntermediateDirectories: true)
        try Data("[Core.System]\r\nSavePath=..\\Save\r\nPaths=../Maps/*.unr\r\nPaths=..\\Save\\*.usa\r\n".utf8).write(to: paths.documents.appending(path: "Game.ini"))
        try GameSettings.configure(for: .hp2, paths: paths, viewport: (1024, 768), slot: 3)
        let text = try INI.read(paths.documents.appending(path: "Game.ini"))
        let slot = #"C:\users\crossover\Documents\Harry Potter II\Save\Slot3"#
        XCTAssertEqual(INI.value(text, section: "Core.System", key: "SavePath"), slot)
        XCTAssertTrue(text.contains("Paths=" + slot + #"\*.usa"#))
        XCTAssertTrue(text.contains("Paths=../Maps/*.unr"), "Other search paths must be left alone.")
        XCTAssertEqual(INI.value(text, section: "FrontEnd", key: "UseSaveSlot"), "3")
    }

    func testSaveSlotsContinueTheNewestAndStartInTheFirstEmptyOne() throws {
        let slots = SaveSlots(paths: GamePaths(game: .hp2, data: DataRoot(url: root)))
        XCTAssertNil(slots.latest)
        XCTAssertEqual(slots.firstEmpty, 1)
        for (slot, age) in [(1, -500.0), (2, -10.0)] {
            try FileManager.default.createDirectory(at: slots.folder(slot), withIntermediateDirectories: true)
            let save = slots.folder(slot).appending(path: "Save0.usa")
            try Data().write(to: save)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: age)], ofItemAtPath: save.path)
        }
        try FileManager.default.createDirectory(at: slots.folder(3), withIntermediateDirectories: true)   // made by the game, never saved in
        XCTAssertEqual(slots.latest, 2)
        XCTAssertEqual(slots.firstEmpty, 3)
    }

    func testLaunchCommandUsesFEXOnlyOnARM64() {
        let paths = GamePaths(game: .hp3, data: DataRoot(url: root))
        let arm = GameLaunch(paths: paths, crossOver: CrossOver(app: root.appending(path: "Missing.app")))
        XCTAssertEqual(arm.arguments.prefix(4), ["--bottle", "hp3", "--dll", "d3d8=n;d3d11,dxgi,winemetal=b;winemenubuilder="])
        XCTAssertEqual(arm.arguments.suffix(2), [#"C:\HP3\system\hppoa.exe"#, "-windowed"])
        XCTAssertFalse(arm.gameEnvironment.contains("FEX"), "A CrossOver without FEX must not get FEX settings.")
    }
}
