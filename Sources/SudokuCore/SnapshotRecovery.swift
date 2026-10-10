import Foundation

/// File operations are synchronous so their callers can run the whole transaction
/// on one utility worker. There is one rotating, fully validated backup.
public enum SnapshotRecovery {
    public enum Failure: Error { case originalUnreadable, fileTooLarge, operationUnavailable }
    public static let maximumBytes = 64 * 1024 * 1024

    public static func readOriginal(at url: URL, maximumBytes: Int = maximumBytes) throws -> Data {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue <= maximumBytes else {
            throw Failure.fileTooLarge
        }
        let data = try Data(contentsOf: url)
        guard data.count <= maximumBytes else { throw Failure.fileTooLarge }
        return data
    }

    /// Copy bytes rather than re-encoding: malformed JSON and unknown fields survive.
    public static func exportOriginal(at source: URL, to directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("sudoku-lisa-original-\(UUID().uuidString).json")
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    public static func write(_ data: Data, to source: URL, backupURL: URL,
                             validate: (Data) throws -> Void) throws {
        guard data.count <= maximumBytes else { throw Failure.fileTooLarge }
        let previous: Data
        if FileManager.default.fileExists(atPath: source.path) {
            do {
                previous = try readOriginal(at: source)
                try validate(previous)
            } catch { throw Failure.originalUnreadable }
            // Recheck the original even for repeated captures: external corruption
            // must still close the persistence gate. Identical valid bytes need no
            // atomic replacement, and must not rotate away the older recovery copy.
            if previous == data, FileManager.default.fileExists(atPath: backupURL.path) { return }
        } else {
            previous = data
        }
        try validate(data)
        // If preserving the known good data fails, the current save is left intact.
        try previous.write(to: backupURL, options: .atomic)
        try data.write(to: source, options: .atomic)
    }

    /// Validate before any mutation; preserve the original before atomic replacement.
    /// The preserved file is deliberately never rotated away or deleted by the app.
    public static func restoreBackup<Snapshot>(at backupURL: URL, to source: URL,
                                                decode: (Data) throws -> Snapshot) throws
        -> (snapshot: Snapshot, preservedOriginalURL: URL?) {
        let bytes = try readOriginal(at: backupURL)
        let snapshot = try decode(bytes)
        var preserved: URL?
        if FileManager.default.fileExists(atPath: source.path) {
            let original = source.deletingLastPathComponent()
                .appendingPathComponent("sudoku-lisa-preserved-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: source, to: original)
            preserved = original
        }
        try bytes.write(to: source, options: .atomic)
        return (snapshot, preserved)
    }
}
