import Foundation
import PoulpiStickers
import UIKit

enum WhatsAppStickerError: Error, Equatable {
    case unavailable
    case missingAsset
    case invalidPack
    case couldNotOpen
}

/// The JSON is built and validated away from the main actor. Only the explicit
/// button action writes the short-lived pasteboard item and opens WhatsApp.
enum WhatsAppStickerService {
    static let pasteboardType = "net.whatsapp.third-party.sticker-pack"
    static let openURL = URL(string: "whatsapp://stickerPack")!

    struct StickerInput: Sendable {
        let webp: Data
        let emojis: [String]
        let accessibilityEnglish: String
    }

    private struct StickerJSON: Encodable {
        let image_data: String
        let emojis: [String]
        let accessibility_text: String
    }

    private struct PackJSON: Encodable {
        let identifier: String
        let name: String
        let publisher: String
        let tray_image: String
        let stickers: [StickerJSON]
    }

    static func payload(trayPNG: Data, stickers: [StickerInput], name: String) throws -> Data {
        // Xcode can replace PNG's IHDR with a CgBI chunk in processed bundles.
        // Re-encode that iOS-specific variant before sending standard PNG bytes.
        let tray: Data
        if trayPNG.count >= 16, Array(trayPNG[12..<16]) == Array("CgBI".utf8) {
            tray = UIImage(data: trayPNG)?.pngData() ?? trayPNG
        } else {
            tray = trayPNG
        }
        guard (3...30).contains(stickers.count),
              !name.isEmpty, name.count <= 128,
              validPNG(tray, width: 96, height: 96, maximumBytes: 50_000)
        else { throw WhatsAppStickerError.invalidPack }

        let encoded = try stickers.map { item -> StickerJSON in
            guard !item.emojis.isEmpty, item.emojis.count <= 3,
                  !item.accessibilityEnglish.isEmpty, item.accessibilityEnglish.count <= 125,
                  validStaticWebP(item.webp, width: 512, height: 512, maximumBytes: 100_000)
            else { throw WhatsAppStickerError.invalidPack }
            return StickerJSON(
                image_data: item.webp.base64EncodedString(),
                emojis: item.emojis,
                accessibility_text: item.accessibilityEnglish
            )
        }

        return try JSONEncoder().encode(PackJSON(
            identifier: "lisa.poulpi.moods.v1",
            name: name,
            publisher: "Lisa Sudoku",
            tray_image: tray.base64EncodedString(),
            stickers: encoded
        ))
    }

    @MainActor
    static func openPack() async throws {
        guard UIApplication.shared.canOpenURL(openURL) else { throw WhatsAppStickerError.unavailable }
        let name = PoulpiStickerCatalog.text("gallery.title")
        let items = PoulpiStickerCatalog.stickers
        let trayURL = PoulpiStickerCatalog.trayURL
        let stickerURLs = items.map { PoulpiStickerCatalog.imageURL(for: $0.id, fileExtension: "webp") }
        guard let trayURL, stickerURLs.allSatisfy({ $0 != nil }) else { throw WhatsAppStickerError.missingAsset }

        let worker = Task.detached(priority: .userInitiated) {
            let tray = try Data(contentsOf: trayURL)
            var stickers: [StickerInput] = []
            stickers.reserveCapacity(items.count)
            for (item, url) in zip(items, stickerURLs) {
                try Task.checkCancellation()
                guard let url else { throw WhatsAppStickerError.missingAsset }
                stickers.append(StickerInput(
                    webp: try Data(contentsOf: url),
                    emojis: item.emojis,
                    accessibilityEnglish: item.accessibilityEnglish
                ))
            }
            try Task.checkCancellation()
            return try payload(trayPNG: tray, stickers: stickers, name: name)
        }
        let data = try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }

        try Task.checkCancellation()
        UIPasteboard.general.setItems(
            [[pasteboardType: data]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)]
        )
        guard await UIApplication.shared.open(openURL) else { throw WhatsAppStickerError.couldNotOpen }
    }

    private static func validPNG(_ data: Data, width: Int, height: Int, maximumBytes: Int) -> Bool {
        guard (24...maximumBytes).contains(data.count) else { return false }
        let bytes = Array(data.prefix(24))
        guard Array(bytes[0..<8]) == [137, 80, 78, 71, 13, 10, 26, 10],
              Array(bytes[12..<16]) == [73, 72, 68, 82] else { return false }
        func integer(_ start: Int) -> Int {
            bytes[start..<(start + 4)].reduce(0) { ($0 << 8) | Int($1) }
        }
        return integer(16) == width && integer(20) == height
    }

    private static func validStaticWebP(_ data: Data, width: Int, height: Int, maximumBytes: Int) -> Bool {
        guard (30...maximumBytes).contains(data.count) else { return false }
        let bytes = Array(data.prefix(30))
        guard Array(bytes[0..<4]) == Array("RIFF".utf8),
              Array(bytes[8..<12]) == Array("WEBP".utf8) else { return false }
        let riffLength = bytes[4..<8].enumerated().reduce(0) { $0 | (Int($1.element) << (8 * $1.offset)) }
        guard riffLength + 8 == data.count else { return false }
        let fourCC = String(decoding: bytes[12..<16], as: UTF8.self)
        let actual: (Int, Int)
        switch fourCC {
        case "VP8X":
            guard bytes[20] & 0x02 == 0 else { return false }
            actual = (
                1 + Int(bytes[24]) + (Int(bytes[25]) << 8) + (Int(bytes[26]) << 16),
                1 + Int(bytes[27]) + (Int(bytes[28]) << 8) + (Int(bytes[29]) << 16)
            )
        case "VP8L":
            guard bytes[20] == 0x2f else { return false }
            actual = (
                1 + Int(bytes[21]) + (Int(bytes[22] & 0x3f) << 8),
                1 + Int(bytes[22] >> 6) + (Int(bytes[23]) << 2) + (Int(bytes[24] & 0x0f) << 10)
            )
        case "VP8 ":
            guard Array(bytes[23..<26]) == [0x9d, 0x01, 0x2a] else { return false }
            actual = (
                (Int(bytes[26]) | (Int(bytes[27]) << 8)) & 0x3fff,
                (Int(bytes[28]) | (Int(bytes[29]) << 8)) & 0x3fff
            )
        default: return false
        }
        return actual.0 == width && actual.1 == height
    }
}
