import XCTest
@testable import HP_Launcher

@MainActor
final class LibraryTests: XCTestCase {
    func testPreferencesPersistAcrossLaunches() throws {
        let root = DataRoot(url: FileManager.default.temporaryDirectory.appending(path: "LibraryTests-\(UUID().uuidString)"))
        defer { try? FileManager.default.removeItem(at: root.url) }
        let first = Library(root: root)
        first.selected = .hp3
        first.setEdition(.remastered, for: .hp3)   // not offered for this year, so it must not stick
        let second = Library(root: root)
        XCTAssertEqual(second.selected, .hp3)
        XCTAssertEqual(second.state(.hp3).edition, .original)
        XCTAssertEqual(second.state(.hp1).edition, .original)
    }

    func testUnreadablePreferencesFallBackToDefaults() throws {
        let root = DataRoot(url: FileManager.default.temporaryDirectory.appending(path: "LibraryTests-\(UUID().uuidString)"))
        defer { try? FileManager.default.removeItem(at: root.url) }
        try FileManager.default.createDirectory(at: root.url, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: root.preferences)
        XCTAssertEqual(Library(root: root).selected, .hp1)
    }
}
