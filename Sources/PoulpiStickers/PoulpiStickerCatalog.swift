import Foundation

public struct PoulpiSticker: Identifiable, Sendable {
    public let id: String
    public let titleKey: String
    public let emojis: [String]
    public let accessibilityEnglish: String

    public var title: String { PoulpiStickerCatalog.text(titleKey) }
}

public enum PoulpiStickerCatalog {
    public static let stickers: [PoulpiSticker] = [
        .init(id: "idle", titleKey: "sticker.idle", emojis: ["🐙", "💜"], accessibilityEnglish: "Poulpi resting"),
        .init(id: "happy", titleKey: "sticker.happy", emojis: ["🐙", "😊"], accessibilityEnglish: "Happy Poulpi"),
        .init(id: "thinking", titleKey: "sticker.thinking", emojis: ["🐙", "🤔"], accessibilityEnglish: "Poulpi thinking"),
        .init(id: "encouraging", titleKey: "sticker.encouraging", emojis: ["🐙", "💪"], accessibilityEnglish: "Poulpi cheering you on"),
        .init(id: "sleepy", titleKey: "sticker.sleepy", emojis: ["🐙", "😴"], accessibilityEnglish: "Sleepy Poulpi"),
        .init(id: "celebrating", titleKey: "sticker.celebrating", emojis: ["🐙", "🎉"], accessibilityEnglish: "Poulpi celebrating"),
        .init(id: "pirouette", titleKey: "sticker.pirouette", emojis: ["🐙", "🌀"], accessibilityEnglish: "Poulpi spinning"),
        .init(id: "wobble", titleKey: "sticker.wobble", emojis: ["🐙", "〰️"], accessibilityEnglish: "Poulpi wobbling"),
        .init(id: "peek", titleKey: "sticker.peek", emojis: ["🐙", "👀"], accessibilityEnglish: "Poulpi peeking"),
        .init(id: "jelly", titleKey: "sticker.jelly", emojis: ["🐙", "🪼"], accessibilityEnglish: "Poulpi jiggling"),
        .init(id: "swim", titleKey: "sticker.swim", emojis: ["🐙", "🌊"], accessibilityEnglish: "Poulpi swimming"),
        .init(id: "bow", titleKey: "sticker.bow", emojis: ["🐙", "🙇"], accessibilityEnglish: "Poulpi bowing"),
        .init(id: "curious", titleKey: "sticker.curious", emojis: ["🐙", "🔎"], accessibilityEnglish: "Curious Poulpi"),
        .init(id: "giggle", titleKey: "sticker.giggle", emojis: ["🐙", "😄"], accessibilityEnglish: "Poulpi giggling"),
        .init(id: "rocket", titleKey: "sticker.rocket", emojis: ["🐙", "🚀"], accessibilityEnglish: "Poulpi blasting off"),
        .init(id: "chase", titleKey: "sticker.chase", emojis: ["🐙", "✨"], accessibilityEnglish: "Poulpi chasing a sparkle"),
        .init(id: "moonwalk", titleKey: "sticker.moonwalk", emojis: ["🐙", "🌙"], accessibilityEnglish: "Poulpi moonwalking"),
        .init(id: "juggle", titleKey: "sticker.juggle", emojis: ["🐙", "🤹"], accessibilityEnglish: "Poulpi juggling"),
        .init(id: "cloudHide", titleKey: "sticker.cloudHide", emojis: ["🐙", "☁️"], accessibilityEnglish: "Poulpi hiding behind a cloud"),
        .init(id: "sneeze", titleKey: "sticker.sneeze", emojis: ["🐙", "🤧"], accessibilityEnglish: "Poulpi sneezing"),
        .init(id: "tumble", titleKey: "sticker.tumble", emojis: ["🐙", "🤸"], accessibilityEnglish: "Poulpi tumbling"),
        .init(id: "balance", titleKey: "sticker.balance", emojis: ["🐙", "⚖️"], accessibilityEnglish: "Poulpi balancing"),
        .init(id: "dizzy", titleKey: "sticker.dizzy", emojis: ["🐙", "😵‍💫"], accessibilityEnglish: "Dizzy Poulpi"),
        .init(id: "superhero", titleKey: "sticker.superhero", emojis: ["🐙", "🦸"], accessibilityEnglish: "Superhero Poulpi")
    ]

    public static func imageURL(for id: String, fileExtension: String = "png") -> URL? {
        guard stickers.contains(where: { $0.id == id }), ["png", "webp"].contains(fileExtension) else { return nil }
        return Bundle.module.url(forResource: "poulpi-\(id)", withExtension: fileExtension)
    }

    public static var trayURL: URL? {
        Bundle.module.url(forResource: "poulpi-tray", withExtension: "png")
    }

    public static func text(_ key: String) -> String {
        let preference = UserDefaults.standard.string(forKey: "lisa.language")
        let supported = ["fr", "en", "de", "es", "ru"]
        let language = preference.flatMap { supported.contains($0) ? $0 : nil }
            ?? Bundle.preferredLocalizations(from: supported, forPreferences: Locale.preferredLanguages).first
            ?? "fr"
        let bundle = Bundle.module.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? Bundle.module
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
