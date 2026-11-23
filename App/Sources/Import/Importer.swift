import Foundation

/// installation.json: what the importer found in the copy it installed.
struct InstallRecord: Codable, Equatable, Sendable {
    var format = 1
    var game: GameID
    var executableSHA256: String
    var copyProtected: Bool
    var fileCount: Int
    var bytes: Int64
    var importedAt: Date
}

/// Copies a game from the player's folder, ZIP or disc image into Games/HPx/Game. The player's own
/// files are only read.
struct Importer: Sendable {
    let paths: GamePaths
    var progress: @Sendable (String) -> Void = { _ in }

    static let maxFiles = 50_000
    static let maxFileBytes: Int64 = 2 << 30
    static let maxTotalBytes: Int64 = 16 << 30

    func run(from source: URL) async throws -> InstallRecord {
        try require(Files.freeSpace(at: paths.root) > 3 << 30, "Setting up needs about 3 GB of free space. Free some space and try again.")
        Self.removeLeftovers(in: paths.root, game: paths.game)
        let work = paths.root.appending(path: ".Import-\(UUID().uuidString)")
        try Files.makeDirectory(work)
        var mounted: URL?
        let result: Result<InstallRecord, Error>
        do { result = .success(try await importFiles(from: source, work: work, mounted: &mounted)) } catch { result = .failure(error) }
        // Unmount the disc before removing the folder it is mounted in.
        if let mounted { _ = try? await Command.run(URL(filePath: "/usr/bin/hdiutil"), ["detach", mounted.path, "-force"], timeout: 60) }
        try? FileManager.default.removeItem(at: work)
        return try result.get()
    }

