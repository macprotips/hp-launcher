import Foundation

/// The three games. Facts each feature needs live next to that feature: Import/GameFiles.swift,
/// Original/WindowsGame.swift and Remastered/RemasteredLaunch.swift.
enum GameID: String, CaseIterable, Codable, Identifiable, Sendable {
    case hp1, hp2, hp3

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hp1: "Sorcerer’s Stone"
        case .hp2: "Chamber of Secrets"
        case .hp3: "Prisoner of Azkaban"
        }
    }

    var year: Int {
        switch self {
        case .hp1: 2001
        case .hp2: 2002
        case .hp3: 2004
        }
    }

    var schoolYear: String {
        switch self {
        case .hp1: "Year I"
        case .hp2: "Year II"
        case .hp3: "Year III"
        }
    }
}

/// Original runs the shipped Windows game through CrossOver; Remastered runs a bundled native engine on
/// the same files; Custom runs an engine the player chooses.
enum Edition: String, CaseIterable, Codable, Sendable {
    case original, remastered, custom

    var title: String {
        switch self {
        case .original: "Original"
        case .remastered: "Remastered"
        case .custom: "Custom"
        }
    }

    func summary(for game: GameID) -> String {
        switch self {
        case .original: "The \(game.year) PC game, exactly as it shipped."
        case .remastered: "A modern rebuild that uses the same game files."
        case .custom: "Another developer’s engine, run on the same game files."
        }
    }
}
