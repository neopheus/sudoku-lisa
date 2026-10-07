import XCTest
import SudokuCore
@testable import SudokuLisa

final class LisaStoreTests: XCTestCase {
    private func temporarySave() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("sudoku-lisa-v1.json")
    }

    private func fixture() throws -> Data {
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var game = GameSession(puzzle: Puzzle(givens: Array(repeating: 0, count: 81), solution: solution, difficulty: .easy, seed: 42))
        game.elapsedSeconds = 123
        game.enter(1, at: 0)
        game.toggleNote(7, at: 4)
        let session = try JSONSerialization.jsonObject(with: JSONEncoder().encode(game))
        return try JSONSerialization.data(withJSONObject: [
            "session": session, "settings": ["sound": false, "music": false],
            "history": [["id": "00000000-0000-0000-0000-000000000001", "date": 800000000,
                         "difficulty": "easy", "seconds": 90, "mistakes": 0, "hints": 1, "mode": "Voyage"]],
            "completedDays": ["2026-10-06"], "eventWins": 5, "mode": "Quotidien",
            "activeDay": "2026-10-07", "eventMedals": ["2026-10-1"], "activeEvent": "2026-10-2",
            "activeTournament": "2026-W41"
        ])
    }

    @MainActor func testOpeningSaveDoesNotRewriteProgressBeforeRestorationFinishes() async throws {
        let url = try temporarySave()
        let original = try fixture()
        try original.write(to: url)
        let store = LisaStore(saveURL: url)
        await store.flushPendingSaves()
        XCTAssertEqual(try Data(contentsOf: url), original, "Opening the app must not modify its save")
        let reopened = LisaStore(saveURL: url)
        await reopened.flushPendingSaves()
        XCTAssertEqual(reopened.history.count, 1)
        XCTAssertEqual(reopened.completedDays, ["2026-10-06"])
        XCTAssertEqual(reopened.eventWins, 5)
        XCTAssertEqual(reopened.eventMedals, ["2026-10-1"])
        XCTAssertEqual(reopened.mode, "Quotidien")
        XCTAssertEqual(reopened.activeDay, "2026-10-07")
        XCTAssertEqual(reopened.activeEvent, "2026-10-2")
        XCTAssertEqual(reopened.activeTournament, "2026-W41")
        XCTAssertEqual(reopened.clock.seconds, 123)
        XCTAssertEqual(reopened.session?.values[0], 1)
        XCTAssertEqual(reopened.session?.notes[4], [7])
    }

    @MainActor func testUnreadableSaveCannotBeOverwrittenByAutomaticSaves() async throws {
        let url = try temporarySave()
        let original = Data("{\"history\": [incomplete but potentially recoverable".utf8)
        try original.write(to: url)
        let store = LisaStore(saveURL: url)
        XCTAssertNotNil(store.saveError)
        store.saveError = nil // Dismissing the alert must not unlock writes.
        store.settings.darkMode = true
        store.save()
        store.saveForBackground()
        await store.flushPendingSaves()
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    @MainActor func testFailedLoadPreventsStartingAnUnsavableGame() throws {
        let url = try temporarySave()
        let original = Data("invalid save".utf8)
        try original.write(to: url)
        let store = LisaStore(saveURL: url)
        store.saveError = nil
        store.start(.easy)
        XCTAssertFalse(store.isGenerating)
        XCTAssertNil(store.session)
        XCTAssertNotNil(store.saveError)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    @MainActor func testNormalChangesPersistAfterSuccessfulLoad() async throws {
        let url = try temporarySave()
        try fixture().write(to: url)
        let store = LisaStore(saveURL: url)
        store.settings.darkMode = true
        store.clock.seconds = 145
        store.session?.enter(2, at: 1)
        store.changed()
        await store.flushPendingSaves()
        let reopened = LisaStore(saveURL: url)
        await reopened.flushPendingSaves()
        XCTAssertTrue(reopened.settings.darkMode)
        XCTAssertEqual(reopened.history.count, 1)
        XCTAssertEqual(reopened.eventWins, 5)
        XCTAssertEqual(reopened.clock.seconds, 145)
        XCTAssertEqual(reopened.session?.values[1], 2)
    }

    @MainActor func testNewInstallationCanSave() async throws {
        let url = try temporarySave()
        let store = LisaStore(saveURL: url)
        store.settings.darkMode = true
        await store.flushPendingSaves()
        let reopened = LisaStore(saveURL: url)
        await reopened.flushPendingSaves()
        XCTAssertTrue(reopened.settings.darkMode)
        XCTAssertNil(reopened.saveError)
    }
}
