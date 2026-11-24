import SwiftUI
import UniformTypeIdentifiers

/// The steps to make a game playable in the chosen edition, each marked done or not.
struct SetupView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    let game: GameID
    /// One open panel serves every step: SwiftUI handles only one file importer per view reliably.
    private enum Choice { case crossOver, files, graphics, engine }
    @State private var choosing = false
    @State private var target = Choice.files   // separate from `choosing`, which resets before the result arrives
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            let edition = library.state(game).edition
            let original = edition == .original
            VStack(alignment: .leading, spacing: 6) {
                Text("Set Up \(game.title)").font(Theme.display(26))
                Text(library.isReady(game) ? "Ready to play." : subtitle(edition))
                    .font(.system(size: 14)).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                if original {
                    Step(number: 1, title: "CrossOver", detail: crossOverDetail, done: library.crossOver != nil,
                         action: library.crossOver == nil ? "Choose…" : "Change…") { choose(.crossOver) }
                    Divider().padding(.leading, 58)
                }
                Step(number: original ? 2 : 1, title: "Your game files", detail: filesDetail(original: original),
                     done: library.isInstalled(game) && filesProblem(original: original) == nil,
                     action: library.isInstalled(game) ? "Replace…" : "Choose…",
                     enabled: library.activity == nil) { choose(.files) }
                if original {
                    Divider().padding(.leading, 58)
                    Step(number: 3, title: "Graphics support", detail: graphicsDetail,
                         done: library.graphicsReady(game), action: library.graphicsReady(game) ? "Replace…" : "Choose…",
                         enabled: library.isInstalled(game) && library.activity == nil) { choose(.graphics) }
                }
                if edition == .custom {
                    let engine = library.state(game).customEngine
                    Divider().padding(.leading, 58)
                    Step(number: 2, title: "Engine", detail: engineDetail(engine), done: engine?.exists == true,
                         action: engine == nil ? "Choose…" : "Change…") { choose(.engine) }
                    if let engine {
                        ArgumentsField(engine: engine) { library.setCustomEngine($0, for: game) }
                    }
                }
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            if let activity = library.activity {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text(activity).font(.system(size: 13)).foregroundStyle(.secondary) }
            }
            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if Files.exists(library.paths(game).log) {
                    Button("Show Log") { NSWorkspace.shared.activateFileViewerSelecting([library.paths(game).log]) }.controlSize(.large)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction).controlSize(.large)
                    .disabled(library.activity != nil)
            }
        }
        .padding(32)
        .frame(width: 580)
        .onExitCommand { if library.activity == nil { dismiss() } }
        .interactiveDismissDisabled(library.activity != nil)
        .fileImporter(isPresented: $choosing, allowedContentTypes: allowedTypes) { result in
            guard case .success(let url) = result else { return }
            problem = nil
            switch target {
            case .crossOver:
                do { try library.useCrossOver(at: url) }
                catch let issue as CrossOver.Problem { problem = issue.message } catch { problem = error.localizedDescription }
            case .files:
                Task { do { try await library.importGame(game, from: url) } catch { problem = error.localizedDescription } }
            case .graphics:
                Task { do { try await library.installGraphics(game, from: url) } catch { problem = error.localizedDescription } }
            case .engine:
                let engine = CustomEngine(path: url.path, arguments: library.state(game).customEngine?.arguments ?? "")
                if engine.exists { library.setCustomEngine(engine, for: game) } else { problem = "That isn’t an app or a program HP Launcher can start." }
            }
        }
        .fileDialogDefaultDirectory(target == .crossOver ? URL(filePath: "/Applications") : target == .graphics ? .downloadsDirectory : nil)
    }

    private func choose(_ choice: Choice) {
        target = choice
        choosing = true
    }

    private var allowedTypes: [UTType] {
        switch target {
        case .crossOver: [.applicationBundle]
        case .graphics: [.zip]
        case .engine: [.application, .unixExecutable]
        default: [.folder, .zip, .diskImage, UTType(filenameExtension: "iso") ?? .data]
        }
    }

    private func subtitle(_ edition: Edition) -> String {
        switch edition {
        case .original: "Three steps, done once."
        case .remastered: "One step: add your copy of the game."
        case .custom: "Two steps: your copy of the game, then the engine to run it."
        }
    }

    private func engineDetail(_ engine: CustomEngine?) -> String {
        guard let engine else {
            return game == .hp1
                ? "Another developer’s engine, such as OpenHP1: choose its openhp1-game program, and HP Launcher sets it up."
                : "Another developer’s engine for \(game.title), such as a decompilation or recompilation. A Mac app or a command-line program."
        }
        guard engine.exists else { return "\(engine.name) isn’t where it was. Choose it again." }
        let ready = engine.isOpenHP1 ? "OpenHP1, set up to use your game files." : "\(engine.name). It starts in the game folder."
        guard engine.needsApproval else { return ready }
        return ready + " The first time, macOS will say it can’t open it, because it came from the internet. Click Done, then in System Settings > Privacy & Security, click Open Anyway and press Play again."
    }

    /// Why the installed copy can't be played in this edition, if it can't.
    private func filesProblem(original: Bool) -> String? {
        guard let record = library.record(game) else { return nil }
        if original && record.copyProtected {
            return "This copy still has its disc copy protection, which can’t run in CrossOver. Choose a copy without it, or play Remastered."
        }
        return library.state(game).edition == .remastered ? game.remasteredProblem(with: record) : nil
    }

    private func filesDetail(original: Bool) -> String {
        guard let record = library.record(game) else { return "The folder your PC copy of \(game.title) is installed in, or a ZIP or disc image of it." }
        if let problem = filesProblem(original: original) { return problem }
        return "Installed: \(record.fileCount) files, \(ByteCountFormatter.string(fromByteCount: record.bytes, countStyle: .file))."
    }

    private var graphicsDetail: String {
        guard Graphics.isInstalled(library.paths(game)) else {
            return "The free dgVoodoo 2.79.3. [Download the ZIP](\(Graphics.download)), then choose it here. Newer releases crash these games."
        }
        return "dgVoodoo \(Graphics.supportedVersion) is ready."
    }

    private var crossOverDetail: String {
        guard let crossOver = library.crossOver else {
            return "Runs the original Windows games. Get CrossOver 26 or newer, or CrossOver Preview, from [codeweavers.com](https://www.codeweavers.com/crossover), then choose it here."
        }
        switch try? crossOver.support() {
        case .tested: return "\(crossOver.name) is ready."
        default:
            return crossOver.kind == .x86
                ? "\(crossOver.name) works, but runs these games slowly. CrossOver Preview is much faster."
                : "\(crossOver.name) is ready. This version hasn’t been tested with HP Launcher yet."
        }
    }
}

/// Extra command-line arguments for a custom engine, saved as the player types.
private struct ArgumentsField: View {
    let engine: CustomEngine
    let save: (CustomEngine) -> Void
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Arguments (optional)", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
                .onSubmit(commit)
            Text("Only if the engine needs them. {game} stands for the game folder.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(.leading, 58)
        .padding(.trailing, 18)
        .padding(.bottom, 16)
        .onAppear { text = engine.arguments }
        .onChange(of: text) { commit() }
    }

    private func commit() {
        var updated = engine
        updated.arguments = text
        if updated != engine { save(updated) }
    }
}

private struct Step: View {
    let number: Int
    let title: String
    let detail: String
    let done: Bool
    let action: String
    var enabled = true
    let perform: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Group {
                if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                else { Image(systemName: "\(number).circle").foregroundStyle(.secondary) }
            }
            .font(.system(size: 20))
            .frame(width: 24)
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 5 }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(LocalizedStringKey(detail)).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(action, action: perform).disabled(!enabled)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .opacity(enabled || done ? 1 : 0.5)
    }
}
