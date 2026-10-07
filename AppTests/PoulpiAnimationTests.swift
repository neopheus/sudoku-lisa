import XCTest
import SceneKit
@testable import SudokuLisa

@MainActor
final class PoulpiAnimationTests: XCTestCase {
    func testUnchangedPoseDoesNotRewritePositionsAndScales() {
        let rig = PoulpiRig()
        rig.animate(0)
        var writes = 0
        var observations: [NSKeyValueObservation] = []
        rig.node.enumerateChildNodes { node, _ in
            observations.append(node.observe(\.position) { _, _ in writes += 1 })
            observations.append(node.observe(\.scale) { _, _ in writes += 1 })
        }
        // No elapsed time and no changed inputs: the visible pose is identical.
        for _ in 0..<120 { rig.animate(0) }
        XCTAssertEqual(writes, 0, "Unchanged transforms must not dirty SceneKit nodes every frame")
        withExtendedLifetime(observations) {}
    }

    func testStaticPoseThenResumeRestoresAnimatedFace() {
        let rig = PoulpiRig()
        rig.play(.celebrating, animated: true)
        rig.animate(1)
        var animated: [SCNVector3] = []
        rig.node.enumerateChildNodes { node, _ in animated.append(node.position) }
        rig.play(.sleepy, animated: false)
        rig.play(.celebrating, animated: true)
        rig.animate(1)
        var resumed: [SCNVector3] = []
        rig.node.enumerateChildNodes { node, _ in resumed.append(node.position) }
        XCTAssertEqual(animated.count, resumed.count)
        for (a, b) in zip(animated, resumed) {
            XCTAssertEqual(a.x, b.x, accuracy: 0.00001)
            XCTAssertEqual(a.y, b.y, accuracy: 0.00001)
            XCTAssertEqual(a.z, b.z, accuracy: 0.00001)
        }
    }
}
