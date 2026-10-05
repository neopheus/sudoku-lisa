import SwiftUI

@main
struct SudokuLisaApp: App {
    @StateObject private var store = LisaStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--octopus-preview") {
                VStack {
                    Text("Lisa, le petit poulpe").font(.title.bold())
                    LisaMascot(size: 280, mood: .happy)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.cyan.opacity(0.15))
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
