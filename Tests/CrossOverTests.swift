import XCTest
@testable import HP_Launcher

final class CrossOverTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "CrossOverTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    /// Builds a fake CrossOver bundle with only the pieces detection looks at.
    private func fake(_ name: String, version: String, identifier: String = "com.codeweavers.CrossOver",
                      fex: Bool = false, dxmt: Bool = true) throws -> CrossOver {
        let fm = FileManager.default
        let app = root.appending(path: "\(name).app")
        let support = app.appending(path: "Contents/SharedSupport/CrossOver")
        try fm.createDirectory(at: support.appending(path: "bin"), withIntermediateDirectories: true)
        try fm.createDirectory(at: support.appending(path: "lib/wine/aarch64-unix"), withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": identifier, "CFBundleShortVersionString": version,
                                    "CFBundleExecutable": "CrossOver", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: app.appending(path: "Contents/Info.plist"))
        for tool in ["wine", "cxbottle"] {
            let url = support.appending(path: "bin/\(tool)")
            try Data("#!/bin/sh\n".utf8).write(to: url)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        if fex { try Data().write(to: support.appending(path: "lib/wine/aarch64-unix/libwow64fex.so")) }
        if dxmt { try fm.createDirectory(at: support.appending(path: "lib/dxmt"), withIntermediateDirectories: true) }
        return CrossOver(app: app)
    }

    func testTestedPreviewIsRecognised() throws {
        let preview = try fake("Preview", version: "20260821", fex: true)
        XCTAssertEqual(try preview.support(), .tested)
        XCTAssertEqual(preview.kind, .arm64)
        XCTAssertEqual(preview.name, "CrossOver Preview 20260821")
    }

    func testCrossOver26IsCompatibleX86() throws {
        let release = try fake("Release", version: "26.3")
        XCTAssertEqual(try release.support(), .compatible)
        XCTAssertEqual(release.kind, .x86)
        XCTAssertEqual(release.name, "CrossOver 26.3")
    }

    func testNewerBuildsAreCompatibleButNotTested() throws {
        XCTAssertEqual(try fake("NewPreview", version: "20270101", fex: true).support(), .compatible)
        XCTAssertEqual(try fake("Next", version: "27.0", fex: true).support(), .compatible)
    }

    func testUnsupportedInstallsAreRejectedWithTheRightReason() throws {
        XCTAssertThrowsError(try fake("Old", version: "25.1").support()) { XCTAssertEqual($0 as? CrossOver.Problem, .unsupportedVersion("CrossOver 25.1")) }
        XCTAssertThrowsError(try fake("OldPreview", version: "20260101", fex: true).support())
        XCTAssertThrowsError(try fake("PreviewWithoutFEX", version: "20260901").support())
        XCTAssertThrowsError(try fake("NoDXMT", version: "26.3", dxmt: false).support()) { XCTAssertEqual($0 as? CrossOver.Problem, .missingGraphics("CrossOver 26.3")) }
        XCTAssertThrowsError(try fake("Other", version: "26.3", identifier: "org.example.Other").support()) { XCTAssertEqual($0 as? CrossOver.Problem, .notCrossOver) }
        XCTAssertThrowsError(try CrossOver(app: root.appending(path: "Missing.app")).support())
    }

    func testDiscoveryPrefersTheTestedPreview() throws {
        let release = try fake("CrossOver", version: "26.3")
        let preview = try fake("CrossOver Preview", version: "20260821", fex: true)
        XCTAssertEqual(CrossOver.discover(in: [release.app.path, preview.app.path])?.app, preview.app)
        XCTAssertEqual(CrossOver.discover(in: [release.app.path])?.app, release.app)
        XCTAssertNil(CrossOver.discover(in: [root.appending(path: "None.app").path]))
    }
}
