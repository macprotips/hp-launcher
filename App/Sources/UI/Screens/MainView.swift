import SwiftUI

struct MainView: View {
    @Environment(Library.self) private var library

    var body: some View {
        @Bindable var library = library
        let game = library.selected
        GeometryReader { window in
            // The title block grows with the window, up to 1.5x, so it holds its place on large displays.
            let scale = min(max(window.size.height / 660, 1), 1.5)
            ZStack(alignment: .bottomLeading) {
                NightScene(game: game)
                    .id(game)
                    .transition(.opacity)
                Hero(game: game, scale: scale)
                    .id(game)
                    .transition(.opacity.combined(with: .offset(y: 6)))
                    .padding(.leading, 72 * scale)
                    .padding(.trailing, 64)
                    .padding(.bottom, 64 * scale)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: game)
        .foregroundStyle(Theme.ink)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Game", selection: $library.selected) {
                    ForEach(GameID.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            ToolbarItem(placement: .primaryAction) {
                SettingsLink { Label("Settings", systemImage: "gearshape") }
                    .help("Settings")
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .sheet(isPresented: $library.showingSetup) { SetupView(game: game) }
    }
}

/// Year, title, an optional status line, then Play and the edition.
private struct Hero: View {
    @Environment(Library.self) private var library
    let game: GameID
    var scale: CGFloat = 1

    var body: some View {
        let ready = library.isReady(game)
        let edition = library.state(game).edition

        VStack(alignment: .leading, spacing: 0) {
            Text("\(game.schoolYear) · \(String(game.year))".uppercased())
                .font(Theme.display(12 * scale))
                .tracking(3.4 * scale)
                .foregroundStyle(Theme.gold)
            Text(game.title)
                .font(Theme.display(52 * scale))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 4)
                .padding(.top, 6)
            if let status {
                Text(status)
                    .font(.system(size: 14 * min(scale, 1.2)))
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.top, 6)
            }
            HStack(spacing: 28) {
                Button {
                    guard ready else { library.showingSetup = true; return }
                    library.start(game)
                } label: {
                    Label(!ready ? "Set Up" : library.canContinue(game) ? "Continue" : "Play", systemImage: ready ? "play.fill" : "plus")
                }
                .buttonStyle(CandleButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(library.activity != nil || library.running != nil)
                .contextMenu {
                    if ready && library.canContinue(game) {
                        Button("Start a New Game") { library.start(game, newGame: true) }.disabled(library.activity != nil || library.running != nil)
                    }
                    if ready { Button("Set Up Again…") { library.showingSetup = true }.disabled(library.activity != nil) }
                }
                .accessibilityHint(ready ? "Starts \(game.title), \(edition.title)" : "Opens the setup steps for \(game.title)")
                EditionTabs(game: game, selection: edition, available: { library.available($0, for: game) }) { library.setEdition($0, for: game) }
            }
            .padding(.top, 26)
        }
        .alert("Couldn’t start \(game.title)", isPresented: Binding(get: { library.problem != nil }, set: { if !$0 { library.problem = nil } })) {
            Button("OK") {}
            if Files.exists(library.paths(game).log) {
                Button("Show Log") { NSWorkspace.shared.activateFileViewerSelecting([library.paths(game).log]) }
            }
        } message: { Text(library.problem ?? "") }
    }

    /// Shown only when it adds something the button doesn't say.
    private var status: String? {
        if let activity = library.activity { return activity }
        if library.running == game { return "Playing now." }
        if let other = library.running { return "\(other.title) is running." }
        if let last = library.state(game).lastPlayed { return "Last played \(last.formatted(.relative(presentation: .named)))." }
        return nil
    }
}

/// Original and Remastered as small caps with a gold rule under the chosen one.
private struct EditionTabs: View {
    let game: GameID
    let selection: Edition
    let available: (Edition) -> Bool
    let choose: (Edition) -> Void
    @Namespace private var rule

    var body: some View {
        HStack(spacing: 22) {
            ForEach(Edition.allCases, id: \.self) { edition in
                let selected = edition == selection
                let offered = available(edition)
                Button { withAnimation(.snappy(duration: 0.25)) { choose(edition) } } label: {
                    VStack(spacing: 7) {
                        Text(edition.title.uppercased())
                            .font(Theme.display(13))
                            .tracking(2.4)
                            .foregroundStyle(selected ? Theme.ink : Theme.secondaryInk.opacity(offered ? 0.75 : 0.6))
                        ZStack {
                            Capsule().fill(.clear).frame(height: 1.5)
                            if selected { Capsule().fill(Theme.gold).frame(height: 1.5).matchedGeometryEffect(id: "rule", in: rule) }
                        }
                    }
                    .fixedSize()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!offered)
                .help(offered ? edition.summary(for: game) : "Remastered isn’t available for \(game.title) yet.")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Edition")
    }
}
