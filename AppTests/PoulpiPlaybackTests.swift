import SceneKit
import UIKit
import XCTest
@testable import SudokuLisa

@MainActor
final class PoulpiPlaybackTests: XCTestCase {
    func testEveryExpressionStartsAndCanReplayWithoutChangingMood() throws {
        let view = OctopusRenderView()
        for (index, mood) in LisaMascotMood.allCases.enumerated() {
            view.configure(mood: mood, reaction: index * 2, animated: true)
            let rig = try XCTUnwrap(node(withAction: "rig", in: view.scene!.rootNode), mood.rawValue)
            XCTAssertNotNil(rig.action(forKey: "rig"), mood.rawValue)
            if mood != .idle && mood != .sleepy {
                let gesture = try XCTUnwrap(node(withAction: "gesture", in: view.scene!.rootNode), mood.rawValue)
                let first = try XCTUnwrap(gesture.action(forKey: "gesture"))
                XCTAssertEqual(first.duration, mood.reactionDuration)
                view.configure(mood: mood, reaction: index * 2 + 1, animated: true)
                XCTAssertFalse(first === gesture.action(forKey: "gesture"), "Replay must restart \(mood)")
            }
        }
    }

    func testPauseKeepsActionsAndSpeedAppliesToTheWholeScene() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let view = OctopusRenderView()
        window.addSubview(view)
        view.configure(mood: .surprised, reaction: 1, animated: true)
        let scene = try XCTUnwrap(view.scene)
        let rig = try XCTUnwrap(node(withAction: "rig", in: scene.rootNode))
        let gesture = try XCTUnwrap(node(withAction: "gesture", in: scene.rootNode))
        let rigAction = try XCTUnwrap(rig.action(forKey: "rig"))
        let gestureAction = try XCTUnwrap(gesture.action(forKey: "gesture"))
        XCTAssertFalse(scene.isPaused)
        view.setPlayback(paused: true, speed: 0.35)
        XCTAssertTrue(scene.isPaused)
        XCTAssertFalse(view.rendersContinuously)
        XCTAssertEqual(rigAction.speed, 0.35, accuracy: 0.001)
        XCTAssertEqual(gestureAction.speed, 0.35, accuracy: 0.001)
        view.setPlayback(paused: false, speed: 1)
        XCTAssertFalse(scene.isPaused)
        XCTAssertTrue(rigAction === rig.action(forKey: "rig"))
        XCTAssertTrue(gestureAction === gesture.action(forKey: "gesture"))
        view.removeFromSuperview()
        XCTAssertTrue(scene.isPaused, "Detached previews must stop rendering")
    }

    func testDisabledMotionStopsRigAndSameMoodResumes() throws {
        let view = OctopusRenderView()
        view.configure(mood: .celebrating, reaction: 1, animated: true)
        let root = try XCTUnwrap(view.scene?.rootNode)
        XCTAssertNotNil(node(withAction: "rig", in: root))
        view.configure(mood: .celebrating, reaction: 1, animated: false)
        XCTAssertNil(node(withAction: "rig", in: root))
        XCTAssertNil(node(withAction: "gesture", in: root))
        view.configure(mood: .celebrating, reaction: 1, animated: true)
        XCTAssertNotNil(node(withAction: "rig", in: root))
        XCTAssertNotNil(node(withAction: "gesture", in: root))
    }

    private func node(withAction key: String, in root: SCNNode) -> SCNNode? {
        if root.action(forKey: key) != nil { return root }
        for child in root.childNodes {
            if let match = node(withAction: key, in: child) { return match }
        }
        return nil
    }
}
