import XCTest
@testable import HP_Launcher

@MainActor
final class CustomEngineTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "CustomEngineTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testArgumentsKeepQuotedTextAndFillInTheGameFolder() {
        let engine = CustomEngine(path: "/x", arguments: #"-data {game} --title "Year Two"  -fast"#)
        XCTAssertEqual(engine.argumentList(game: URL(filePath: "/Games/HP2 Copy")), ["-data", "/Games/HP2 Copy", "--title", "Year Two", "-fast"])
        XCTAssertEqual(CustomEngine(path: "/x").argumentList(game: root), [])
    }

    func testADownloadedEngineIsFlaggedUntilApproved() throws {
        let engine = root.appending(path: "engine")
        try Data().write(to: engine)
        XCTAssertFalse(CustomEngine(path: engine.path).needsApproval)
        for (flags, needs) in [("0083", true), ("00c3", false)] {
            let value = Array("\(flags);6b04e192;Safari;".utf8)
            XCTAssertEqual(setxattr(engine.path, "com.apple.quarantine", value, value.count, 0, 0), 0)
            XCTAssertEqual(CustomEngine(path: engine.path).needsApproval, needs, flags)
        }
    }

    /// A stand-in engine records where it was started and what it was given.
    func testACustomEngineStartsInTheGameFolderWithItsArguments() async throws {
        let library = Library(root: DataRoot(url: root.appending(path: "Data")), helpers: root)
        let paths = library.paths(.hp1)
        try FileManager.default.createDirectory(at: paths.install, withIntermediateDirectories: true)
        let record = InstallRecord(game: .hp1, executableSHA256: "", copyProtected: true, fileCount: 0, bytes: 0, importedAt: .now)
        try JSONEncoder.pretty.encode(record).write(to: paths.record)

        let output = root.appending(path: "ran.txt")
        let script = root.appending(path: "engine")
        try "#!/bin/sh\npwd > '\(output.path)'\nprintf '%s\\n' \"$@\" >> '\(output.path)'\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        library.setEdition(.custom, for: .hp1)
        XCTAssertFalse(library.isReady(.hp1), "No engine chosen yet")
        library.setCustomEngine(CustomEngine(path: script.path, arguments: "--game {game}"), for: .hp1)
        library.refresh()
        XCTAssertTrue(library.isReady(.hp1), "Disc protection doesn't matter to a custom engine")

        try await library.play(.hp1)
        for _ in 0..<50 where library.running != nil { try await Task.sleep(for: .milliseconds(100)) }
        let lines = try String(contentsOf: output, encoding: .utf8).split(separator: "\n").map(String.init)
        let folder = paths.install.resolvingSymlinksInPath().path
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(URL(filePath: lines[0]).resolvingSymlinksInPath().path, folder, "Starts in the game folder")
        XCTAssertEqual(lines[1], "--game")
        XCTAssertEqual(URL(filePath: lines[2]).resolvingSymlinksInPath().path, folder, "{game} becomes the folder")
        XCTAssertNil(library.running)
    }
}
