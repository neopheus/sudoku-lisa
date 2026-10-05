import SwiftUI

@main
struct SudokuLisaApp: App {
    @StateObject private var store = LisaStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .preferredColorScheme(store.settings.darkMode ? .dark : .light)
                .onAppear {
                    #if DEBUG
                    OctopusAssetExporter.exportIfRequested()
                    #endif
                }
        }
    }
}
