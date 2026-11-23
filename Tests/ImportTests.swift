import XCTest
@testable import HP_Launcher

final class ImportTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "ImportTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    // MARK: Programs

    /// A minimal 32-bit Windows program header with the given section names.
    private func program(sections: [String], machine: UInt16 = 0x14C) throws -> URL {
        var bytes = [UInt8](repeating: 0, count: 1024)
        bytes[0] = 0x4D; bytes[1] = 0x5A
        let pe = 0x80
        bytes[0x3C] = UInt8(pe)
        bytes.replaceSubrange(pe..<pe + 4, with: [0x50, 0x45, 0, 0])
        bytes[pe + 4] = UInt8(machine & 0xFF); bytes[pe + 5] = UInt8(machine >> 8)
        bytes[pe + 6] = UInt8(sections.count)
        bytes[pe + 20] = 0xE0   // optional header size
        for (i, name) in sections.enumerated() {
            let start = pe + 24 + 0xE0 + i * 40
            for (j, c) in name.utf8.prefix(8).enumerated() { bytes[start + j] = c }
        }
        let url = root.appending(path: "\(UUID().uuidString).exe")
        try Data(bytes).write(to: url)
        return url
    }

    func testSafeDiscAndSecuROMAreDetected() throws {
        XCTAssertTrue(try Executable.isCopyProtected(program(sections: [".text", ".rdata", "stxt774", "stxt371"])))
        XCTAssertTrue(try Executable.isCopyProtected(program(sections: [".text", ".securom"])))
        XCTAssertFalse(try Executable.isCopyProtected(program(sections: [".text", ".rdata", ".data", ".rsrc"])))
    }

    func testOnlyThirtyTwoBitWindowsProgramsAreAccepted() throws {
        XCTAssertTrue(try Executable.isWindows32(program(sections: [".text"])))
        XCTAssertFalse(try Executable.isWindows32(program(sections: [".text"], machine: 0x8664)))
        let text = root.appending(path: "readme.exe")
        try Data("not a program".utf8).write(to: text)
        XCTAssertFalse(try Executable.isWindows32(text))
    }

    // MARK: Finding the game

    private func makeGame(_ game: GameID, at folder: URL) throws {
        for file in game.identityFiles {
            let url = folder.appending(path: file)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: url)
        }
    }

    func testFindsTheGameNestedAndIgnoringCase() throws {
        let disc = root.appending(path: "Disc/Game Files/HP3")
        try makeGame(.hp3, at: disc)
        try FileManager.default.moveItem(at: disc.appending(path: "Maps"), to: disc.appending(path: "MAPS"))
        XCTAssertEqual(try Importer.findGame(.hp3, in: root).standardizedFileURL, disc.standardizedFileURL)
    }

    func testNamesTheOtherGameWhenTheWrongFilesAreChosen() throws {
        try makeGame(.hp2, at: root.appending(path: "Chamber"))
        XCTAssertThrowsError(try Importer.findGame(.hp3, in: root)) {
            XCTAssertEqual(($0 as? LauncherError)?.message, "These are the files for Chamber of Secrets, not Prisoner of Azkaban.")
        }
    }

    func testRefusesTwoCopiesAndExplainsAnEmptyChoice() throws {
        try makeGame(.hp1, at: root.appending(path: "A"))
        try makeGame(.hp1, at: root.appending(path: "B"))
        XCTAssertThrowsError(try Importer.findGame(.hp1, in: root))
        let empty = root.appending(path: "Empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        XCTAssertThrowsError(try Importer.findGame(.hp1, in: empty)) {
            XCTAssertTrue(($0 as? LauncherError)?.message.contains("wasn’t found") == true)
        }
    }

    func testExplainsADiscThatOnlyHoldsAnInstaller() throws {
        let disc = root.appending(path: "Disc/setup")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        try Data().write(to: disc.appending(path: "data1.cab"))
        XCTAssertThrowsError(try Importer.findGame(.hp2, in: root.appending(path: "Disc"))) {
            XCTAssertTrue(($0 as? LauncherError)?.message.contains("packed inside its installer") == true)
        }
    }

    // MARK: Importing

    /// A stand-in copy of Sorcerer's Stone: the right file names, a valid program, no real content.
    private func makeImportableHP1(at folder: URL) throws {
        try makeGame(.hp1, at: folder)
        for file in ["System/Core.u", "System/Engine.u", "System/HPBase.u", "Textures/a.utx", "Sounds/a.uax", "Music/a.umx", "save/Art.bmp"] {
            let url = folder.appending(path: file)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("x".utf8).write(to: url)
        }
        try Data("[Engine.Engine]\r\nGameRenderDevice=SoftDrv.SoftwareRenderDevice\r\n".utf8).write(to: folder.appending(path: "System/Default.ini"))
        try FileManager.default.moveItem(at: try program(sections: [".text"]), to: folder.appending(path: "System/HP.exe"))
    }

    func testReplacingSorcerersStoneKeepsSavesAndSettings() async throws {
        let source = root.appending(path: "Source")
        try makeImportableHP1(at: source)
        let paths = GamePaths(game: .hp1, data: DataRoot(url: root.appending(path: "Data")))
        let first = try await Importer(paths: paths).run(from: source)
        XCTAssertFalse(first.copyProtected)
        XCTAssertTrue(Files.exists(paths.system.appending(path: "HP.exe")))
        XCTAssertTrue(Files.exists(source.appending(path: "System/HP.exe")), "The player's own files must be left in place.")

        // What playing leaves behind: a save and the game's settings, both inside the game folder.
        let save = paths.saves(.original).appending(path: "save0.usa")
        try Data("progress".utf8).write(to: save)
        try Data("[Keys]\r\n".utf8).write(to: paths.system.appending(path: "HP.ini"))

        _ = try await Importer(paths: paths).run(from: source)
        XCTAssertEqual(try Data(contentsOf: save), Data("progress".utf8))
        XCTAssertEqual(try String(contentsOf: paths.system.appending(path: "HP.ini"), encoding: .utf8), "[Keys]\r\n")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: paths.root.path).filter { $0.hasPrefix(".") }
        XCTAssertEqual(leftovers, [], "Setup must clean up its work folders.")
    }

    func testAQuitDuringReplaceIsPutRightNextTime() async throws {
        let source = root.appending(path: "Source")
        try makeImportableHP1(at: source)
        let paths = GamePaths(game: .hp1, data: DataRoot(url: root.appending(path: "Data")))
        _ = try await Importer(paths: paths).run(from: source)
        let save = paths.saves(.original).appending(path: "save0.usa")
        try Data("progress".utf8).write(to: save)
        let fm = FileManager.default

        // Quit after the old copy stepped aside, before the new one arrived: the old copy comes back.
        var work = paths.root.appending(path: ".Import-A")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        try fm.moveItem(at: paths.install, to: work.appending(path: "Previous"))
        try fm.moveItem(at: paths.record, to: work.appending(path: "Previous.json"))
        Importer.removeLeftovers(in: paths.root, game: .hp1)
        XCTAssertEqual(try Data(contentsOf: save), Data("progress".utf8))
        XCTAssertTrue(Files.exists(paths.record))
        XCTAssertFalse(Files.exists(work))

        // Quit after the new copy arrived, before the saves were carried over: they are carried over.
        work = paths.root.appending(path: ".Import-B")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        try fm.moveItem(at: paths.install, to: work.appending(path: "Previous"))
        try fm.copyItem(at: work.appending(path: "Previous"), to: paths.install)
        try fm.removeItem(at: save)
        Importer.removeLeftovers(in: paths.root, game: .hp1)
        XCTAssertEqual(try Data(contentsOf: save), Data("progress".utf8))
        XCTAssertFalse(Files.exists(work))
    }
}
