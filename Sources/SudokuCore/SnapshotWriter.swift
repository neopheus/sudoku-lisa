import Foundation

/// Captures are submitted in UI order. Only the most recent pending capture is
/// retained while an atomic write is in flight; encoding and I/O never run on UI.
@MainActor
public final class SnapshotWriter<Snapshot: Encodable & Sendable> {
    private var pending: Snapshot?
    private var drain: Task<Void, Never>?
    private let write: @Sendable (Snapshot) throws -> Void
    public var onResult: (@MainActor (Result<Void, Error>) -> Void)?

    public init(url: URL) {
        write = { snapshot in
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        }
    }

    /// Validation covers the full app payload, including migrations and contexts.
    /// An unreadable existing original is never replaced by an automatic write.
    public init(url: URL, backupURL: URL, validate: @escaping @Sendable (Data) throws -> Void) {
        write = { snapshot in
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(snapshot)
            try SnapshotRecovery.write(data, to: url, backupURL: backupURL, validate: validate)
        }
    }

    // Injectable I/O allows tests to block an in-flight write deterministically.
    init(write: @escaping @Sendable (Snapshot) throws -> Void) { self.write = write }

    public func submit(_ snapshot: Snapshot) {
        pending = snapshot
        guard drain == nil else { return }
        drain = Task {
            while let snapshot = pending {
                pending = nil
                let write = self.write
                let result = await Task.detached(priority: .utility) {
                    Result { try write(snapshot) }
                }.value
                // A superseded failure must not obscure the result of a retry.
                if pending == nil { onResult?(result) }
            }
            drain = nil
        }
    }

    /// Includes pending captures submitted while a write was in flight.
    public func flush() async { await drain?.value }
}
