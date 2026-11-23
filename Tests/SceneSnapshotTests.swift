import SwiftUI
import XCTest
@testable import HP_Launcher

/// Renders each year's night scene with its title to PNGs for design review.
/// Skipped unless HPL_SNAPSHOTS names a folder to write into.
@MainActor
final class SceneSnapshotTests: XCTestCase {
    func testRenderScenes() throws {
        guard let folder = ProcessInfo.processInfo.environment["HPL_SNAPSHOTS"] else { throw XCTSkip("Set HPL_SNAPSHOTS to render scenes.") }
        // The default window, the smallest it can be, and a large display.
        for (width, height) in [(1040.0, 660.0), (960, 600), (1800, 1040)] {
            for game in GameID.allCases {
                let view = ZStack(alignment: .bottomLeading) {
                    NightScene(game: game)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(game.schoolYear) · \(String(game.year))".uppercased()).font(Theme.display(12)).tracking(3.4).foregroundStyle(Theme.gold)
                        Text(game.title).font(Theme.display(52)).foregroundStyle(Theme.ink)
                        Capsule().fill(Theme.gold).frame(width: 176, height: 42).padding(.top, 20)
                    }
                    .padding(.leading, 72).padding(.bottom, 64)
                }
                .frame(width: width, height: height)
                let renderer = ImageRenderer(content: view)
                renderer.scale = width > 1500 ? 1 : 2
                let image = try XCTUnwrap(renderer.nsImage?.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0) }?.representation(using: .png, properties: [:]))
                let name = width == 1040 ? game.rawValue : "\(game.rawValue)-\(Int(width))x\(Int(height))"
                try image.write(to: URL(filePath: folder).appending(path: "\(name).png"))
            }
        }
    }

    /// The real screens with their native controls, drawn in an offscreen window.
    func testRenderScreens() throws {
        guard let folder = ProcessInfo.processInfo.environment["HPL_SNAPSHOTS"] else { throw XCTSkip("Set HPL_SNAPSHOTS to render screens.") }
        // HPL_SNAPSHOT_ROOT: a data folder with games already set up (from the end-to-end tests), to show real states.
        // HPL_SNAPSHOT_HELPERS: a built app's Contents/Helpers, so Remastered is offered.
        let env = ProcessInfo.processInfo.environment
        let scratch = FileManager.default.temporaryDirectory.appending(path: "Screens-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let library = Library(root: DataRoot(url: env["HPL_SNAPSHOT_ROOT"].map { URL(filePath: $0) } ?? scratch),
                              helpers: env["HPL_SNAPSHOT_HELPERS"].map { URL(filePath: $0) } ?? scratch)
        func capture<V: View>(_ name: String, _ size: CGSize? = nil, _ view: V) throws {
            let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)).environment(library).preferredColorScheme(.dark).tint(Theme.gold))
            let fitting = size ?? host.fittingSize
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: fitting), styleMask: [.titled], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(filePath: folder).appending(path: "screen-\(name).png"))
        }
        let window = CGSize(width: 1040, height: 660)
        for game in GameID.allCases {
            library.selected = game
            for edition in Edition.allCases where library.available(edition, for: game) {
                library.setEdition(edition, for: game)
                try capture("main-\(game.rawValue)-\(edition.rawValue)", window, MainView())
                try capture("setup-\(game.rawValue)-\(edition.rawValue)", nil, SetupView(game: game))
            }
        }
        for game in GameID.allCases {
            try capture("info-\(game.rawValue)", nil, EditionInfo(game: game, remasteredAvailable: game != .hp1))
        }
        try capture("settings", nil, SettingsView())
        try capture("help", nil, HelpView())
    }
}
