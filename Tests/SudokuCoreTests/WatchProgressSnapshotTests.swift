import XCTest
@testable import SudokuCore

final class WatchProgressSnapshotTests: XCTestCase {
    private var context: [String: Any] {
        ["lisaProgressVersion": 1, "completedGames": 12, "currentStreak": 3, "updatedAt": 1_700_000_000.0]
    }

    func testOlderSnapshotsKeepProgressAndDefaultPoulpi() throws {
        let value = try XCTUnwrap(WatchProgressSnapshot(context: context))
        XCTAssertEqual(value.completedGames, 12)
        XCTAssertEqual(value.currentStreak, 3)
        XCTAssertEqual(value.appearance, PoulpiAppearance())
    }

    func testAllPhoneAppearancesArePreserved() throws {
        for color in PoulpiColor.allCases {
            for accessory in PoulpiAccessory.allCases {
                var payload = context
                payload["poulpiColor"] = color.rawValue
                payload["poulpiAccessory"] = accessory.rawValue
                let value = try XCTUnwrap(WatchProgressSnapshot(context: payload))
                XCTAssertEqual(value.appearance, PoulpiAppearance(color: color, accessory: accessory))
            }
        }
    }

    func testPersistedSnapshotKeepsAppearanceAndOrderingDate() throws {
        var payload = context
        payload["poulpiColor"] = "gold"
        payload["poulpiAccessory"] = "crown"
        let original = try XCTUnwrap(WatchProgressSnapshot(context: payload))
        let data = try PropertyListSerialization.data(fromPropertyList: original.context, format: .binary, options: 0)
        let restored = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(WatchProgressSnapshot(context: restored), original)
    }

    func testUnknownAppearanceDoesNotDiscardProgress() throws {
        var payload = context
        payload["poulpiColor"] = "unknown-color"
        payload["poulpiAccessory"] = "unknown-accessory"
        XCTAssertEqual(try XCTUnwrap(WatchProgressSnapshot(context: payload)).appearance, PoulpiAppearance())
    }

    func testInvalidOrUnsupportedSnapshotsAreRejected() {
        for (key, value) in [("lisaProgressVersion", 2 as Any), ("completedGames", -1),
                             ("currentStreak", -1), ("updatedAt", Double.nan), ("updatedAt", 0.0)] {
            var payload = context
            payload[key] = value
            XCTAssertNil(WatchProgressSnapshot(context: payload))
        }
        XCTAssertNil(WatchProgressSnapshot(context: [:]))
    }
}
