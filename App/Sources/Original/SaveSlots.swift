import Foundation

/// HP2's six save slots. Its own slot menu doesn't draw under CrossOver, so the launcher chooses:
/// Continue takes the newest save, a new game the first empty slot.
struct SaveSlots: Sendable {
    let paths: GamePaths

    func folder(_ slot: Int) -> URL { paths.documents.appending(path: "Save/Slot\(slot)") }

    /// Last-saved dates. The game creates all six folders, so a slot counts as used once it holds Save0.usa.
    var used: [Int: Date] {
        var result: [Int: Date] = [:]
        for slot in 1...6 {
            let save = folder(slot).appending(path: "Save0.usa")
            if let date = try? save.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate { result[slot] = date }
        }
        return result
    }

    var latest: Int? { used.max { $0.value < $1.value }?.key }
    var firstEmpty: Int? { (1...6).first { used[$0] == nil } }

    /// The slot to play, and whether it starts a new game there.
    func choose(newGame: Bool) throws -> (slot: Int, isNew: Bool) {
        if !newGame, let latest { return (latest, false) }
        guard let firstEmpty else {
            throw LauncherError("All six save slots are in use. Choose Game > Show Saved Games in Finder and remove a Slot folder you no longer need.")
        }
        return (firstEmpty, true)
    }
}
