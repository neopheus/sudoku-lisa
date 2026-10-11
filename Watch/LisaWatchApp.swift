import SwiftUI
import LisaInvitations
import UserNotifications
import WatchKit
import CloudKit

@main
struct LisaWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchApplicationDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var progress = WatchProgressStore()
    @StateObject private var notifications = WatchNotificationDelegate()
    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(progress)
                .environmentObject(notifications)
                .task { notifications.install(); progress.activate() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { progress.refresh() }
                }
        }
    }
}

@MainActor
final class WatchNotificationDelegate: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var openInbox = false
    func install() { UNUserNotificationCenter.current().delegate = self }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run {
            self.openInbox = true
            Task { await LisaInvitationStore.shared.refresh() }
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        Task { @MainActor in await LisaInvitationStore.shared.refresh() }
        return [.banner, .sound]
    }
}

@MainActor
final class WatchApplicationDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WKApplication.shared().registerForRemoteNotifications()
    }
    func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> WKBackgroundFetchResult {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              notification.subscriptionID == "lisa-invitations-v1" else {
            return .noData
        }
        let store = LisaInvitationStore.shared
        let previousInvitations = store.invitations
        let previousRooms = store.rooms
        await store.refresh()
        if store.errorMessage != nil { return .failed }
        if previousInvitations != store.invitations || previousRooms != store.rooms { return .newData }
        return .noData
    }
}
