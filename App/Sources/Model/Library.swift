import Foundation
import Observation

/// App state for the UI: preferences, what is installed, and setup and play.
@MainActor @Observable
final class Library {
    let root: DataRoot
    /// Contents/Helpers of this app; tests point it at a built app's.
    let helpers: URL

    private(set) var preferences: Preferences
    private(set) var crossOver: CrossOver?
    /// A line describing setup or launch in progress; nil when idle.
    private(set) var activity: String?
    private(set) var running: GameID?
    /// The last failed start, shown as an alert.
    var problem: String?
    /// Here rather than in the view so the Game menu can open Setup too.
    var showingSetup = false

    init(root: DataRoot = .standard, helpers: URL = Bundle.main.bundleURL.appending(path: "Contents/Helpers")) {
        self.root = root
        self.helpers = helpers
        preferences = Preferences.load(from: root.preferences) ?? Preferences()
        crossOver = preferences.crossOverPath.map { CrossOver(app: URL(filePath: $0)) }.flatMap { $0.isUsable ? $0 : nil }
            ?? CrossOver.discover()
    }

    func paths(_ id: GameID) -> GamePaths { GamePaths(game: id, data: root) }

    // MARK: Choices

    var selected: GameID {
        get { preferences.selected }
        set { update { $0.selected = newValue } }
    }

    /// The stored state, falling back to Original where Remastered isn't available.
    func state(_ id: GameID) -> GameState {
        var state = preferences.state(id)
        if !available(state.edition, for: id) { state.edition = .original }
        return state
    }

    func available(_ edition: Edition, for id: GameID) -> Bool { edition == .original || remasteredApp(id) != nil }

    func setEdition(_ edition: Edition, for id: GameID) {
        guard available(edition, for: id) else { return }
        update { $0.games[id, default: GameState()].edition = edition }
    }

    func useCrossOver(at app: URL) throws(CrossOver.Problem) {
        let candidate = CrossOver(app: app)
        _ = try candidate.support()
        crossOver = candidate
        update { $0.crossOverPath = app.path }
    }

    func remasteredApp(_ id: GameID) -> URL? {
        id.remasteredApp.map { helpers.appending(path: $0) }.flatMap { Files.exists($0) ? $0 : nil }
    }

    // MARK: What is installed

    /// Bumped whenever files may have changed. Disk status is cached per revision so views never
    /// hash files while drawing.
    private var revision = 0
    private struct Installed { var record: InstallRecord?; var files = false; var graphics = false }
    @ObservationIgnored private var cache: [GameID: (revision: Int, value: Installed)] = [:]

    private func installed(_ id: GameID) -> Installed {
        if let cached = cache[id], cached.revision == revision { return cached.value }
        var value = Installed()
        value.record = (try? Data(contentsOf: paths(id).record)).flatMap { try? JSONDecoder.iso8601.decode(InstallRecord.self, from: $0) }
        value.files = value.record != nil && Files.exists(paths(id).install)
        value.graphics = value.files && Graphics.isInstalled(paths(id))
        cache[id] = (revision, value)
        return value
    }

    /// For when files may have changed outside the launcher, such as when it becomes active again.
    func refresh() {
        guard activity == nil else { return }
        revision += 1
        if crossOver?.isUsable != true { crossOver = CrossOver.discover() }
    }

    func record(_ id: GameID) -> InstallRecord? { installed(id).record }
    func isInstalled(_ id: GameID) -> Bool { installed(id).files }
    func graphicsReady(_ id: GameID) -> Bool { installed(id).graphics }

    /// Remastered never runs the old program, so disc protection only matters for Original.
    func isReady(_ id: GameID) -> Bool {
        switch state(id).edition {
        case .original: crossOver != nil && isInstalled(id) && graphicsReady(id) && record(id)?.copyProtected == false
        case .remastered: isInstalled(id) && remasteredApp(id) != nil && id.remasteredProblem(with: record(id)) == nil
        }
    }

    /// HP2 Original only: the launcher, not the game, offers Continue and New Game.
    func offersNewGame(_ id: GameID) -> Bool { id == .hp2 && state(id).edition == .original }

    func canContinue(_ id: GameID) -> Bool {
        _ = revision
        return offersNewGame(id) && SaveSlots(paths: paths(id)).latest != nil
    }

    // MARK: Setup

    func importGame(_ id: GameID, from source: URL) async throws {
        try require(running != id, "Quit \(id.title) before replacing its files.")
        try require(activity == nil, "HP Launcher is still busy. Try again in a moment.")
        try await perform("Reading your files…") { [self] in
            let importer = Importer(paths: paths(id)) { message in
                Task { @MainActor in self.activity = message }
            }
            _ = try await withSecurityScope(source) { try await importer.run(from: source) }
            // Players add dgVoodoo once; later games reuse the copy kept by the first.
            if !Graphics.isInstalled(paths(id)), let kept = GameID.allCases.map({ paths($0).graphicsArchive }).first(where: Files.exists) {
                try? await Graphics.install(from: kept, into: paths(id))
            }
        }
    }

    func installGraphics(_ id: GameID, from archive: URL) async throws {
        try await perform("Installing graphics support…") { [self] in
            try await withSecurityScope(archive) { try await Graphics.install(from: archive, into: paths(id)) }
        }
    }

    // MARK: Play

    /// Starts a game, reporting failure through `problem`.
    func start(_ id: GameID, newGame: Bool = false) {
        Task {
            do { try await play(id, newGame: newGame) } catch { problem = error.localizedDescription }
        }
    }

    func play(_ id: GameID, newGame: Bool = false) async throws {
        try require(activity == nil, "HP Launcher is still busy. Try again in a moment.")
        try require(running == nil, "A game is already running. Quit it first.")
        try await perform("Starting \(id.title)…") { [self] in
            let process: Process
            switch state(id).edition {
            case .original:
                guard let crossOver else { throw LauncherError("Choose CrossOver in Setup first.") }
                var launch = GameLaunch(paths: paths(id), crossOver: crossOver)
                if id == .hp2 { (launch.slot, launch.newGame) = try SaveSlots(paths: paths(id)).choose(newGame: newGame) }
                process = try await launch.start(record: record(id))
            case .remastered:
                guard let app = remasteredApp(id) else { throw LauncherError("Remastered isn’t available for \(id.title) yet.") }
                guard isInstalled(id) else { throw LauncherError("Set up \(id.title) first.") }
                if let problem = id.remasteredProblem(with: record(id)) { throw LauncherError(problem) }
                process = try RemasteredLaunch(paths: paths(id), app: app).start()
            }
            running = id
            update { $0.games[id, default: GameState()].lastPlayed = .now }
            Task.detached { [weak self] in
                process.waitUntilExit()
                await MainActor.run { self?.running = nil; self?.revision += 1 }
            }
        }
    }

    // MARK: Helpers

    private func perform(_ start: String, _ work: () async throws -> Void) async throws {
        activity = start
        defer { activity = nil; revision += 1 }
        try await work()
    }

    /// Files chosen in an open panel are readable only inside this scope.
    private func withSecurityScope<T>(_ url: URL, _ work: () async throws -> T) async throws -> T {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try await work()
    }

    private func update(_ change: (inout Preferences) -> Void) {
        var next = preferences
        change(&next)
        guard next != preferences else { return }
        preferences = next
        next.save(to: root.preferences)
    }
}
