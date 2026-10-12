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

    @MainActor func testRetryRestoresWholeCorrectedSaveWithoutRewritingIt() async throws {
        let url = try temporarySave()
        try Data("broken".utf8).write(to: url)
        let store = LisaStore(saveURL: url)
        XCTAssertTrue(store.needsSaveRecovery)
        store.settings.darkMode = true
        let corrected = try fixture()
        try corrected.write(to: url)
        let retried = await store.retryLoadingSave()
        XCTAssertTrue(retried)
        await store.flushPendingSaves()
        XCTAssertFalse(store.needsSaveRecovery)
        XCTAssertNil(store.saveError)
        XCTAssertEqual(try Data(contentsOf: url), corrected)
        XCTAssertFalse(store.settings.darkMode)
        XCTAssertEqual(store.history.count, 1)
        XCTAssertEqual(store.completedDays, ["2026-10-06"])
        XCTAssertEqual(store.eventWins, 5)
        XCTAssertEqual(store.eventMedals, ["2026-10-1"])
        XCTAssertEqual(store.activeEvent, "2026-10-2")
        XCTAssertEqual(store.activeTournament, "2026-W41")
        XCTAssertEqual(store.mode, "Quotidien")
        XCTAssertEqual(store.clock.seconds, 123)
        XCTAssertEqual(store.session?.notes[4], [7])
        store.session?.undo()
        XCTAssertEqual(store.session?.notes[4], [])
        store.settings.darkMode = true
        await store.flushPendingSaves()
        XCTAssertTrue(LisaStore(saveURL: url).settings.darkMode)
    }

    @MainActor func testFailedOrMissingRetryKeepsPersistenceClosed() async throws {
        let url = try temporarySave()
        let original = Data("unreadable original".utf8)
        try original.write(to: url)
        let store = LisaStore(saveURL: url)
        let retried = await store.retryLoadingSave()
        XCTAssertFalse(retried)
        XCTAssertTrue(store.needsSaveRecovery)
        store.settings.darkMode = true
        await store.flushPendingSaves()
        XCTAssertEqual(try Data(contentsOf: url), original)
        try FileManager.default.removeItem(at: url)
        let retriedMissing = await store.retryLoadingSave()
        XCTAssertFalse(retriedMissing)
        store.save()
        await store.flushPendingSaves()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        store.start(.easy)
        XCTAssertFalse(store.isGenerating)
    }

    @MainActor func testRecoveryExportPreservesRawCorruptionAndBlockedPersistence() async throws {
        let url = try temporarySave()
        let original = Data([0xFF, 0x00, 0x7B, 0x22])
        try original.write(to: url)
        let store = LisaStore(saveURL: url)
        let exported = try await store.exportOriginalSave()
        addTeardownBlock { try? FileManager.default.removeItem(at: exported.deletingLastPathComponent()) }
        XCTAssertEqual(try Data(contentsOf: exported), original)
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertTrue(store.needsSaveRecovery)
        store.save()
        await store.flushPendingSaves()
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    @MainActor func testRestoreBackupRecoversMigrationAndQuarantinesExactOriginal() async throws {
        let url = try temporarySave()
        let backup = url.appendingPathExtension("backup")
        let original = Data("partial original".utf8)
        try original.write(to: url)
        let valid = try fixture()
        try valid.write(to: backup)
        let store = LisaStore(saveURL: url)
        await store.refreshRecoveryBackup()
        XCTAssertTrue(store.canRestoreBackup)
        let restored = await store.restoreBackup()
        XCTAssertTrue(restored)
        XCTAssertFalse(store.needsSaveRecovery)
        XCTAssertEqual(store.history.count, 1)
        XCTAssertEqual(store.clock.seconds, 123)
        XCTAssertEqual(store.session?.notes[4], [7])
        let preserved = try XCTUnwrap(store.preservedSaveURL)
        XCTAssertEqual(try Data(contentsOf: preserved), original)
        XCTAssertEqual(try Data(contentsOf: url), valid)
        XCTAssertEqual(try Data(contentsOf: backup), valid)
        let export = try await store.exportOriginalSave()
        addTeardownBlock { try? FileManager.default.removeItem(at: export.deletingLastPathComponent()) }
        XCTAssertEqual(try Data(contentsOf: export), original)
        store.settings.darkMode = true
        await store.flushPendingSaves()
        XCTAssertTrue(LisaStore(saveURL: url).settings.darkMode)
        XCTAssertEqual(try Data(contentsOf: preserved), original)
    }

    @MainActor func testInvalidBackupCannotUnlockRecoveryOrOverwriteOriginal() async throws {
        let url = try temporarySave()
        let original = Data("original".utf8)
        try original.write(to: url)
        var invalid = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture()) as? [String: Any])
        invalid["savedGames"] = ["Libre": ["id": UUID().uuidString, "mode": "Quotidien",
                                             "session": invalid["session"]!, "recorded": false]]
        try JSONSerialization.data(withJSONObject: invalid).write(to: url.appendingPathExtension("backup"))
        let store = LisaStore(saveURL: url)
        await store.refreshRecoveryBackup()
        XCTAssertFalse(store.canRestoreBackup)
        let restored = await store.restoreBackup()
        XCTAssertFalse(restored)
        XCTAssertTrue(store.needsSaveRecovery)
        store.save()
        await store.flushPendingSaves()
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    @MainActor func testLiveFileCorruptionClosesPersistenceAndKeepsHealthyBackup() async throws {
        let url = try temporarySave()
        let valid = try fixture()
        try valid.write(to: url)
        let store = LisaStore(saveURL: url)
        store.settings.darkMode = true
        await store.flushPendingSaves()
        let backup = url.appendingPathExtension("backup")
        XCTAssertEqual(try Data(contentsOf: backup), valid)
        let corrupted = Data("{partially written elsewhere".utf8)
        try corrupted.write(to: url)
        store.settings.darkMode = false
        await store.flushPendingSaves()
        XCTAssertTrue(store.needsSaveRecovery)
        XCTAssertEqual(try Data(contentsOf: backup), valid)
        XCTAssertEqual(try Data(contentsOf: url), corrupted)
        XCTAssertFalse(store.resumeLastGame(), "An unreadable save must not resume an unsavable board")
        store.start(.easy)
        XCTAssertFalse(store.isGenerating)
        store.save()
        await store.flushPendingSaves()
        XCTAssertEqual(try Data(contentsOf: url), corrupted)
    }

    @MainActor func testCorruptionDuringGenerationCannotReplaceRestoredBackupWithStaleBoard() async throws {
        let url = try temporarySave()
        try fixture().write(to: url)
        let began = expectation(description: "Generation began")
        let finished = expectation(description: "Cancelled worker eventually returned")
        let release = DispatchSemaphore(value: 0)
        let store = LisaStore(saveURL: url, generator: { difficulty, seed in
            began.fulfill()
            _ = release.wait(timeout: .now() + 5)
            defer { finished.fulfill() }
            // Ignore cancellation deliberately: the store must reject this stale result.
            return Self.puzzle(difficulty, seed)
        })
        store.save()
        await store.flushPendingSaves()
        let previous = try XCTUnwrap(store.session)
        store.start(.hard, mode: "Quotidien", seedOverride: 999)
        await fulfillment(of: [began], timeout: 3)
        await store.flushPendingSaves()
        try Data("{corrupt original".utf8).write(to: url)
        store.save()
        await store.flushPendingSaves()
        XCTAssertTrue(store.needsSaveRecovery)
        XCTAssertFalse(store.isGenerating)
        let restored = await store.restoreBackup()
        XCTAssertTrue(restored)
        release.signal()
        await fulfillment(of: [finished], timeout: 3)
        try await Task.sleep(for: .milliseconds(50))
        await store.flushPendingSaves()
        XCTAssertEqual(store.session, previous)
        XCTAssertEqual(store.mode, "Quotidien")
        XCTAssertEqual(LisaStore(saveURL: url).session, previous)
        XCTAssertFalse(store.showGame)
    }

    @MainActor func testLegacyEquippedStarMigratesWithoutRewritingAndPersistsWithColor() async throws {
        let url = try temporarySave()
        var data = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture()) as? [String: Any])
        var settings = try XCTUnwrap(data["settings"] as? [String: Any])
        settings["poulpiStarEquipped"] = true
        data["settings"] = settings
        let original = try JSONSerialization.data(withJSONObject: data)
        try original.write(to: url)
        let store = LisaStore(saveURL: url)
        XCTAssertEqual(store.poulpiAppearance, PoulpiAppearance(accessory: .star))
        await store.flushPendingSaves()
        XCTAssertEqual(try Data(contentsOf: url), original)
        store.selectPoulpiColor(.mint)
        await store.flushPendingSaves()
        let reopened = LisaStore(saveURL: url)
        XCTAssertEqual(reopened.poulpiAppearance, PoulpiAppearance(color: .mint, accessory: .star))
        XCTAssertTrue(reopened.settings.poulpiStarEquipped)
        XCTAssertEqual(reopened.session?.notes[4], [7])
        XCTAssertEqual(reopened.clock.seconds, 123)
    }

    @MainActor func testBattleRewardsPersistAndOnlyOneUnlockedAccessoryCanBeEquipped() async throws {
        let url = try temporarySave()
        let store = LisaStore(saveURL: url)
        store.equipPoulpiAccessory(.crown)
        XCTAssertEqual(store.poulpiAppearance.accessory, .none)
        let round = UUID()
        XCTAssertTrue(store.recordBattleResult(roundID: round, won: false))
        XCTAssertFalse(store.recordBattleResult(roundID: round, won: true))
        store.equipPoulpiAccessory(.headband)
        store.selectPoulpiColor(.coral)
        await store.flushPendingSaves()
        let reopened = LisaStore(saveURL: url)
        XCTAssertEqual(reopened.battleRewards.finishedRounds, 1)
        XCTAssertEqual(reopened.battleRewards.wins, 0)
        XCTAssertFalse(reopened.recordBattleResult(roundID: round, won: true))
        XCTAssertEqual(reopened.poulpiAppearance, PoulpiAppearance(color: .coral, accessory: .headband))
        for _ in 0..<5 { reopened.recordBattleResult(roundID: UUID(), won: true) }
        reopened.equipPoulpiAccessory(.crown)
        XCTAssertEqual(reopened.poulpiAppearance.accessory, .crown)
        XCTAssertFalse(reopened.settings.poulpiStarEquipped)
        reopened.equipPoulpiAccessory(.none)
        XCTAssertEqual(reopened.poulpiAppearance.accessory, .none)
        await reopened.flushPendingSaves()
        let final = LisaStore(saveURL: url)
        XCTAssertTrue(final.isPoulpiAccessoryUnlocked(.crown))
        XCTAssertEqual(final.battleRewards.wins, 5)
    }

    @MainActor func testCustomizationAndBattleCannotOverwriteUnreadableSave() async throws {
        let url = try temporarySave()
        let original = Data("unreadable progression".utf8)
        try original.write(to: url)
        let store = LisaStore(saveURL: url)
        store.selectPoulpiColor(.gold)
        store.equipPoulpiAccessory(.none)
        XCTAssertFalse(store.recordBattleResult(roundID: UUID(), won: true))
        await store.flushPendingSaves()
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertEqual(store.battleRewards.finishedRounds, 0)
    }

    private static func puzzle(_ difficulty: Difficulty, _ seed: UInt64) -> Puzzle {
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var givens = solution
        for index in [0, 40, 80] { givens[index] = 0 }
        return Puzzle(givens: givens, solution: solution, difficulty: difficulty, seed: seed)
    }

    @MainActor private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(condition(), "Timed out waiting for store generation")
    }

    @MainActor func testMigrationAndPerModeRoundTripPreserveNotesUndoClockAndContext() async throws {
        let url = try temporarySave()
        try fixture().write(to: url)
        let store = LisaStore(saveURL: url, generator: Self.puzzle)
        XCTAssertFalse(store.settings.numberFirst)
        XCTAssertTrue(store.hasPoulpiStarReward, "Existing travel wins unlock the souvenir")
        store.clock.seconds = 161
        store.settings.numberFirst = true
        var daily = try XCTUnwrap(store.session)
        daily.elapsedSeconds = 161
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-07T12:00:00Z"))
        let otherDate = date.addingTimeInterval(86400)
        XCTAssertTrue(store.hasSavedGame(mode: "Quotidien", date: date))
        XCTAssertFalse(store.hasSavedGame(mode: "Quotidien", date: otherDate))

        store.start(.hard, mode: "Libre", seedOverride: 101)
        try await waitUntil { !store.isGenerating }
        store.session?.toggleNote(2, at: 0)
        store.clock.seconds = 17
        store.changed()
        var free = try XCTUnwrap(store.session)
        free.elapsedSeconds = 17
        XCTAssertTrue(store.resume(mode: "Quotidien", date: date))
        XCTAssertEqual(store.session, daily)
        XCTAssertEqual(store.activeDay, "2026-10-07")
        XCTAssertEqual(store.clock.seconds, 161)
        XCTAssertFalse(store.resume(mode: "Quotidien", date: otherDate))
        store.save()
        await store.flushPendingSaves()

        let reopened = LisaStore(saveURL: url)
        XCTAssertEqual(reopened.session, daily)
        XCTAssertTrue(reopened.settings.numberFirst)
        XCTAssertTrue(reopened.resume(mode: "Libre"))
        XCTAssertEqual(reopened.session, free)
        reopened.session?.undo()
        XCTAssertEqual(reopened.session?.notes[0], [])
        XCTAssertTrue(reopened.resume(mode: "Quotidien", date: date))
        reopened.session?.undo()
        XCTAssertEqual(reopened.session?.notes[4], [], "Legacy undo survives the migration and round trip")
    }

    @MainActor func testCancelledAndFailedGenerationKeepExactPreviousSessionAndContext() async throws {
        let url = try temporarySave()
        try fixture().write(to: url)
        let store = LisaStore(saveURL: url, generator: { difficulty, seed in
            // Deliberately ignore cancellation to verify stale result protection too.
            Thread.sleep(forTimeInterval: 0.08)
            return Self.puzzle(difficulty, seed)
        })
        store.clock.seconds = 178
        var original = try XCTUnwrap(store.session)
        original.elapsedSeconds = 178
        store.start(.expert, mode: "Tournoi", tournamentID: "new-week")
        XCTAssertEqual(store.mode, "Quotidien", "Generation must not mutate live context")
        store.cancelGeneration()
        try await Task.sleep(for: .milliseconds(180))
        XCTAssertEqual(store.mode, "Quotidien")
        XCTAssertEqual(store.activeDay, "2026-10-07")
        XCTAssertEqual(store.session?.puzzle, original.puzzle)
        XCTAssertEqual(store.clock.seconds, 178)
        XCTAssertFalse(store.showGame)
        store.save()
        await store.flushPendingSaves()
        XCTAssertEqual(LisaStore(saveURL: url).session, original)

        let failing = LisaStore(saveURL: url, generator: { _, _ in throw CancellationError() })
        failing.start(.easy, mode: "Événement", eventID: "2026-11-1")
        try await waitUntil { !failing.isGenerating }
        XCTAssertNotNil(failing.generationError)
        XCTAssertEqual(failing.session, original)
        XCTAssertEqual(failing.mode, "Quotidien")
    }

    @MainActor func testRapidStartsNeverRunConcurrentGeneratorsAndOnlyLatestCommits() async throws {
        let probe = GenerationProbe()
        let store = LisaStore(saveURL: try temporarySave(), generator: { difficulty, seed in
            probe.enter()
            defer { probe.exit() }
            Thread.sleep(forTimeInterval: 0.08)
            try Task.checkCancellation()
            return Self.puzzle(difficulty, seed)
        })
        store.start(.easy, seedOverride: 1)
        try await waitUntil { probe.started > 0 }
        store.start(.hard, mode: "Voyage", seedOverride: 2)
        store.start(.medium, mode: "Événement", seedOverride: 3, eventID: "2026-10-1")
        try await waitUntil { !store.isGenerating }
        XCTAssertEqual(probe.maximumActive, 1)
        XCTAssertEqual(store.session?.puzzle.seed, 3)
        XCTAssertEqual(store.mode, "Événement")
        XCTAssertEqual(store.activeEvent, "2026-10-1")
        XCTAssertFalse(store.hasSavedGame(mode: "Voyage"))
        // Finish the asynchronous save before the teardown removes its directory.
        await store.flushPendingSaves()
    }

    @MainActor func testVictoryRewardRecordedOnceAndEquipmentPersists() async throws {
        let url = try temporarySave()
        let store = LisaStore(saveURL: url, generator: Self.puzzle)
        store.settings.sound = false
        store.settings.haptics = false
        store.eventWins = 4
        store.startJourney()
        try await waitUntil { !store.isGenerating }
        for index in [0, 40, 80] { store.session?.enter(Self.puzzle(.easy, 1).solution[index], at: index) }
        store.changed()
        store.changed()
        XCTAssertEqual(store.eventWins, 5)
        XCTAssertEqual(store.history.count, 1)
        XCTAssertTrue(store.hasPoulpiStarReward)
        XCTAssertEqual(store.victoryContinuationTitle, L10n.text("Prochaine étape"))
        store.equipPoulpiStar(true)
        await store.flushPendingSaves()
        let reopened = LisaStore(saveURL: url, generator: Self.puzzle)
        reopened.changed()
        XCTAssertEqual(reopened.eventWins, 5)
        XCTAssertEqual(reopened.history.count, 1)
        XCTAssertTrue(reopened.poulpiStarEquipped)
        reopened.continueAfterVictory()
        try await waitUntil { !reopened.isGenerating }
        XCTAssertEqual(reopened.mode, "Voyage")
        XCTAssertFalse(try XCTUnwrap(reopened.session).isComplete)
        XCTAssertEqual(reopened.savedGame(mode: "Voyage")?.journeyStage, 6)
    }

    @MainActor func testDailyVictoryReturnsHomeAndCannotGiveRepeatedDayRewards() async throws {
        let url = try temporarySave()
        let store = LisaStore(saveURL: url, generator: Self.puzzle)
        store.settings.sound = false
        store.settings.haptics = false
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-07T12:00:00Z"))
        store.start(.medium, mode: "Quotidien", date: date)
        try await waitUntil { !store.isGenerating }
        for index in [0, 40, 80] { store.session?.enter(Self.puzzle(.easy, 1).solution[index], at: index) }
        store.changed()
        store.continueAfterVictory()
        store.changed()
        XCTAssertEqual(store.completedDays, ["2026-10-07"])
        XCTAssertEqual(store.history.count, 1)
        XCTAssertEqual(store.eventWins, 0)
        XCTAssertFalse(store.showGame)
        XCTAssertFalse(store.isGenerating)
    }


    @MainActor func testAllFiveModesResumeTheirOwnIdentityAfterReload() async throws {
        let url = try temporarySave()
        let store = LisaStore(saveURL: url, generator: Self.puzzle)
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-07T12:00:00Z"))
        let modes = ["Libre", "Quotidien", "Voyage", "Événement", "Tournoi"]
        for (index, mode) in modes.enumerated() {
            store.start(.medium, mode: mode, date: mode == "Quotidien" ? date : nil,
                        seedOverride: UInt64(index + 1), eventID: mode == "Événement" ? "2026-09-3" : nil,
                        tournamentID: mode == "Tournoi" ? "2026-W40" : nil)
            try await waitUntil { !store.isGenerating }
            store.session?.toggleNote(index + 1, at: 0)
            store.clock.seconds = (index + 1) * 30
            store.changed()
        }
        await store.flushPendingSaves()
        let reopened = LisaStore(saveURL: url)
        XCTAssertEqual(reopened.savedGames.count, 5)
        for (index, mode) in modes.enumerated() {
            XCTAssertTrue(reopened.resume(mode: mode))
            XCTAssertEqual(reopened.session?.puzzle.seed, UInt64(index + 1))
            XCTAssertEqual(reopened.session?.notes[0], [index + 1])
            XCTAssertEqual(reopened.clock.seconds, (index + 1) * 30)
            XCTAssertEqual(reopened.activeDay, mode == "Quotidien" ? "2026-10-07" : nil)
            XCTAssertEqual(reopened.activeEvent, mode == "Événement" ? "2026-09-3" : nil)
            XCTAssertEqual(reopened.activeTournament, mode == "Tournoi" ? "2026-W40" : nil)
        }
    }

    @MainActor func testSeasonContinuationUsesSavedMonthAndTravelStopsAt25() async throws {
        let store = LisaStore(saveURL: try temporarySave(), generator: Self.puzzle)
        store.settings.sound = false
        store.settings.haptics = false
        store.start(.medium, mode: "Événement", eventID: "2026-09-1")
        try await waitUntil { !store.isGenerating }
        for index in [0, 40, 80] { store.session?.enter(Self.puzzle(.easy, 1).solution[index], at: index) }
        store.changed()
        store.continueAfterVictory()
        try await waitUntil { !store.isGenerating }
        XCTAssertEqual(store.activeEvent, "2026-09-2", "The old seasonal session retains its own month")
        XCTAssertEqual(store.eventMedals, ["2026-09-1"])

        store.eventWins = 24
        store.startJourney()
        try await waitUntil { !store.isGenerating }
        for index in [0, 40, 80] { store.session?.enter(Self.puzzle(.easy, 1).solution[index], at: index) }
        store.changed()
        store.continueAfterVictory()
        XCTAssertEqual(store.eventWins, 25)
        XCTAssertFalse(store.isGenerating)
        XCTAssertFalse(store.showGame)
    }

    @MainActor func testBackgroundCancellationPreservesActiveBoard() async throws {
        let url = try temporarySave()
        try fixture().write(to: url)
        let store = LisaStore(saveURL: url, generator: { difficulty, seed in
            Thread.sleep(forTimeInterval: 0.08)
            return Self.puzzle(difficulty, seed)
        })
        store.clock.seconds = 210
        store.start(.hard, mode: "Libre")
        store.saveForBackground()
        await store.flushPendingSaves()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(store.isGenerating)
        XCTAssertEqual(store.mode, "Quotidien")
        XCTAssertEqual(LisaStore(saveURL: url).clock.seconds, 210)
    }

    @MainActor func testInactiveThenBackgroundSavesOnceUntilActiveAgain() async throws {
        let url = try temporarySave()
        try fixture().write(to: url)
        let store = LisaStore(saveURL: url)
        store.clock.seconds = 211
        store.sceneActivityChanged(isActive: false)
        await store.flushPendingSaves()
        XCTAssertEqual(LisaStore(saveURL: url).clock.seconds, 211)
        // Model a second phase notification after the first flush completed.
        store.clock.seconds = 212
        store.sceneActivityChanged(isActive: false)
        await store.flushPendingSaves()
        XCTAssertEqual(LisaStore(saveURL: url).clock.seconds, 211)
        store.sceneActivityChanged(isActive: true)
        store.sceneActivityChanged(isActive: false)
        await store.flushPendingSaves()
        XCTAssertEqual(LisaStore(saveURL: url).clock.seconds, 212)
    }


    @MainActor func testMismatchedPerModeContextCannotOverwriteSave() async throws {
        let url = try temporarySave()
        try fixture().write(to: url)
        let originalStore = LisaStore(saveURL: url)
        originalStore.save()
        await originalStore.flushPendingSaves()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var saves = try XCTUnwrap(json["savedGames"] as? [String: Any])
        saves["Libre"] = saves.removeValue(forKey: "Quotidien")
        json["savedGames"] = saves
        let corrupted = try JSONSerialization.data(withJSONObject: json)
        try corrupted.write(to: url)
        let store = LisaStore(saveURL: url)
        XCTAssertNotNil(store.saveError)
        store.saveError = nil
        store.settings.numberFirst = true
        store.save()
        await store.flushPendingSaves()
        XCTAssertEqual(try Data(contentsOf: url), corrupted)
    }

}


private final class GenerationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var active = 0
    private var maximum = 0
    private var count = 0
    var started: Int { lock.withLock { count } }
    var maximumActive: Int { lock.withLock { maximum } }
    func enter() { lock.withLock { active += 1; count += 1; maximum = max(maximum, active) } }
    func exit() { lock.withLock { active -= 1 } }
}
