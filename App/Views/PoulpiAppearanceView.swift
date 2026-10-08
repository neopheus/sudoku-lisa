import SwiftUI
import SceneKit
import SudokuCore

extension PoulpiColor {
    var title: String {
        switch self {
        case .pink: L10n.text("Original")
        case .coral: L10n.text("Corail")
        case .lavender: L10n.text("Lavande")
        case .lagoon: L10n.text("Bleu lagon")
        case .mint: L10n.text("Menthe")
        case .gold: L10n.text("Doré")
        }
    }
    var swatch: Color {
        let rgb = pigment
        return Color(red: rgb.x, green: rgb.y, blue: rgb.z)
    }
    /// Original keeps the exact validated material and shader untouched.
    var pigment: SIMD3<Double> {
        switch self {
        case .pink: SIMD3(0.37, 0.32, 0.76)
        case .coral: SIMD3(0.90, 0.39, 0.40)
        case .lavender: SIMD3(0.64, 0.47, 0.87)
        case .lagoon: SIMD3(0.21, 0.62, 0.86)
        case .mint: SIMD3(0.26, 0.72, 0.57)
        case .gold: SIMD3(0.92, 0.65, 0.25)
        }
    }
}

extension PoulpiAccessory {
    var title: String {
        switch self {
        case .none: L10n.text("Sans accessoire")
        case .star: L10n.text("L’étoile du voyage")
        case .headband: L10n.text("Bandeau de battle")
        case .crown: L10n.text("Couronne de champion")
        }
    }
    var icon: String {
        switch self {
        case .none: "circle.dashed"
        case .star: "star.fill"
        case .headband: "flag.checkered"
        case .crown: "crown.fill"
        }
    }
}

/// Selection controls share one live preview in the Poulpi stage. Swatches and
/// accessory cards never create additional animated SceneKit surfaces.
struct PoulpiAppearanceControls: View {
    @EnvironmentObject private var store: LisaStore
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("Personnaliser Poulpi")).font(LisaTheme.heading(17))
            Text(L10n.text("Couleurs gratuites")).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                ForEach(PoulpiColor.allCases) { color in
                    PoulpiColorChoice(color: color, selected: store.poulpiAppearance.color == color) {
                        store.selectPoulpiColor(color)
                        store.feedback(.select)
                    }
                }
            }
            Text(L10n.text("Un accessoire à la fois")).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted)
            ForEach(PoulpiAccessory.allCases) { accessory in
                PoulpiAccessoryChoice(accessory: accessory,
                                      selected: store.poulpiAppearance.accessory == accessory,
                                      unlocked: store.isPoulpiAccessoryUnlocked(accessory),
                                      progress: progress(accessory)) {
                    store.equipPoulpiAccessory(store.poulpiAppearance.accessory == accessory ? .none : accessory)
                    store.feedback(.select)
                }
            }
        }
        .padding(14)
        .background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 20))
    }

    private func progress(_ accessory: PoulpiAccessory) -> String {
        switch accessory {
        case .none: return L10n.text("Poulpi au naturel")
        case .star:
            return store.isPoulpiAccessoryUnlocked(accessory) ? L10n.text("Un souvenir de votre première escale.")
                : L10n.text("Voyage : %@/5 étapes", String(min(5, store.eventWins)))
        case .headband:
            return store.isPoulpiAccessoryUnlocked(accessory) ? L10n.text("Votre première battle terminée !")
                : L10n.text("Terminez votre première battle")
        case .crown:
            return store.isPoulpiAccessoryUnlocked(accessory) ? L10n.text("Cinq victoires, une couronne !")
                : L10n.text("Battles : %@/5 victoires", String(min(5, store.battleRewards.wins)))
        }
    }
}

private struct PoulpiColorChoice: View {
    let color: PoulpiColor
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Circle().fill(color.swatch.gradient).frame(width: 34, height: 34)
                    .overlay { if selected { Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white) } }
                    .overlay(Circle().strokeBorder(selected ? LisaTheme.ink : .white, lineWidth: selected ? 3 : 2))
                Text(color.title).font(LisaTheme.body(11)).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 62).padding(4)
            .background(selected ? LisaTheme.lavender.opacity(0.3) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        }
        .foregroundStyle(LisaTheme.ink).buttonStyle(LisaPressStyle())
        .accessibilityLabel(color.title).accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("poulpiColor-" + color.rawValue)
    }
}

private struct PoulpiAccessoryChoice: View {
    let accessory: PoulpiAccessory
    let selected: Bool
    let unlocked: Bool
    let progress: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: accessory.icon).font(.system(size: 20, weight: .bold))
                    .foregroundStyle(unlocked ? LisaTheme.ink : LisaTheme.muted)
                    .frame(width: 38, height: 38)
                    .background((selected ? LisaTheme.yellow : LisaTheme.lavender.opacity(0.3)), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(accessory.title).font(LisaTheme.heading(13))
                    Text(progress).font(LisaTheme.body(11)).foregroundStyle(LisaTheme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: unlocked ? (selected ? "checkmark.circle.fill" : "circle") : "lock.fill")
                    .foregroundStyle(selected ? LisaTheme.ink : LisaTheme.muted)
            }
            .padding(8).frame(minHeight: 52)
            .background(selected ? LisaTheme.yellow.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 14))
        }
        .foregroundStyle(LisaTheme.ink).buttonStyle(LisaPressStyle()).disabled(!unlocked)
        .accessibilityLabel(accessory == .star ? (selected ? L10n.text("Retirer") : L10n.text("Équiper")) : accessory.title)
        .accessibilityValue(accessory.title + ". " + progress)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(accessory == .star ? "poulpiStarToggle" : "poulpiAccessory-" + accessory.rawValue)
    }
}

/// A still of the same rig and accessories. No animated view or render loop is
/// retained by an opponent avatar; the serial renderer caches at most 24 images.
struct PoulpiAvatar: View {
    var appearance = PoulpiAppearance()
    var size: CGFloat = 48
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            Circle().fill(appearance.color.swatch.opacity(0.12))
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "water.waves").font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(appearance.color.swatch)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: appearance) {
            image = nil
            let rendered = await PoulpiAvatarRenderer.shared.image(for: appearance)
            guard !Task.isCancelled else { return }
            image = rendered
        }
    }
}

private actor PoulpiAvatarRenderer {
    static let shared = PoulpiAvatarRenderer()
    private var images: [PoulpiAppearance: UIImage] = [:]
    func image(for appearance: PoulpiAppearance) -> UIImage {
        if let image = images[appearance] { return image }
        let model = OctopusModel()
        model.setMotionEnabled(false)
        model.setAppearance(appearance)
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = model.scene
        renderer.pointOfView = model.scene.rootNode.childNodes.first { $0.camera != nil }
        let image = renderer.snapshot(atTime: 0, with: CGSize(width: 160, height: 160), antialiasingMode: .multisampling4X)
        // Six finite palettes × four accessories; unknown server values cannot
        // create new cache keys because the shared model uses closed enums.
        images[appearance] = image
        return image
    }
}
