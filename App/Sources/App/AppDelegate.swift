import AppKit

/// Closing the window quits, unless setup is still copying files: an interrupted setup has to be
/// undone next time, so the app stays open until it finishes, and Quit asks first.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var library: Library?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { library?.activity == nil }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let activity = library?.activity else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "HP Launcher is still working"
        alert.informativeText = "\(activity) Quitting now stops it, and setup will need to run again."
        alert.addButton(withTitle: "Keep Working")
        alert.addButton(withTitle: "Quit Anyway")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}
