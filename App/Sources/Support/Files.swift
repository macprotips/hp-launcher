import CryptoKit
import Foundation

enum Files {
    static var fm: FileManager { .default }

    static func exists(_ url: URL) -> Bool { fm.fileExists(atPath: url.path) }

    static func isDirectory(_ url: URL) -> Bool {
        var dir: ObjCBool = false
        return fm.fileExists(atPath: url.path, isDirectory: &dir) && dir.boolValue
    }

    static func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    static func makeDirectory(_ url: URL) throws {
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
    }

    static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Resolves `relative` under `root` one component at a time, ignoring case, as the games were
    /// built for Windows. Exactly one match per component; links and `..` are refused.
    static func resolve(_ relative: String, in root: URL) -> URL? {
        var current = root
        for part in relative.split(separator: "/").map(String.init) {
            guard part != "..", part != ".",
                  let entries = try? fm.contentsOfDirectory(at: current, includingPropertiesForKeys: [.isSymbolicLinkKey]) else { return nil }
            let matches = entries.filter { $0.lastPathComponent.caseInsensitiveCompare(part) == .orderedSame }
            guard matches.count == 1, !isSymlink(matches[0]) else { return nil }
            current = matches[0]
        }
        return current
    }

    /// Free space for important data on the volume holding `url`.
    static func freeSpace(at url: URL) -> Int64 {
        var probe = url
        while !exists(probe) { probe.deleteLastPathComponent() }
        return (try? probe.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? 0
    }
}
