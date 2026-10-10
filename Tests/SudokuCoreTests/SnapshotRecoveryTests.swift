import XCTest
@testable import SudokuCore

final class SnapshotRecoveryTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    func testExportCopiesCorruptOriginalExactlyWithoutChangingIt() throws {
        let directory = try directory()
        let originalURL = directory.appendingPathComponent("save.json")
        let original = Data([0x00, 0xFF, 0x7B, 0x22, 0x0A])
        try original.write(to: originalURL)
        let export = try SnapshotRecovery.exportOriginal(at: originalURL, to: directory.appendingPathComponent("export"))
        XCTAssertNotEqual(export, originalURL)
        XCTAssertEqual(try Data(contentsOf: export), original)
        XCTAssertEqual(try Data(contentsOf: originalURL), original)
    }

    func testExportDoesNotReplaceAnEarlierExportAndMissingOriginalFails() throws {
        let directory = try directory()
        let source = directory.appendingPathComponent("save.json")
        let exportDirectory = directory.appendingPathComponent("exports")
        try Data("first original".utf8).write(to: source)
        let first = try SnapshotRecovery.exportOriginal(at: source, to: exportDirectory)
        try Data("corrected original".utf8).write(to: source)
        let second = try SnapshotRecovery.exportOriginal(at: source, to: exportDirectory)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try Data(contentsOf: first), Data("first original".utf8))
        XCTAssertEqual(try Data(contentsOf: second), Data("corrected original".utf8))
        try FileManager.default.removeItem(at: source)
        XCTAssertThrowsError(try SnapshotRecovery.exportOriginal(at: source, to: exportDirectory))
        XCTAssertEqual(try Data(contentsOf: first), Data("first original".utf8))
    }

    func testReadRejectsMissingFileAndTooLargeFileWithoutMutation() throws {
        let directory = try directory()
        let url = directory.appendingPathComponent("save.json")
        XCTAssertThrowsError(try SnapshotRecovery.readOriginal(at: url))
        let original = Data(repeating: 0x42, count: 5)
        try original.write(to: url)
        XCTAssertThrowsError(try SnapshotRecovery.readOriginal(at: url, maximumBytes: 4))
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertEqual(try SnapshotRecovery.readOriginal(at: url, maximumBytes: 5), original)
    }

    private static func decode(_ data: Data) throws -> Int {
        try JSONDecoder().decode(Int.self, from: data)
    }

    func testSafeWriteKeepsOneValidatedPreviousSnapshot() throws {
        let directory = try directory()
        let source = directory.appendingPathComponent("save.json")
        let backup = directory.appendingPathComponent("backup.json")
        try SnapshotRecovery.write(Data("1".utf8), to: source, backupURL: backup, validate: { _ = try Self.decode($0) })
        XCTAssertEqual(try Data(contentsOf: backup), Data("1".utf8))
        try SnapshotRecovery.write(Data("2".utf8), to: source, backupURL: backup, validate: { _ = try Self.decode($0) })
        try SnapshotRecovery.write(Data("3".utf8), to: source, backupURL: backup, validate: { _ = try Self.decode($0) })
        XCTAssertEqual(try Data(contentsOf: source), Data("3".utf8))
        XCTAssertEqual(try Data(contentsOf: backup), Data("2".utf8))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 2)
    }

    func testSafeWriteNeverOverwritesUnreadableOriginalOrGoodBackup() throws {
        let directory = try directory()
        let source = directory.appendingPathComponent("save.json")
        let backup = directory.appendingPathComponent("backup.json")
        let broken = Data("{partial original".utf8)
        try broken.write(to: source)
        try Data("42".utf8).write(to: backup)
        XCTAssertThrowsError(try SnapshotRecovery.write(Data("7".utf8), to: source, backupURL: backup, validate: { _ = try Self.decode($0) }))
        XCTAssertEqual(try Data(contentsOf: source), broken)
        XCTAssertEqual(try Data(contentsOf: backup), Data("42".utf8))
    }

    func testIdenticalValidSnapshotDoesNotReplaceFilesOrRotateBackup() throws {
        let directory = try directory()
        let source = directory.appendingPathComponent("save.json")
        let backup = directory.appendingPathComponent("backup.json")
        var validations = 0
        let validate: (Data) throws -> Void = {
            validations += 1
            _ = try Self.decode($0)
        }
        try SnapshotRecovery.write(Data("1".utf8), to: source, backupURL: backup, validate: validate)
        try SnapshotRecovery.write(Data("2".utf8), to: source, backupURL: backup, validate: validate)
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: source.path)
        let backupAttributes = try FileManager.default.attributesOfItem(atPath: backup.path)
        validations = 0
        try SnapshotRecovery.write(Data("2".utf8), to: source, backupURL: backup, validate: validate)
        XCTAssertEqual(validations, 1, "The unchanged original is validated once, without decoding it again")
        XCTAssertEqual(try Data(contentsOf: backup), Data("1".utf8))
        for key in [FileAttributeKey.systemFileNumber, .modificationDate] {
            XCTAssertEqual(originalAttributes[key] as? NSObject,
                           try FileManager.default.attributesOfItem(atPath: source.path)[key] as? NSObject)
            XCTAssertEqual(backupAttributes[key] as? NSObject,
                           try FileManager.default.attributesOfItem(atPath: backup.path)[key] as? NSObject)
        }
        try SnapshotRecovery.write(Data("3".utf8), to: source, backupURL: backup, validate: validate)
        XCTAssertEqual(try Data(contentsOf: source), Data("3".utf8))
        XCTAssertEqual(try Data(contentsOf: backup), Data("2".utf8))
    }

    @MainActor func testRepeatedWriterSnapshotStillDetectsOriginalCorruption() async throws {
        let directory = try directory()
        let source = directory.appendingPathComponent("save.json")
        let backup = directory.appendingPathComponent("backup.json")
        let writer = SnapshotWriter<Int>(url: source, backupURL: backup) { _ = try Self.decode($0) }
        writer.submit(7)
        await writer.flush()
        let corrupt = Data("{partial".utf8)
        try corrupt.write(to: source)
        var blocked = false
        writer.onResult = { result in
            if case let .failure(error) = result,
               case SnapshotRecovery.Failure.originalUnreadable = error { blocked = true }
        }
        writer.submit(7)
        await writer.flush()
        XCTAssertTrue(blocked)
        XCTAssertEqual(try Data(contentsOf: source), corrupt)
        XCTAssertEqual(try Data(contentsOf: backup), Data("7".utf8))
    }

    func testIdenticalSnapshotRecreatesMissingBackupAndInvalidCandidateCannotMutateFiles() throws {
        let directory = try directory()
        let source = directory.appendingPathComponent("save.json")
        let backup = directory.appendingPathComponent("backup.json")
        let validate: (Data) throws -> Void = { _ = try Self.decode($0) }
        try Data("7".utf8).write(to: source)
        try SnapshotRecovery.write(Data("7".utf8), to: source, backupURL: backup, validate: validate)
        XCTAssertEqual(try Data(contentsOf: backup), Data("7".utf8))
        XCTAssertThrowsError(try SnapshotRecovery.write(Data("invalid".utf8), to: source,
                                                       backupURL: backup, validate: validate))
        XCTAssertEqual(try Data(contentsOf: source), Data("7".utf8))
        XCTAssertEqual(try Data(contentsOf: backup), Data("7".utf8))
    }

    func testRestoringValidatedBackupPreservesExactOriginalAndBackup() throws {
        let directory = try directory()
        let source = directory.appendingPathComponent("save.json")
        let backup = directory.appendingPathComponent("backup.json")
        let broken = Data([0xFF, 0x7B, 0x00])
        try broken.write(to: source)
        try Data("42".utf8).write(to: backup)
        let restored = try SnapshotRecovery.restoreBackup(at: backup, to: source, decode: Self.decode)
        XCTAssertEqual(restored.snapshot, 42)
        let preserved = try XCTUnwrap(restored.preservedOriginalURL)
        XCTAssertNotEqual(preserved, source)
        XCTAssertEqual(try Data(contentsOf: preserved), broken)
        XCTAssertEqual(try Data(contentsOf: source), Data("42".utf8))
        XCTAssertEqual(try Data(contentsOf: backup), Data("42".utf8))
    }

    func testInvalidOrMissingBackupCannotMutateOriginal() throws {
        let directory = try directory()
        let source = directory.appendingPathComponent("save.json")
        let backup = directory.appendingPathComponent("backup.json")
        let broken = Data("recoverable original".utf8)
        try broken.write(to: source)
        XCTAssertThrowsError(try SnapshotRecovery.restoreBackup(at: backup, to: source, decode: Self.decode))
        try Data("bad backup".utf8).write(to: backup)
        XCTAssertThrowsError(try SnapshotRecovery.restoreBackup(at: backup, to: source, decode: Self.decode))
        XCTAssertEqual(try Data(contentsOf: source), broken)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 2)
    }

    func testFailedOriginalPreservationAbortsRestoration() throws {
        let directory = try directory()
        let source = directory.appendingPathComponent("save.json")
        let backup = directory.appendingPathComponent("backup.json")
        let original = Data("original".utf8)
        try original.write(to: source)
        try Data("42".utf8).write(to: backup)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path) }
        XCTAssertThrowsError(try SnapshotRecovery.restoreBackup(at: backup, to: source, decode: Self.decode))
        XCTAssertEqual(try Data(contentsOf: source), original)
    }

    @MainActor func testWriterRotatesBackupOffMainAndReportsCorruptSourceWithoutOverwriting() async throws {
        let directory = try directory()
        let source = directory.appendingPathComponent("save.json")
        let backup = directory.appendingPathComponent("backup.json")
        let writer = SnapshotWriter<Int>(url: source, backupURL: backup) { data in
            XCTAssertFalse(Thread.isMainThread)
            _ = try Self.decode(data)
        }
        writer.submit(1)
        await writer.flush()
        writer.submit(2)
        await writer.flush()
        XCTAssertEqual(try Data(contentsOf: backup), Data("1".utf8))
        let corrupt = Data("{partial".utf8)
        try corrupt.write(to: source)
        var blocked = false
        writer.onResult = { result in
            if case let .failure(error) = result,
               case SnapshotRecovery.Failure.originalUnreadable = error { blocked = true }
        }
        writer.submit(3)
        await writer.flush()
        XCTAssertTrue(blocked)
        XCTAssertEqual(try Data(contentsOf: source), corrupt)
        XCTAssertEqual(try Data(contentsOf: backup), Data("1".utf8))
    }
}
