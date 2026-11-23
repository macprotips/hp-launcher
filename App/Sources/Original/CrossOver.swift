import Foundation

/// A CrossOver installation, judged by what it contains rather than by its version alone.
/// ARM64 builds (the Preview line) run x86 games through FEX and are fast. x86 builds (the 26.x
/// releases) run under Rosetta and are much slower: HP2 takes about 80 s to reach its title screen.
struct CrossOver: Equatable, Sendable {
    enum Kind: String, Sendable { case arm64, x86 }
    enum Support: Equatable, Sendable { case tested, compatible }

    /// Previews the games have been played on. The oldest is the minimum.
    static let testedPreviews = ["20260821", "20261015"]
    static let knownLocations = [
        "/Applications/CrossOver.app",
        "/Applications/CrossOver Preview.app",
    ]

    let app: URL

    var root: URL { app.appending(path: "Contents/SharedSupport/CrossOver") }
    var wine: URL { root.appending(path: "bin/wine") }
    var cxbottle: URL { root.appending(path: "bin/cxbottle") }

    var version: String {
        Bundle(url: app)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// Previews are numbered by date (20260821); releases by version (26.3).
    var isPreview: Bool { version.count == 8 && version.allSatisfy(\.isNumber) }

    var kind: Kind {
        FileManager.default.fileExists(atPath: root.appending(path: "lib/wine/aarch64-unix/libwow64fex.so").path) ? .arm64 : .x86
    }

    var name: String { (isPreview ? "CrossOver Preview " : "CrossOver ") + version }

    private var hasDXMT: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: root.appending(path: "lib/dxmt").path)
            || ["x86_64", "aarch64"].contains { fm.fileExists(atPath: root.appending(path: "lib/wine/\($0)-windows/winemetal.dll").path) }
    }

    enum Problem: Error, Equatable, Sendable {
        case notCrossOver, unsupportedVersion(String), missingGraphics(String)

        var message: String {
            switch self {
            case .notCrossOver: "That isn’t CrossOver. Choose CrossOver 26 or newer, or CrossOver Preview."
            case .unsupportedVersion(let name): "\(name) is too old. Choose CrossOver 26 or newer, or CrossOver Preview."
            case .missingGraphics(let name): "\(name) is missing its Metal graphics support. Reinstall it from CodeWeavers."
            }
        }
    }

    func support() throws(Problem) -> Support {
        let fm = FileManager.default
        guard let bundle = Bundle(url: app), (bundle.bundleIdentifier ?? "").hasPrefix("com.codeweavers.CrossOver"),
              fm.isExecutableFile(atPath: wine.path), fm.isExecutableFile(atPath: cxbottle.path) else {
            throw .notCrossOver
        }
        let supported = isPreview
            ? (Int(version) ?? 0) >= Int(Self.testedPreviews[0])! && kind == .arm64
            : (version.split(separator: ".").first.flatMap { Int($0) } ?? 0) >= 26
        guard supported else { throw .unsupportedVersion(name) }
        guard hasDXMT else { throw .missingGraphics(name) }
        return Self.testedPreviews.contains(version) && kind == .arm64 ? .tested : .compatible
    }

    var isUsable: Bool { (try? support()) != nil }

    /// A tested Preview first, then any usable CrossOver in Applications.
    static func discover(in locations: [String] = knownLocations) -> CrossOver? {
        let found = locations.map { CrossOver(app: URL(filePath: $0)) }
        return found.first { (try? $0.support()) == .tested } ?? found.first { $0.isUsable }
    }
}
