import SwiftUI

@main
struct HPLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var library = Library()

    var body: some Scene {
        Window("HP Launcher", id: "main") {
            MainView()
                .environment(library)
                .frame(minWidth: 960, idealWidth: 1040, minHeight: 600, idealHeight: 660)
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
                .onAppear { delegate.library = library }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in library.refresh() }
        }
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1040, height: 660)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .toolbar) {}   // hiding the toolbar would hide the game picker
            GameCommands(library: library)
            CommandGroup(replacing: .help) { HelpCommand() }
        }

        Window("HP Launcher Help", id: "help") {
            HelpView().preferredColorScheme(.dark)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environment(library)
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
        }
    }
}
