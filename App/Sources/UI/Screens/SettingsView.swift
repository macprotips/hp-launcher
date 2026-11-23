import SwiftUI
import UniformTypeIdentifiers

/// Which CrossOver runs Original, and the About section.
struct SettingsView: View {
    @Environment(Library.self) private var library
    @State private var choosingCrossOver = false
    @State private var showingLicenses = false
    @State private var problem: String?

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Button(library.crossOver == nil ? "Choose…" : "Change…") { choosingCrossOver = true }
                } label: {
                    Text("CrossOver")
                    Text(library.crossOver?.name ?? "Not found. Get it from codeweavers.com.")
                }
                if let problem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(.orange)
                }
            } footer: {
                Text("CrossOver runs the Original games. Remastered doesn’t need it.")
            }
            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                LabeledContent("Open-source software") {
                    Button("View Licenses…") { showingLicenses = true }.disabled(Self.licenses == nil)
                }
                Text("An independent launcher, not affiliated with or endorsed by Warner Bros., Electronic Arts or CodeWeavers. Games, CrossOver and dgVoodoo are not included.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .fileImporter(isPresented: $choosingCrossOver, allowedContentTypes: [.applicationBundle]) { result in
            guard case .success(let url) = result else { return }
            do { try library.useCrossOver(at: url); problem = nil }
            catch let issue as CrossOver.Problem { problem = issue.message } catch { problem = error.localizedDescription }
        }
        .fileDialogDefaultDirectory(URL(filePath: "/Applications"))
        .sheet(isPresented: $showingLicenses) {
            VStack(spacing: 0) {
                ScrollView {
                    Text(Self.licenses ?? "").font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                }
                Divider()
                HStack { Spacer(); Button("Done") { showingLicenses = false }.keyboardShortcut(.defaultAction) }.padding(14)
            }
            .frame(width: 640, height: 520)
        }
    }

    /// Added by tools/build.sh when it embeds the Remastered engines.
    private static let licenses: String? = Bundle.main.url(forResource: "Licenses", withExtension: "md")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
}
