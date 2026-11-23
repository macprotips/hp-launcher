import Foundation

struct GameState: Codable, Equatable, Sendable {
    var edition: Edition = .original
    var lastPlayed: Date?
}

/// Saved to Preferences.json.
struct Preferences: Codable, Equatable, Sendable {
    var selected: GameID = .hp1
    var games: [GameID: GameState] = [:]
    var crossOverPath: String?

    func state(_ id: GameID) -> GameState { games[id] ?? GameState() }

    static func load(from url: URL) -> Preferences? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.iso8601.decode(Preferences.self, from: data)
    }

    /// Best effort: losing a preference must never block play.
    func save(to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder.pretty.encode(self).write(to: url, options: .atomic)
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
