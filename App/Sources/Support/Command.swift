import Foundation

/// Runs helper tools and games, with their output appended to the game's log.
enum Command {
    struct Result: Sendable { let status: Int32; let output: String; var timedOut = false }

    /// Runs a tool to completion. A tool still running after `timeout` is stopped, then killed.
    @discardableResult
    static func run(_ executable: URL, _ arguments: [String], environment: [String: String]? = nil,
                    log: URL? = nil, timeout: TimeInterval = 180) async throws -> Result {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if let environment { process.environment = environment }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let stopped = Flag()
        return try await withCheckedThrowingContinuation { continuation in
            let collected = OutputBuffer()
            pipe.fileHandleForReading.readabilityHandler = { handle in collected.append(handle.availableData) }
            process.terminationHandler = { finished in
                pipe.fileHandleForReading.readabilityHandler = nil
                collected.append(pipe.fileHandleForReading.readDataToEndOfFile())
                let text = collected.text
                if let log { Log.append(text, to: log, command: ([executable.lastPathComponent] + arguments).joined(separator: " ")) }
                continuation.resume(returning: Result(status: finished.terminationStatus, output: text, timedOut: stopped.isSet))
            }
            do { try process.run() } catch { continuation.resume(throwing: error); return }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                guard process.isRunning else { return }
                stopped.set()
                process.terminate()
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) { if process.isRunning { kill(process.processIdentifier, SIGKILL) } }
            }
        }
    }

    /// Runs a tool, throwing `failure` on a non-zero exit.
    @discardableResult
    static func check(_ executable: URL, _ arguments: [String], environment: [String: String]? = nil,
                      log: URL? = nil, timeout: TimeInterval = 180, failure: String) async throws -> Result {
        let result = try await run(executable, arguments, environment: environment, log: log, timeout: timeout)
        if result.timedOut { throw LauncherError("That took too long and was stopped. Try again. If it happens again, open the log for details.") }
        guard result.status == 0 else { throw LauncherError(failure) }
        return result
    }

    /// Starts a long-running program, such as a game, and returns without waiting for it.
    static func launch(_ executable: URL, _ arguments: [String], environment: [String: String]? = nil, log: URL) throws -> Process {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if let environment { process.environment = environment }
        Log.append("", to: log, command: ([executable.lastPathComponent] + arguments).joined(separator: " "))
        let handle = try FileHandle(forWritingTo: log)
        defer { try? handle.close() }   // the child keeps its own descriptor
        _ = try handle.seekToEnd()
        process.standardOutput = handle
        process.standardError = handle
        try process.run()
        return process
    }
}

private final class Flag: @unchecked Sendable {
    private var value = false
    private let lock = NSLock()
    func set() { lock.withLock { value = true } }
    var isSet: Bool { lock.withLock { value } }
}

private final class OutputBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()
    func append(_ chunk: Data) { lock.withLock { data.append(chunk) } }
    var text: String { lock.withLock { String(decoding: data, as: UTF8.self) } }
}

enum Log {
    static func append(_ text: String, to url: URL, command: String? = nil) {
        try? Files.makeDirectory(url.deletingLastPathComponent())
        if !Files.exists(url) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        var entry = "[\(Date().formatted(.iso8601))]"
        if let command { entry += " $ \(command)" }
        entry += "\n" + text + (text.hasSuffix("\n") || text.isEmpty ? "" : "\n")
        try? handle.write(contentsOf: Data(entry.utf8))
    }
}
