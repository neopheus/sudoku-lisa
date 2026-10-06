import SwiftUI
import SudokuCore

@main
struct SudokuLisaApp: App {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @StateObject private var store = LisaStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--octopus-preview") {
                if ProcessInfo.processInfo.arguments.contains("--octopus-motion-preview") {
                    OctopusMotionPreview()
                } else {
                    VStack {
                        Text("Lisa, le petit poulpe").font(.title.bold())
                        LisaMascot(size: 280, mood: .happy)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.cyan.opacity(0.15))
                }
            } else {
                game
            }
            #else
            game
            #endif
        }
    }

    private var game: some View {
            RootView().environmentObject(store)
                .environment(\.locale, L10n.locale)
                .preferredColorScheme(store.settings.darkMode ? .dark : .light)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    LisaAudio.shared.configure(active: phase == .active, music: store.settings.music)
                }
                .onAppear {
                    #if DEBUG
                    OctopusAssetExporter.exportIfRequested()
                    #endif
                }
    }
}

#if DEBUG
/// Repeatable large-scale inspection of the same rig used during play.
private struct OctopusMotionPreview: View {
    @State private var step = 0
    private let poses: [(String, LisaMascotMood)] = [
        ("Nage · poussée et glisse", .idle), ("Coucou !", .happy),
        ("Timide", .peek), ("Danse de joie", .celebrating),
        ("Étirement", .bow), ("Jonglage", .juggle)
    ]
    var body: some View {
        VStack {
            Text(poses[step].0).font(.title.bold()).frame(height: 42)
            LisaMascot(size: 280, mood: poses[step].1, reactionToken: step)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cyan.opacity(0.15))
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                step = (step + 1) % poses.count
            }
        }
    }
}
#endif
