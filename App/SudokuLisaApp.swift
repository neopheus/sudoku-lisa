import SwiftUI
import SudokuCore

@main
struct SudokuLisaApp: App {
    @UIApplicationDelegateAdaptor(LisaAppDelegate.self) private var appDelegate
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @StateObject private var store = LisaStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            #if DEBUG || LISA_PERFORMANCE_DIAGNOSTICS
            if ProcessInfo.processInfo.arguments.contains("--profile-rendering") {
                LisaRenderingProbeView()
            } else { appContent }
            #else
            appContent
            #endif
        }
    }

    @ViewBuilder private var appContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--poulpi-inspection-sequence") {
            PoulpiInspectionSequenceView()
        } else if ProcessInfo.processInfo.arguments.contains("--octopus-preview") {
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

    private var game: some View {
        GeometryReader { geometry in
            RootView().environmentObject(store)
                .environment(\.lisaVisibleBounds, geometry.frame(in: .global))
                .environment(\.locale, L10n.locale)
                .background(LisaDisplayObserver().allowsHitTesting(false).accessibilityHidden(true))
                .preferredColorScheme(store.settings.darkMode ? .dark : .light)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    LisaAudio.shared.configure(active: phase == .active, music: store.settings.music, musicTrack: LisaMusicTrack(rawValue: store.settings.musicTrack) ?? .marimbaPuzzle, world: store.activeScenery?.world)
                    store.sceneActivityChanged(isActive: phase == .active)
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active,
                          !ProcessInfo.processInfo.arguments.contains("--uitest-reset"),
                          ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
                          ProcessInfo.processInfo.environment["LISA_UI_TESTING"] != "1" else { return }
                    LisaWatchBridge.shared.update(completedGames: store.history.count, streak: store.streak, appearance: store.poulpiAppearance)
                    await LisaSocialNotifications.shared.refresh()
                }
                .onChange(of: store.history.count) { _, _ in LisaWatchBridge.shared.update(completedGames: store.history.count, streak: store.streak, appearance: store.poulpiAppearance) }
                .onChange(of: store.streak) { _, _ in LisaWatchBridge.shared.update(completedGames: store.history.count, streak: store.streak, appearance: store.poulpiAppearance) }
                .onChange(of: store.poulpiAppearance) { _, appearance in
                    LisaWatchBridge.shared.update(completedGames: store.history.count, streak: store.streak, appearance: appearance)
                }
                .onAppear {
                    #if DEBUG
                    OctopusAssetExporter.exportIfRequested()
                    #endif
                }
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
