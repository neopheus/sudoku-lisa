import Foundation
import Combine
import WatchConnectivity

import SudokuCore

@MainActor
final class WatchProgressStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot: WatchProgressSnapshot?
    private static let cacheKey = "lisa.watch.progress.v1"
    override init() {
        snapshot = UserDefaults.standard.dictionary(forKey: Self.cacheKey).flatMap(WatchProgressSnapshot.init(context:))
        super.init()
    }
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        receive(session.receivedApplicationContext)
        session.activate()
    }
    func refresh() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        receive(session.receivedApplicationContext)
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(["lisaRequestProgress": true], replyHandler: nil, errorHandler: nil)
    }
    private func receive(_ context: [String: Any]) {
        guard let incoming = WatchProgressSnapshot(context: context) else { return }
        apply(incoming)
    }
    private func apply(_ incoming: WatchProgressSnapshot) {
        if let snapshot, incoming.updatedAt < snapshot.updatedAt || incoming == snapshot { return }
        snapshot = incoming
        UserDefaults.standard.set(incoming.context, forKey: Self.cacheKey)
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let value = WatchProgressSnapshot(context: session.receivedApplicationContext)
        Task { @MainActor in
            if let value { self.apply(value) }
            self.refresh()
        }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.refresh() }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let value = WatchProgressSnapshot(context: message)
        Task { @MainActor in if let value { self.apply(value) } }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let value = WatchProgressSnapshot(context: applicationContext)
        Task { @MainActor in
            if let value { self.apply(value) }
        }
    }
}
