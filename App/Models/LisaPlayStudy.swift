import Foundation
import Combine
import SudokuCore

@MainActor
final class LisaPlayStudy: ObservableObject {
    @Published private(set) var snapshot: PlayStudy
    @Published private(set) var storageUnavailable = false
    private let writer: SnapshotWriter<PlayStudy>
    private var exportURL: URL { FileManager.default.temporaryDirectory.appendingPathComponent("Lisa-play-study.json") }

    init(url: URL, existingPlayer: Bool) {
        self.snapshot = PlayStudy(existingPlayer: existingPlayer)
        self.writer = SnapshotWriter(url: url)
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 256_000 else { throw CocoaError(.fileReadCorruptFile) }
                snapshot = try JSONDecoder().decode(PlayStudy.self, from: Data(contentsOf: url))
            } catch { storageUnavailable = true }
        }
        writer.onResult = { [weak self] result in
            if case .failure = result { self?.storageUnavailable = true }
        }
    }

    var enabled: Bool {
        get { snapshot.enabled && !storageUnavailable }
        set {
            guard !storageUnavailable else { return }
            snapshot.setEnabled(newValue)
            writer.submit(snapshot)
        }
    }

    func record(_ event: PlayStudyEvent) {
        guard enabled else { return }
        snapshot.record(event)
        writer.submit(snapshot)
    }

    func flush() async { await writer.flush() }

    /// An explicit reset is the only operation allowed to replace an unreadable study.
    func reset() async {
        await writer.flush()
        let wasEnabled = enabled
        snapshot = PlayStudy(existingPlayer: true)
        snapshot.setEnabled(wasEnabled)
        storageUnavailable = false
        writer.submit(snapshot)
        await writer.flush()
        let exported = exportURL
        await Task.detached(priority: .utility) { try? FileManager.default.removeItem(at: exported) }.value
    }

    func export() async throws -> URL {
        guard !storageUnavailable else { throw CocoaError(.fileReadCorruptFile) }
        struct Report: Encodable, Sendable {
            let schemaVersion = 1
            let windowDays = PlayStudy.windowDays
            let elapsedDays: Int
            let existingPlayer: Bool
            let recordingEnabled: Bool
            let recordingInterrupted: Bool
            let appVersion: String
            let appBuild: String
            let days: [Int: [String: Int]]
        }
        let report = Report(elapsedDays: max(0, snapshot.dayOffset(at: Date())),
                            existingPlayer: snapshot.existingPlayer, recordingEnabled: enabled,
                            recordingInterrupted: snapshot.recordingInterrupted,
                            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
                            days: snapshot.days)
        let destination = exportURL
        return try await Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: destination, options: .atomic)
            return destination
        }.value
    }
}
