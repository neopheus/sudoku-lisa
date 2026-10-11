import AVFoundation
import CryptoKit
import XCTest
@testable import SudokuLisa

final class BundleResourceTests: XCTestCase {
    func testPackedRigRestoresExactValidatedGeometry() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "poulpi-rig", withExtension: "lzfse"))
        let packed = try Data(contentsOf: url)
        let restored = try (packed as NSData).decompressed(using: .lzfse) as Data
        let hash = SHA256.hash(data: restored).map { String(format: "%02x", $0) }.joined()
        // Update only after regenerating and visually validating the source sculpt.
        XCTAssertEqual(hash, "f6fec4fbf381a435955b835b01774d4bb396fc44b024f8f99e7a55669da8e94d")
        XCTAssertNil(Bundle.main.url(forResource: "poulpi-rig", withExtension: "json"),
                     "The uncompressed authoring file must not be shipped as well")
    }

    func testEveryWorldTrackDecodesWithOriginalDurationAndStereo() throws {
        let tracks: [(String, Double)] = [
            ("garden", 66.781519), ("candyForest", 69.683311),
            ("lagoon", 80.001655), ("frost", 43.676735), ("stars", 64)
        ]
        for (world, duration) in tracks {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "lisa-world-\(world)", withExtension: "m4a"))
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertTrue(player.prepareToPlay(), world)
            XCTAssertEqual(player.numberOfChannels, 2, world)
            XCTAssertEqual(player.duration, duration, accuracy: 0.001, world)
            let file = try AVAudioFile(forReading: url)
            XCTAssertEqual(file.processingFormat.sampleRate, 48_000, world)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 8192))
            var frames: AVAudioFramePosition = 0
            while file.framePosition < file.length {
                try file.read(into: buffer)
                guard buffer.frameLength > 0 else { XCTFail("Truncated audio: \(world)"); break }
                frames += AVAudioFramePosition(buffer.frameLength)
            }
            XCTAssertEqual(Double(frames) / file.processingFormat.sampleRate, duration, accuracy: 0.001, world)
        }
    }
}
