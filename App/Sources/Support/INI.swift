import Foundation

/// Settings files of Unreal-era games: sectioned INI text with Windows line endings.
enum INI {
    /// Sets `values` inside `section`, replacing every matching key and adding missing ones.
    /// Other lines, comments and sections are kept exactly.
    static func update(_ text: String, section: String, values: [String: String]) -> String {
        var lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        let heading = "[\(section)]"
        var start = lines.firstIndex { $0.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(heading) == .orderedSame }
        if start == nil { lines.append(heading); start = lines.count - 1 }
        var end = lines[(start! + 1)...].firstIndex { $0.trimmingCharacters(in: .whitespaces).hasPrefix("[") } ?? lines.count
        for key in values.keys.sorted() {
            var found = false
            for i in (start! + 1)..<end {
                let name = lines[i].split(separator: "=", maxSplits: 1).first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                if name.caseInsensitiveCompare(key) == .orderedSame { lines[i] = "\(key)=\(values[key]!)"; found = true }
            }
            if !found { lines.insert("\(key)=\(values[key]!)", at: end); end += 1 }
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    static func value(_ text: String, section: String, key: String) -> String? {
        var inSection = false
        for raw in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") { inSection = line.caseInsensitiveCompare("[\(section)]") == .orderedSame; continue }
            guard inSection else { continue }
            let pair = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if pair.count == 2, pair[0].caseInsensitiveCompare(key) == .orderedSame { return pair[1] }
        }
        return nil
    }

    /// Reads a game settings file, which may be UTF-16, UTF-8 or Windows Latin-1.
    static func read(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        try require(data.count <= 8 << 20, "\(url.lastPathComponent) is too large to be a settings file.")
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) { return String(data: data, encoding: .utf16) ?? "" }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252) ?? ""
    }
}