    /// Cleans up after a setup that was interrupted. A game being replaced is put back, or if the new
    /// copy was already in place, HP1's saves are carried over first. A folder that can't be made safe is kept.
    static func removeLeftovers(in root: URL, game: GameID) {
        let fm = FileManager.default
        let install = root.appending(path: "Game")
        for entry in (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        where entry.lastPathComponent.hasPrefix(".Import-") || entry.lastPathComponent.hasPrefix(".Graphics-") {
            let disc = entry.appending(path: "Disc")
            if Files.exists(disc) { _ = try? Process.run(URL(filePath: "/usr/bin/hdiutil"), arguments: ["detach", disc.path, "-force"]).waitUntilExit() }
            let previous = entry.appending(path: "Previous"), previousRecord = entry.appending(path: "Previous.json")
            if Files.exists(previous) {
                if !Files.exists(install) {
                    guard (try? fm.moveItem(at: previous, to: install)) != nil else { continue }
                    if Files.exists(previousRecord) { try? fm.moveItem(at: previousRecord, to: root.appending(path: "installation.json")) }
                } else if (try? keepPlayerFiles(game, from: previous, into: install)) == nil {
                    continue
                }
            }
            try? fm.removeItem(at: entry)
        }
    }

    private func importFiles(from source: URL, work: URL, mounted: inout URL?) async throws -> InstallRecord {
        let game = paths.game
        progress("Reading your files…")
        let media: URL
        switch source.pathExtension.lowercased() {
        case "iso", "dmg", "cdr":
            // Mount a private copy: hdiutil hangs, then fails, on an image the launcher opens straight from Downloads.
            let size = Int64((try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            try require(size > 0 && size <= Self.maxTotalBytes, "That doesn’t look like a disc image of \(game.title).")
            try require(Files.freeSpace(at: paths.root) > size + 3 << 30,
                        "Setting up from this disc image needs more free space. Free some space and try again.")
            let image = work.appending(path: "Image." + source.pathExtension)
            progress("Reading your disc image…")
            try FileManager.default.copyItem(at: source, to: image)
            progress("Opening the disc…")
            let mountPoint = work.appending(path: "Disc")
            try Files.makeDirectory(mountPoint)
            try await Command.check(URL(filePath: "/usr/bin/hdiutil"),
                                    ["attach", image.path, "-readonly", "-nobrowse", "-noautoopen", "-mountpoint", mountPoint.path],
                                    log: paths.log, timeout: 90, failure: "That disc image couldn’t be opened. Check that it isn’t damaged.")
            mounted = mountPoint
            media = mountPoint
        case "zip":
            let size = Int64((try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            try require(Files.freeSpace(at: paths.root) > size * 3 + 3 << 30, "Setting up from this ZIP needs more free space. Free some space and try again.")
            let expanded = work.appending(path: "Extracted")
            try await Command.check(URL(filePath: "/usr/bin/ditto"), ["-x", "-k", source.path, expanded.path],
                                    log: paths.log, timeout: 900, failure: "That ZIP couldn’t be opened. Check that it isn’t damaged.")
            media = expanded
        case "exe", "bin":
            throw LauncherError("That’s an installer, which HP Launcher can’t run. Choose the folder the game was installed to on a PC, a ZIP of it, or the game’s disc image.")
        default:
            try require(Files.isDirectory(source), "Choose a disc image, ZIP or folder with your copy of \(game.title).")
            media = source
        }

        let folder = try Self.findGame(game, in: media)
        for file in game.requiredFiles {
            try require(Files.resolve(file, in: folder) != nil, "Your copy is missing \(file). Choose a complete copy of \(game.title).")
        }

        progress("Copying game files…")
        let staging = work.appending(path: "Game")
        let copied = try copyGame(from: folder, to: staging)

        let executable = try program(Files.resolve("\(game.systemFolder)/\(game.executable)", in: staging), game)
        let protected = try Executable.isCopyProtected(executable)
        let executableHash = try Files.sha256(executable)

        try require(GameSettings.shallowestDefaultINI(in: staging.appending(path: game.systemFolder)) != nil,
                    "Your copy is missing its Default.ini settings file. Choose a complete copy of \(game.title).")
        let record = InstallRecord(game: game, executableSHA256: executableHash, copyProtected: protected,
                                   fileCount: copied.count, bytes: copied.reduce(0) { $0 + $1.bytes }, importedAt: .now)
        let newRecord = work.appending(path: "installation.json"), newFiles = work.appending(path: "imported-files.json")
        try JSONEncoder.pretty.encode(record).write(to: newRecord, options: .atomic)
        try JSONEncoder.pretty.encode(copied).write(to: newFiles, options: .atomic)

        // The old copy and its record step aside together, so the record never describes the wrong files.
        // A quit part way through is put right by removeLeftovers.
        progress("Installing…")
        let fm = FileManager.default
        let previous = work.appending(path: "Previous"), previousRecord = work.appending(path: "Previous.json")
        let replacing = Files.exists(paths.install)
        if Files.exists(paths.record) { try fm.moveItem(at: paths.record, to: previousRecord) }
        do {
            if replacing { try fm.moveItem(at: paths.install, to: previous) }
            try Files.makeDirectory(paths.install.deletingLastPathComponent())
            try fm.moveItem(at: staging, to: paths.install)
            if replacing { try Self.keepPlayerFiles(game, from: previous, into: paths.install) }
        } catch {
            if replacing { try? fm.removeItem(at: paths.install); try? fm.moveItem(at: previous, to: paths.install) }
            if Files.exists(previousRecord) { try? fm.moveItem(at: previousRecord, to: paths.record) }
            throw error
        }
        if Files.exists(paths.files) { try fm.removeItem(at: paths.files) }
        try fm.moveItem(at: newFiles, to: paths.files)
        try fm.moveItem(at: newRecord, to: paths.record)
        return record
    }

    /// HP1 keeps saves and settings inside the game folder, so a replacement must carry them over.
    /// Each copy is checked against its original before the old folder can go.
    static func keepPlayerFiles(_ game: GameID, from previous: URL, into install: URL) throws {
        guard game == .hp1 else { return }
        let fm = FileManager.default
        var carried: [(URL, URL)] = []
        if let saves = Files.resolve("Save", in: previous) {
            let target = Files.resolve("Save", in: install) ?? install.appending(path: "Save")
            try Files.makeDirectory(target)
            for file in try fm.contentsOfDirectory(at: saves, includingPropertiesForKeys: nil) where file.pathExtension.lowercased() != "bmp" {
                let destination = target.appending(path: file.lastPathComponent)
                if !Files.exists(destination) { try fm.copyItem(at: file, to: destination) }
                carried.append((file, destination))
            }
        }
        let system = Files.resolve(game.systemFolder, in: install) ?? install.appending(path: game.systemFolder)
        for name in [game.settingsFile, "User.ini"] {
            guard let file = Files.resolve("\(game.systemFolder)/\(name)", in: previous) else { continue }
            let destination = Files.resolve(name, in: system) ?? system.appending(path: name)
            if !Files.exists(destination) { try fm.copyItem(at: file, to: destination) }
            carried.append((file, destination))
        }
        for (original, copy) in carried {
            try require(try Files.sha256(original) == Files.sha256(copy),
                        "Your saved games couldn’t be carried over safely, so nothing was changed. Try again.")
        }
    }

    // MARK: Finding the game

    /// Finds the folder holding this game, up to eight levels down, and explains a wrong game or a duplicate.
    static func findGame(_ game: GameID, in root: URL) throws -> URL {
        var queue: [(URL, Int)] = [(root, 0)]
        var matches: [URL] = []
        var otherGame: GameID?
        var visited = 0
        while !queue.isEmpty {
            let (folder, depth) = queue.removeFirst()
            visited += 1
            guard visited < 20_000 else { break }
            if Files.resolve("Maps", in: folder) != nil, Files.resolve("System", in: folder) != nil {
                if game.identityFiles.allSatisfy({ Files.resolve($0, in: folder) != nil }) { matches.append(folder); continue }
                otherGame = otherGame ?? GameID.allCases.first { other in other.identityFiles.allSatisfy { Files.resolve($0, in: folder) != nil } }
            }
            guard depth < 8, let children = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: .skipsHiddenFiles) else { continue }
            for child in children where Files.isDirectory(child) && !Files.isSymlink(child) { queue.append((child, depth + 1)) }
        }
        if matches.count == 1 { return matches[0] }
        try require(matches.isEmpty, "These files contain more than one copy of \(game.title). Choose the folder of just one copy.")
        if let otherGame { throw LauncherError("These are the files for \(otherGame.title), not \(game.title).") }
        if holdsInstaller(root) {
            throw LauncherError("This disc keeps \(game.title) packed inside its installer, which HP Launcher can’t open yet. Install the game on a Windows PC, then choose the installed game folder.")
        }
        throw LauncherError("\(game.title) wasn’t found in what you chose. Choose the disc image, ZIP or game folder of your PC copy.")
    }

    /// A disc whose game is still packed in InstallShield cabinets.
    private static func holdsInstaller(_ root: URL) -> Bool {
        let fm = FileManager.default
        let top = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        let inner = top.filter(Files.isDirectory).prefix(40).flatMap { (try? fm.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? [] }
        return (top + inner).contains { file in
            let name = file.lastPathComponent.lowercased()
            return name.hasSuffix(".cab") || name == "setup.exe" || name == "data1.hdr"
        }
    }

    // MARK: Copying

    struct CopiedFile: Codable, Equatable, Sendable { let path: String; let bytes: Int64; let sha256: String }

    private static let skippedExtensions: Set<String> = ["log", "sys", "tmp", "original"]
    private static let skippedNames: Set<String> = ["hp.ini", "user.ini", "game.ini", "hppoa.ini", "running.ini"]

    private func copyGame(from folder: URL, to staging: URL) throws -> [CopiedFile] {
        let game = paths.game
        var copied: [CopiedFile] = []
        var total: Int64 = 0
        let topLevel = game.requiredFolders.map { ($0, true) } + game.optionalFolders.map { ($0, false) }
        for (name, required) in topLevel {
            guard let source = Files.resolve(name, in: folder) else {
                try require(!required, "Your copy is missing its \(name) folder. Choose a complete copy of \(game.title).")
                continue
            }
            let target = name == "System" ? game.systemFolder : name
            let walker = FileManager.default.enumerator(at: source, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
                                                        options: .skipsHiddenFiles)
            while let file = walker?.nextObject() as? URL {
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                try require(values.isSymbolicLink != true, "Your copy contains a linked file, which isn’t supported. Choose a regular copy of the game.")
                guard values.isRegularFile == true else { continue }
                let relative = target + "/" + file.path.dropFirst(source.path.count + 1)
                let lower = file.lastPathComponent.lowercased()
                let ext = file.pathExtension.lowercased()
                if Self.skippedExtensions.contains(ext) || Self.skippedNames.contains(lower) { continue }
                if name == "save" && ext != "bmp" { continue }   // level thumbnails only, never saves
                if ext == "exe" && lower != game.executable.lowercased() { continue }
                let size = Int64(values.fileSize ?? 0)
                try require(copied.count < Self.maxFiles && size <= Self.maxFileBytes && total + size <= Self.maxTotalBytes,
                            "Your copy is larger than any version of \(game.title). Choose just the game’s own files.")
                let destination = staging.appending(path: relative)
                try Files.makeDirectory(destination.deletingLastPathComponent())
                try FileManager.default.copyItem(at: file, to: destination)
                if ["exe", "dll"].contains(ext) {
                    try require(Executable.isWindows32(destination), "\(file.lastPathComponent) isn’t a valid Windows program.")
                }
                copied.append(CopiedFile(path: relative, bytes: size, sha256: try Files.sha256(destination)))
                total += size
            }
        }
        return copied
    }

    private func program(_ url: URL?, _ game: GameID) throws -> URL {
        guard let url else { throw LauncherError("Your copy is missing \(game.executable). Choose a complete copy of \(game.title).") }
        return url
    }
}
