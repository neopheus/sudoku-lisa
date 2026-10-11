import XCTest
import SudokuCore
@testable import SudokuLisa

final class LisaInvitationRoutingTests: XCTestCase {
    @MainActor func testInvitationHandoffFlushesSoloWithoutReplacingIt() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("save.json")
        let store = LisaStore(saveURL: url)
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        store.session = GameSession(puzzle: Puzzle(givens: Array(repeating: 0, count: 81), solution: solution, difficulty: .easy, seed: 42))
        store.session?.enter(1, at: 0)
        store.session?.toggleNote(3, at: 1)
        store.clock.seconds = 57
        let ready = await store.prepareForBattleInvitation()
        XCTAssertTrue(ready)
        let restored = LisaStore(saveURL: url)
        XCTAssertEqual(restored.session?.values, store.session?.values)
        XCTAssertEqual(restored.session?.notes, store.session?.notes)
        XCTAssertEqual(restored.clock.seconds, 57)
        XCTAssertTrue(restored.session?.canUndo == true)
    }
    @MainActor func testInvitationCannotHideUnreadableSoloSave() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data("unreadable".utf8)
        try original.write(to: url)
        let store = LisaStore(saveURL: url)
        let ready = await store.prepareForBattleInvitation()
        XCTAssertFalse(ready)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
}
