import XCTest
@testable import SudokuCore

final class PerformanceStateTests: XCTestCase {
    func testConflictsMatchPeerScanAcrossBoards() {
        for seed in 0..<100 {
            let values = (0..<81).map { ($0 * (seed + 3) + $0 / 9 + seed) % 10 }
            let expected = Set((0..<81).filter { index in
                values[index] != 0 && (0..<81).contains { other in
                    other != index && values[other] == values[index] &&
                    (index / 9 == other / 9 || index % 9 == other % 9 ||
                     (index / 27 == other / 27 && index % 9 / 3 == other % 9 / 3))
                }
            })
            XCTAssertEqual(BoardConflicts.indices(in: values), expected)
        }
        XCTAssertTrue(BoardConflicts.indices(in: Array(repeating: 0, count: 81)).isEmpty)
    }

    @MainActor func testWriterCoalescesAndFlushesLatestCapture() async {
        let began = expectation(description: "First write began")
        let release = DispatchSemaphore(value: 0)
        let writes = RecordedWrites()
        let writer = SnapshotWriter<Int>(write: { value in
            XCTAssertFalse(Thread.isMainThread)
            writes.append(value)
            if value == 1 {
                began.fulfill()
                XCTAssertEqual(release.wait(timeout: .now() + 10), .success)
            }
        })
        writer.submit(1)
        await fulfillment(of: [began], timeout: 5)
        writer.submit(2)
        writer.submit(3)
        release.signal()
        await writer.flush()
        XCTAssertEqual(writes.values, [1, 3])
        writer.submit(4)
        await writer.flush()
        XCTAssertEqual(writes.values, [1, 3, 4])
    }

    @MainActor func testWriterReportsFailureAndCanRetry() async {
        enum Failure: Error { case disk }
        let writer = SnapshotWriter<Int>(write: { if $0 == 1 { throw Failure.disk } })
        var outcomes: [Bool] = []
        writer.onResult = { result in
            switch result { case .success: outcomes.append(true); case .failure: outcomes.append(false) }
        }
        writer.submit(1)
        await writer.flush()
        writer.submit(2)
        await writer.flush()
        XCTAssertEqual(outcomes, [false, true])
    }

    @MainActor func testSupersededFailureDoesNotMaskSuccessfulLatestSave() async {
        enum Failure: Error { case disk }
        let began = expectation(description: "Failing write began")
        let release = DispatchSemaphore(value: 0)
        let writer = SnapshotWriter<Int>(write: { value in
            if value == 1 {
                began.fulfill()
                _ = release.wait(timeout: .now() + 10)
                throw Failure.disk
            }
        })
        var failures = 0
        var successes = 0
        writer.onResult = { result in
            switch result { case .success: successes += 1; case .failure: failures += 1 }
        }
        writer.submit(1)
        await fulfillment(of: [began], timeout: 5)
        writer.submit(2)
        release.signal()
        await writer.flush()
        XCTAssertEqual(failures, 0)
        XCTAssertEqual(successes, 1)
    }

    @MainActor func testAtomicSnapshotPreservesSessionAndTime() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("save.json")
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var game = GameSession(puzzle: Puzzle(givens: Array(repeating: 0, count: 81), solution: solution, difficulty: .easy, seed: 1))
        game.elapsedSeconds = 123
        game.toggleNote(4, at: 0)
        let writer = SnapshotWriter<GameSession>(url: url)
        writer.submit(game)
        await writer.flush()
        XCTAssertEqual(try JSONDecoder().decode(GameSession.self, from: Data(contentsOf: url)), game)
    }
}

private final class RecordedWrites: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Int] = []
    func append(_ value: Int) { lock.lock(); defer { lock.unlock() }; storage.append(value) }
    var values: [Int] { lock.lock(); defer { lock.unlock() }; return storage }
}
