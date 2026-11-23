import Foundation

/// A problem the player can act on. The message is written for them, not for a log.
struct LauncherError: LocalizedError, Equatable {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

func require(_ condition: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String) throws {
    guard try condition() else { throw LauncherError(message()) }
}
