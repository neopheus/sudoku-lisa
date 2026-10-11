import XCTest
import Messages
import PoulpiStickers
import UIKit

@MainActor
final class PoulpiStickerTests: XCTestCase {
    func testEveryBundledStickerLoadsInMessages() throws {
        XCTAssertEqual(PoulpiStickerCatalog.stickers.count, 24)
        var uniqueImages = Set<Data>()
        for item in PoulpiStickerCatalog.stickers {
            let url = try XCTUnwrap(PoulpiStickerCatalog.imageURL(for: item.id))
            let data = try Data(contentsOf: url)
            XCTAssertLessThan(data.count, 500_000, item.id)
            let image = try XCTUnwrap(UIImage(data: data)?.cgImage, item.id)
            XCTAssertEqual(image.width, 512, item.id)
            XCTAssertEqual(image.height, 512, item.id)
            let sticker = try MSSticker(contentsOfFileURL: url, localizedDescription: item.title)
            XCTAssertEqual(sticker.localizedDescription, item.title)
            uniqueImages.insert(data)
        }
        XCTAssertEqual(uniqueImages.count, 24, "Every Poulpi sticker has distinct artwork")
    }

    func testMessagesExtensionIsEmbeddedWithItsOwnCatalogueResources() throws {
        let bundleURL = Bundle.main.bundleURL.appendingPathComponent("PlugIns/LisaStickers.appex")
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let contexts = try XCTUnwrap(bundle.infoDictionary?["MSSupportedPresentationContexts"] as? [String])
        XCTAssertEqual(Set(contexts), ["MSMessagesAppPresentationContextMessages", "MSMessagesAppPresentationContextMedia"],
                       "The packaged extension must opt into the system Stickers drawer, not just the iMessage apps list")
        let configuration = try XCTUnwrap(bundle.infoDictionary?["NSExtension"] as? [String: Any])
        XCTAssertEqual(configuration["NSExtensionPointIdentifier"] as? String, "com.apple.message-payload-provider")
        XCTAssertEqual(configuration["NSExtensionPrincipalClass"] as? String, "LisaStickers.MessagesViewController")
        let resources = try FileManager.default.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil)
        let catalogue = try XCTUnwrap(resources.first { $0.lastPathComponent == "SudokuLisa_PoulpiStickers.bundle" })
        let resourceBundle = try XCTUnwrap(Bundle(url: catalogue))
        for item in PoulpiStickerCatalog.stickers {
            XCTAssertNotNil(resourceBundle.url(forResource: "poulpi-\(item.id)", withExtension: "png"), item.id)
        }
    }
}
