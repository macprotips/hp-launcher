import SwiftUI

/// What each edition of a game needs and offers, shown from the ⓘ beside the edition tabs.
struct EditionInfo: View {
    let game: GameID
    let remasteredAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("Original", lines: [
                "The \(game.year) PC game, exactly as it shipped.",
                "Runs through CrossOver, with dgVoodoo for the graphics.",
                "Needs a copy without disc copy protection.",
                "Keyboard and mouse.",
            ])
            section("Remastered", lines: remasteredAvailable ? remasteredLines : ["Coming in a later update."])
            section("Custom", lines: [
                "Another developer’s engine, such as a decompilation or recompilation, run on your game files.",
                "Choose the engine in Setup. It keeps its own saves and settings.",
            ])
        }
        .padding(20)
        .frame(width: 330, alignment: .leading)
    }

    private var remasteredLines: [String] {
        var lines = ["The game’s own levels, art, sound and scripts, running on a rebuilt engine made for the Mac. No CrossOver needed."]
        switch game {
        case .hp2:
            lines += ["Built on SurrealEngine, an open-source recreation of the original Unreal Engine.",
                      "Plays any PC copy, including one with disc copy protection.", "Plug in a controller and play."]
        case .hp3:
            lines += ["Its engine is written from scratch for this game.",
                      "Needs the North American PC release.", "Keyboard and mouse for now."]
        case .hp1:
            break
        }
        return lines + ["Keeps its own saves, separate from Original.",
                        "Beta: the whole story plays through, and some details may still differ from the original."]
    }

    private func section(_ title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased()).font(Theme.display(11)).tracking(2.2).foregroundStyle(Theme.gold)
            ForEach(lines, id: \.self) { line in
                Text(line).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
