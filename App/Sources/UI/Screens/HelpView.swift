import SwiftUI

/// The player guide, under Help > HP Launcher Help.
struct HelpView: View {
    private struct Topic: Identifiable {
        let title: String
        let lines: [String]
        var id: String { title }
    }

    private let topics = [
        Topic(title: "Getting started", lines: [
            "Pick a game at the top of the window, then choose Original or Remastered.",
            "Click Set Up and follow the steps. You do this once for each game.",
            "After that, click Play.",
        ]),
        Topic(title: "Your game files", lines: [
            "HP Launcher doesn’t include the games. It uses your own PC copy.",
            "In Setup, choose the folder the game is installed in, a ZIP of that folder, or a disc image.",
            "Your files are only read. HP Launcher keeps its own copy and never changes yours.",
        ]),
        Topic(title: "Remastered", lines: [
            "A new engine that runs your game files natively on your Mac. It needs nothing else.",
            "Available for Chamber of Secrets and Prisoner of Azkaban. Sorcerer’s Stone follows in a later update.",
            "Both are early releases: the whole story plays through, and some details may still differ from the original.",
            "Chamber of Secrets plays any PC copy, including one with disc copy protection, and works with controllers. Prisoner of Azkaban needs the North American PC release and uses the keyboard and mouse for now.",
            "For a summary of each game’s editions, click ⓘ next to Original and Remastered.",
        ]),
        Topic(title: "How the remasters work", lines: [
            "They aren’t new versions of the games. The originals were Windows programs built on the Unreal Engine. Each remaster replaces that engine with a new one written for the Mac, and plays the game’s own levels, art, sound and scripts on it unchanged.",
            "Because the engine runs natively on Apple silicon and draws with Metal, there is no Windows layer: no CrossOver, and no graphics add-on.",
            "Chamber of Secrets runs on SurrealEngine, an open-source recreation of the original Unreal Engine, extended with what this game needs. Prisoner of Azkaban, made on a later version of the Unreal Engine, has its own engine written from scratch.",
            "Each part was checked against how the original game behaves, so movement, spells and cutscenes work the way they did.",
        ]),
        Topic(title: "Original", lines: [
            "The game exactly as it shipped, running through CrossOver from CodeWeavers. Get CrossOver 26 or newer, or CrossOver Preview, which is much faster.",
            "It also needs dgVoodoo 2.79.3, a free graphics add-on. Download the ZIP from its author and choose it in Setup.",
            "Discs from those years carry copy protection that can’t run on a modern system. Original needs a copy without it. Remastered doesn’t.",
        ]),
        Topic(title: "Saved games", lines: [
            "Original and Remastered keep separate saves, and switching edition never deletes either.",
            "To find them, choose Game > Show Saved Games in Finder.",
            "Chamber of Secrets, Original: Continue picks up your latest save. To begin again without losing it, choose Game > Start a New Game. There is room for six.",
        ]),
        Topic(title: "If something goes wrong", lines: [
            "Run Setup again from the Game menu. It checks each step and shows what is missing.",
            "Each game keeps a log. Choose Game > Show Log in Finder.",
        ]),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("HP Launcher Help").font(Theme.display(28))
                ForEach(topics) { topic in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(topic.title.uppercased())
                            .font(Theme.display(12)).tracking(2.4).foregroundStyle(Theme.gold)
                        ForEach(topic.lines, id: \.self) { line in
                            Text(line).font(.system(size: 14)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 560, height: 620)
        .textSelection(.enabled)
    }
}
