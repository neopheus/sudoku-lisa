import Foundation
import PoulpiStickers
import XCTest
@testable import SudokuLisa

final class WhatsAppStickerTests: XCTestCase {
    func testCatalogMatchesMascotMoods() {
        let ids = PoulpiStickerCatalog.stickers.map(\.id)
        XCTAssertEqual(ids.count, 24)
        XCTAssertEqual(Set(ids).count, ids.count, "Sticker IDs must be unique")
        for id in ids {
            XCTAssertNotNil(LisaMascotMood(rawValue: id), "Sticker \(id) must resolve to a mascot mood")
        }
    }

    func testPayloadUsesWhatsAppJSONContract() throws {
        let input = WhatsAppStickerService.StickerInput(
            webp: staticWebP(), emojis: ["🐙", "💜"], accessibilityEnglish: "Poulpi resting"
        )
        let data = try WhatsAppStickerService.payload(
            trayPNG: trayPNG(), stickers: Array(repeating: input, count: 3), name: "Poulpi"
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["identifier"] as? String, "lisa.poulpi.moods.v1")
        XCTAssertEqual(json["publisher"] as? String, "Lisa Sudoku")
        XCTAssertEqual(Data(base64Encoded: try XCTUnwrap(json["tray_image"] as? String)), trayPNG())
        let stickers = try XCTUnwrap(json["stickers"] as? [[String: Any]])
        XCTAssertEqual(stickers.count, 3)
        XCTAssertEqual(Data(base64Encoded: try XCTUnwrap(stickers[0]["image_data"] as? String)), staticWebP())
        XCTAssertEqual(stickers[0]["emojis"] as? [String], ["🐙", "💜"])
        XCTAssertEqual(stickers[0]["accessibility_text"] as? String, "Poulpi resting")
    }

    func testBundledArtworkBuildsCompletePack() throws {
        let trayURL = try XCTUnwrap(PoulpiStickerCatalog.trayURL)
        let tray = try Data(contentsOf: trayURL)
        let items = try PoulpiStickerCatalog.stickers.map { sticker -> WhatsAppStickerService.StickerInput in
            let url = try XCTUnwrap(PoulpiStickerCatalog.imageURL(for: sticker.id, fileExtension: "webp"))
            return WhatsAppStickerService.StickerInput(
                webp: try Data(contentsOf: url),
                emojis: sticker.emojis,
                accessibilityEnglish: sticker.accessibilityEnglish
            )
        }
        let payload = try WhatsAppStickerService.payload(trayPNG: tray, stickers: items, name: "Poulpi")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        XCTAssertEqual((json["stickers"] as? [[String: Any]])?.count, 24)
    }

    func testRejectsOutsidePackLimitsAndAnimatedWebP() {
        let input = WhatsAppStickerService.StickerInput(
            webp: staticWebP(), emojis: ["🐙"], accessibilityEnglish: "Poulpi"
        )
        XCTAssertThrowsError(try WhatsAppStickerService.payload(
            trayPNG: trayPNG(), stickers: Array(repeating: input, count: 2), name: "Poulpi"
        ))
        XCTAssertThrowsError(try WhatsAppStickerService.payload(
            trayPNG: trayPNG(), stickers: Array(repeating: input, count: 31), name: "Poulpi"
        ))
        let animated = WhatsAppStickerService.StickerInput(
            webp: staticWebP(animated: true), emojis: ["🐙"], accessibilityEnglish: "Poulpi"
        )
        XCTAssertThrowsError(try WhatsAppStickerService.payload(
            trayPNG: trayPNG(), stickers: Array(repeating: animated, count: 3), name: "Poulpi"
        ))
    }

    func testRejectsIncorrectDimensionsAndOversizeImages() {
        let input = WhatsAppStickerService.StickerInput(
            webp: staticWebP(width: 511), emojis: ["🐙"], accessibilityEnglish: "Poulpi"
        )
        XCTAssertThrowsError(try WhatsAppStickerService.payload(
            trayPNG: trayPNG(), stickers: Array(repeating: input, count: 3), name: "Poulpi"
        ))
        let valid = WhatsAppStickerService.StickerInput(
            webp: staticWebP(), emojis: ["🐙"], accessibilityEnglish: "Poulpi"
        )
        XCTAssertThrowsError(try WhatsAppStickerService.payload(
            trayPNG: trayPNG(width: 95), stickers: Array(repeating: valid, count: 3), name: "Poulpi"
        ))
        XCTAssertThrowsError(try WhatsAppStickerService.payload(
            trayPNG: Data(repeating: 0, count: 50_001),
            stickers: Array(repeating: valid, count: 3), name: "Poulpi"
        ))
    }

    private func trayPNG(width: Int = 96) -> Data {
        var bytes = Array(repeating: UInt8(0), count: 24)
        bytes[0..<8] = [137, 80, 78, 71, 13, 10, 26, 10]
        bytes[12..<16] = ArraySlice("IHDR".utf8)
        bytes[16..<20] = [0, 0, 0, UInt8(width)]
        bytes[20..<24] = [0, 0, 0, 96]
        return Data(bytes)
    }

    private func staticWebP(width: Int = 512, animated: Bool = false) -> Data {
        var bytes = Array(repeating: UInt8(0), count: 30)
        bytes[0..<4] = ArraySlice("RIFF".utf8)
        bytes[4..<8] = [22, 0, 0, 0]
        bytes[8..<12] = ArraySlice("WEBP".utf8)
        bytes[12..<16] = ArraySlice("VP8X".utf8)
        bytes[20] = animated ? 0x02 : 0
        let encodedWidth = width - 1
        bytes[24..<27] = [UInt8(encodedWidth & 0xff), UInt8((encodedWidth >> 8) & 0xff), 0]
        bytes[27..<30] = [0xff, 0x01, 0]
        return Data(bytes)
    }
}
