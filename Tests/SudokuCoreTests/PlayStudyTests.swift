import XCTest
@testable import SudokuCore

final class PlayStudyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_014_400) // UTC midnight

    func testCountersAreBoundedToNinetyDaysAndIgnoreClockRollback() throws {
        var study = PlayStudy(now: start, existingPlayer: false)
        for day in -1...120 { study.record(.appActive, at: start.addingTimeInterval(Double(day) * 86_400)) }
        XCTAssertEqual(study.days.count, 90)
        XCTAssertEqual(study.count(.appActive), 90)
        XCTAssertEqual(study.days[1]?["appActive"], 1)
        XCTAssertEqual(study.days[7]?["appActive"], 1)
        XCTAssertEqual(study.days[30]?["appActive"], 1)
        let reopened = try JSONDecoder().decode(PlayStudy.self, from: JSONEncoder().encode(study))
        XCTAssertEqual(reopened.days, study.days)
        XCTAssertFalse(reopened.existingPlayer)
    }

    func testDisablingStopsCountsAndMarksInterruptedObservation() {
        var study = PlayStudy(now: start, existingPlayer: true)
        study.record(.gameStarted, at: start)
        study.setEnabled(false)
        study.record(.gameCompleted, at: start)
        XCTAssertEqual(study.count(.gameCompleted), 0)
        study.setEnabled(true)
        study.record(.gameCompleted, at: start)
        XCTAssertEqual(study.count(.gameCompleted), 1)
        XCTAssertTrue(study.recordingInterrupted)
    }

    func testRejectsUnboundedCountsAndUnknownEventNames() throws {
        var study = PlayStudy(now: start, existingPlayer: false)
        study.record(.appActive, at: start)
        let data = try JSONEncoder().encode(study)
        let text = String(decoding: data, as: UTF8.self)
        for corrupted in [text.replacingOccurrences(of: "appActive", with: "arbitraryUserData"),
                          text.replacingOccurrences(of: "\"appActive\":1", with: "\"appActive\":-1")] {
            XCTAssertNotEqual(corrupted, text)
            XCTAssertThrowsError(try JSONDecoder().decode(PlayStudy.self, from: Data(corrupted.utf8)))
        }
    }
}
