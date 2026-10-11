import Foundation
import SudokuCore
import WatchConnectivity

@MainActor protocol LisaWatchTransport: AnyObject {
    var available: Bool { get }
    var reachable: Bool { get }
    func enqueue(_ context: [String: Any]) throws
    func sendImmediately(_ context: [String: Any])
}

@MainActor private final class SystemWatchTransport: LisaWatchTransport {
    var available: Bool {
        WCSession.isSupported() && WCSession.default.activationState == .activated
            && WCSession.default.isPaired && WCSession.default.isWatchAppInstalled
    }
    var reachable: Bool { WCSession.default.isReachable }
    func enqueue(_ context: [String: Any]) throws { try WCSession.default.updateApplicationContext(context) }
    func sendImmediately(_ context: [String: Any]) {
        WCSession.default.sendMessage(context, replyHandler: nil, errorHandler: nil)
    }
}

/// Background delivery survives disconnection; live messages update an open Watch.
@MainActor final class LisaWatchBridge: NSObject, WCSessionDelegate {
    static let shared = LisaWatchBridge()
    private let transport: any LisaWatchTransport
    private var snapshot: [String: Any] = [:]
    private var lastGames: Int?
    private var lastStreak: Int?
    private var lastAppearance: PoulpiAppearance?

    private override init() {
        transport = SystemWatchTransport()
        super.init()
        guard WCSession.isSupported() else { return }
        // A Watch request can wake the phone before its SwiftUI scene becomes active.
        snapshot = WCSession.default.applicationContext
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    init(transport: any LisaWatchTransport) {
        self.transport = transport
        super.init()
    }

    func update(completedGames: Int, streak: Int, appearance: PoulpiAppearance) {
        if completedGames != lastGames || streak != lastStreak || appearance != lastAppearance {
            lastGames = completedGames; lastStreak = streak; lastAppearance = appearance
            snapshot = ["lisaProgressVersion": 1, "completedGames": completedGames, "currentStreak": streak,
                        "updatedAt": Date().timeIntervalSince1970, "poulpiColor": appearance.color.rawValue,
                        "poulpiAccessory": appearance.accessory.rawValue]
        }
        // Retry on foreground activation even if the previous enqueue failed.
        send()
    }

    func send() {
        guard transport.available, WatchProgressSnapshot(context: snapshot) != nil else { return }
        // Either channel may succeed independently. The next lifecycle event retries.
        try? transport.enqueue(snapshot)
        if transport.reachable { transport.sendImmediately(snapshot) }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { Task { @MainActor in self.send() } }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) { Task { @MainActor in self.send() } }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) { Task { @MainActor in self.send() } }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message["lisaRequestProgress"] as? Bool == true else { return }
        Task { @MainActor in self.send() }
    }
}
