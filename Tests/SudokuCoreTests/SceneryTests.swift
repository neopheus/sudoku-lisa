import XCTest
@testable import SudokuCore

final class SceneryTests: XCTestCase {
    func testJourneyVisitsExactlyTwentyFiveStops() {
        let stops = (1...25).compactMap { SceneryStop.journey(stage: $0) }
        XCTAssertEqual(Set(stops.map(\.id)).count, 25)
        for world in SceneryWorld.allCases {
            XCTAssertEqual(stops.filter { $0.world == world }.map(\.index), Array(0..<5))
        }
        XCTAssertNil(SceneryStop.journey(stage: 0))
        XCTAssertNil(SceneryStop.journey(stage: 26))
        for stop in stops { XCTAssertEqual(SceneryStop(id: stop.id), stop) }
        XCTAssertNil(SceneryStop(id: "garden-99"))
    }

    func testFreeRouteShufflesWorldsAndChangesStopsOnEveryVisit() throws {
        var route = FreeSceneryRoute()
        var previous: SceneryStop?
        var visits: [SceneryWorld: Set<Int>] = [:]
        for _ in 0..<5 {
            var worlds: Set<SceneryWorld> = []
            for _ in 0..<5 {
                let next = route.next
                XCTAssertNotEqual(next.world, previous?.world)
                XCTAssertTrue(worlds.insert(next.world).inserted)
                XCTAssertTrue(visits[next.world, default: []].insert(next.index).inserted)
                XCTAssertEqual(route.takeNext(), next)
                let encoded = try JSONEncoder().encode(route)
                route = try JSONDecoder().decode(FreeSceneryRoute.self, from: encoded)
                previous = next
            }
        }
        XCTAssertEqual(visits.values.reduce(0) { $0 + $1.count }, 25)
    }

    func testMigrationStableAtEverySeedAndAvoidsImmediateRepeat() {
        for seed in [UInt64(0), 42, UInt64.max] {
            let stop = SceneryStop.legacyFree(seed: seed)
            XCTAssertEqual(stop, SceneryStop.legacyFree(seed: seed))
            let route = FreeSceneryRoute(after: stop)
            XCTAssertNotEqual(route.next.world, stop.world)
        }
    }
}
