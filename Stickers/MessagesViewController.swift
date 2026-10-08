import Messages
import OSLog
import PoulpiStickers
import UIKit

/// Messages owns sticker insertion and sending; the same catalogue is previewed in Lisa.
final class MessagesViewController: MSMessagesAppViewController {
    private let browser = LisaStickerBrowser(stickerSize: .regular)
    private let retryButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        addChild(browser)
        let stack = UIStackView(arrangedSubviews: [browser.view, retryButton])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        browser.didMove(toParent: self)
        browser.stickerBrowserView.backgroundColor = .systemBackground
        browser.stickerBrowserView.accessibilityIdentifier = "poulpiMessageStickers"
        retryButton.titleLabel?.numberOfLines = 0
        retryButton.titleLabel?.textAlignment = .center
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .callout)
        retryButton.accessibilityIdentifier = "poulpiStickerRetry"
        retryButton.setTitle(PoulpiStickerCatalog.text("Impossible de charger les autocollants.") + " " + PoulpiStickerCatalog.text("Réessayer"), for: .normal)
        retryButton.addTarget(self, action: #selector(reloadStickers), for: .touchUpInside)
        reloadStickers()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        loadViewIfNeeded()
        if browser.hasLoadFailures { reloadStickers() }
        browser.stickerBrowserView.reloadData()
    }

    @objc private func reloadStickers() {
        browser.loadStickers()
        retryButton.isHidden = !browser.hasLoadFailures
    }
}

private final class LisaStickerBrowser: MSStickerBrowserViewController {
    private var stickers: [MSSticker] = []
    private(set) var hasLoadFailures = false
    private let logger = Logger(subsystem: "com.xavier.sudokulisa.LisaStickers", category: "Catalogue")

    func loadStickers() {
        hasLoadFailures = false
        stickers = PoulpiStickerCatalog.stickers.compactMap { item in
            guard let url = PoulpiStickerCatalog.imageURL(for: item.id, fileExtension: "png") else {
                logger.error("Missing sticker resource: \(item.id, privacy: .public)")
                hasLoadFailures = true
                return nil
            }
            do {
                return try MSSticker(contentsOfFileURL: url, localizedDescription: item.title)
            } catch {
                logger.error("Cannot load sticker \(item.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                hasLoadFailures = true
                return nil
            }
        }
        stickerBrowserView.dataSource = self
        stickerBrowserView.reloadData()
        logger.info("Loaded \(self.stickers.count) Poulpi stickers")
    }

    override func numberOfStickers(in stickerBrowserView: MSStickerBrowserView) -> Int { stickers.count }

    override func stickerBrowserView(_ stickerBrowserView: MSStickerBrowserView, stickerAt index: Int) -> MSSticker {
        stickers[index]
    }
}
