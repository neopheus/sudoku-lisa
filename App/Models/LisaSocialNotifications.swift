import UIKit
import UserNotifications
import CloudKit
import LisaInvitations
import SudokuCore

@MainActor final class LisaSocialNotifications: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = LisaSocialNotifications()
    @Published private(set) var permissionMessage: String?
    private var refreshTask: Task<Void, Never>?
    private let category = "LISA_INVITATIONS"
    func configure() {
        guard !ProcessInfo.processInfo.arguments.contains("--uitest-reset"), ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil, ProcessInfo.processInfo.environment["LISA_UI_TESTING"] != "1" else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([UNNotificationCategory(identifier: category, actions: [
            UNNotificationAction(identifier: "ACCEPT", title: L10n.text("Je suis disponible"), options: [.foreground]),
            UNNotificationAction(identifier: "DECLINE", title: L10n.text("Refuser"), options: [.foreground]),
            UNNotificationAction(identifier: "OPEN", title: L10n.text("Voir les invitations"), options: [.foreground])
        ], intentIdentifiers: [])])
        UIApplication.shared.registerForRemoteNotifications()
    }
    func requestAuthorization() async {
        do {
            let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            permissionMessage = allowed ? "Notifications activées." : "Notifications désactivées. Vous pouvez les autoriser dans les réglages de l’iPhone."
        } catch { permissionMessage = "Impossible d’activer les notifications. Réessayez." }
    }
    /// Pushes are change hints; only fresh, validated records can create actionable alerts.
    func refresh() async {
        if let task = refreshTask { await task.value; return }
        let task = Task { @MainActor in
            await self.refreshAlerts()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }
    private func refreshAlerts() async {
            let store = LisaInvitationStore.shared
            await store.refresh()
            guard store.errorMessage == nil, let user = store.currentUserID else { return }
            let defaultsKey = "lisa.notifiedInvitations.\(user)"
            var seen = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
            let pending = store.invitations.filter { $0.isIncoming && $0.status == .pending && $0.expiresAt > Date() }
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard store.currentUserID == user else { return }
            let active = UIApplication.shared.applicationState == .active
            if !active, settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                for invitation in pending where !seen.contains(invitation.id) {
                    guard store.currentUserID == user, invitation.expiresAt > Date() else { return }
                    let content = UNMutableNotificationContent()
                    content.title = L10n.text("Invitation Lisa")
                    content.body = L10n.text("%@ souhaite jouer avec vous", invitation.senderName)
                    content.categoryIdentifier = category
                    content.sound = .default
                    content.userInfo = ["lisaInvitationID": invitation.id, "lisaAccountID": user]
                    do {
                        try await center.add(UNNotificationRequest(identifier: "lisa.invite.\(invitation.id)", content: content, trigger: nil))
                        seen.append(invitation.id)
                    } catch { /* The next refresh may retry. */ }
                }
            } else if active {
                seen.append(contentsOf: pending.map(\.id).filter { !seen.contains($0) })
            }
            // Clear resolved alerts; cap both persisted dedupe state and delivered notifications.
            let live = Set(pending.map { "lisa.invite.\($0.id)" })
            let delivered = await center.deliveredNotifications()
            guard store.currentUserID == user else { return }
            center.removeDeliveredNotifications(withIdentifiers: delivered.map { $0.request.identifier }.filter { $0.hasPrefix("lisa.invite.") && !live.contains($0) })
            UserDefaults.standard.set(Array(seen.suffix(100)), forKey: defaultsKey)
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
        Task { @MainActor in await self.refresh() }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.content.userInfo["lisaInvitationID"] as? String
        let account = response.notification.request.content.userInfo["lisaAccountID"] as? String
        let action = response.actionIdentifier
        // Complete promptly; all actions launch the app and are revalidated from CloudKit.
        completionHandler()
        Task { @MainActor in
            await self.refresh()
            let store = LisaInvitationStore.shared
            if account == store.currentUserID, store.errorMessage == nil,
               let id, let invite = store.invitations.first(where: { $0.id == id && $0.isIncoming && $0.status == .pending && $0.expiresAt > Date() }) {
                if action == "ACCEPT" { await store.respond(to: invite, accepting: true) }
                else if action == "DECLINE" { await store.respond(to: invite, accepting: false) }
            }
            LisaSocialNavigation.shared.openInbox = true
        }
    }
}

@MainActor final class LisaAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        LisaSocialNotifications.shared.configure()
        if !ProcessInfo.processInfo.arguments.contains("--uitest-reset"),
           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
           ProcessInfo.processInfo.environment["LISA_UI_TESTING"] != "1" {
            // Register before a Watch message wakes a background-only phone launch.
            _ = LisaWatchBridge.shared
        }
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = LisaSceneDelegate.self
        return configuration
    }
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo), notification.subscriptionID == "lisa-invitations-v1" else { completionHandler(.noData); return }
        Task { @MainActor in
            let store = LisaInvitationStore.shared
            let before = store.invitations
            await LisaSocialNotifications.shared.refresh()
            completionHandler(store.errorMessage != nil ? .failed : (before == store.invitations ? .noData : .newData))
        }
    }
}

@MainActor final class LisaSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata { receive(metadata) }
    }
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) { receive(cloudKitShareMetadata) }
    private func receive(_ metadata: CKShare.Metadata) {
        Task { @MainActor in
            await LisaInvitationStore.shared.acceptShare(metadata)
            LisaSocialNavigation.shared.openInbox = true
        }
    }
}
