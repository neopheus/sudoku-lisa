import Messages
import UIKit

/// Four locally bundled stickers. Messages handles placement and sending.
final class MessagesViewController: MSMessagesAppViewController {
    private let browser = LisaStickerBrowser(stickerSize: .small)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        addChild(browser)
        browser.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(browser.view)
        NSLayoutConstraint.activate([
            browser.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            browser.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            browser.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            browser.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        browser.didMove(toParent: self)
        browser.stickerBrowserView.backgroundColor = .systemBackground
    }
}

private final class LisaStickerBrowser: MSStickerBrowserViewController {
    private let stickers: [MSSticker] = [
        ("lisa-smile", "Lisa sourit : on joue ?"),
        ("lisa-heart", "Lisa vous envoie un cœur"),
        ("lisa-bravo", "Lisa vous félicite : bravo !"),
        ("lisa-zen", "Lisa fait une pause zen")
    ].compactMap { name, description in
        guard let url = Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Resources") else { return nil }
        return try? MSSticker(contentsOfFileURL: url, localizedDescription: NSLocalizedString(description, comment: "Sticker accessibility description"))
    }

    override func numberOfStickers(in stickerBrowserView: MSStickerBrowserView) -> Int {
        stickers.count
    }

    override func stickerBrowserView(_ stickerBrowserView: MSStickerBrowserView, stickerAt index: Int) -> MSSticker {
        stickers[index]
    }
}
