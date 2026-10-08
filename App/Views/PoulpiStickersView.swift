import PoulpiStickers
import SudokuCore
import SwiftUI
import UIKit

struct PoulpiStickersView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selected: PoulpiSticker?
    @State private var exporting = false
    @State private var exportTask: Task<Void, Never>?
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 170 : 126), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(PoulpiStickerCatalog.text("gallery.title"))
                        .font(.largeTitle.bold())
                        .foregroundStyle(LisaTheme.ink)
                    Text(PoulpiStickerCatalog.text("gallery.subtitle"))
                        .font(.body)
                        .foregroundStyle(LisaTheme.muted)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PoulpiStickerCatalog.stickers) { sticker in
                        Button { selected = sticker } label: {
                            StickerTile(sticker: sticker)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(sticker.title)
                        .accessibilityIdentifier("poulpiSticker.\(sticker.id)")
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        guard !exporting else { return }
                        exporting = true
                        exportTask = Task {
                            defer {
                                exporting = false
                                exportTask = nil
                            }
                            do {
                                try await WhatsAppStickerService.openPack()
                            } catch WhatsAppStickerError.unavailable {
                                if !Task.isCancelled {
                                    presentAlert(title: "gallery.unavailable.title", message: "gallery.unavailable.message")
                                }
                            } catch {
                                if !Task.isCancelled {
                                    presentAlert(title: "gallery.error.title", message: "gallery.error.message")
                                }
                            }
                        }
                    } label: {
                        Label(
                            exporting ? PoulpiStickerCatalog.text("gallery.loading") : PoulpiStickerCatalog.text("gallery.whatsapp"),
                            systemImage: "plus.bubble.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LisaTheme.coral)
                    .disabled(exporting)
                    .accessibilityIdentifier("poulpiAddToWhatsApp")

                    Text(PoulpiStickerCatalog.text("gallery.imessage"))
                        .font(.footnote)
                        .foregroundStyle(LisaTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 22))
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(LisaTheme.background)
        .navigationTitle(PoulpiStickerCatalog.text("gallery.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { sticker in
            StickerDetail(sticker: sticker)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button(PoulpiStickerCatalog.text("gallery.ok"), role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onDisappear { exportTask?.cancel() }
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = PoulpiStickerCatalog.text(title)
        alertMessage = PoulpiStickerCatalog.text(message)
        showAlert = true
    }
}

private struct StickerTile: View {
    let sticker: PoulpiSticker

    var body: some View {
        VStack(spacing: 8) {
            StickerArtwork(id: sticker.id)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
            Text(sticker.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LisaTheme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct StickerDetail: View {
    @Environment(\.dismiss) private var dismiss
    let sticker: PoulpiSticker

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Spacer(minLength: 0)
                StickerArtwork(id: sticker.id)
                    .frame(maxWidth: 320, maxHeight: 320)
                    .padding(24)
                    .background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 30))
                Text(sticker.title)
                    .font(.title2.bold())
                    .foregroundStyle(LisaTheme.ink)
                if let url = PoulpiStickerCatalog.imageURL(for: sticker.id) {
                    ShareLink(item: url) {
                        Label(PoulpiStickerCatalog.text("gallery.share"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LisaTheme.coral)
                    .accessibilityIdentifier("poulpiShareSticker")
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(LisaTheme.background)
            .navigationTitle(PoulpiStickerCatalog.text("gallery.detail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(PoulpiStickerCatalog.text("gallery.ok")) { dismiss() }
                }
            }
        }
    }
}

private struct StickerArtwork: View {
    let id: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LisaTheme.coral)
                    .padding(32)
            }
        }
        .accessibilityHidden(true)
        .task(id: id) {
            let key = id as NSString
            if let cached = StickerImageCache.shared.object(forKey: key) {
                image = cached
                return
            }
            guard let url = PoulpiStickerCatalog.imageURL(for: id),
                  let loaded = UIImage(contentsOfFile: url.path),
                  !Task.isCancelled else { return }
            StickerImageCache.shared.setObject(loaded, forKey: key, cost: Int(loaded.size.width * loaded.size.height * 4))
            image = loaded
        }
    }
}

@MainActor private enum StickerImageCache {
    static let shared: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 24
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()
}
