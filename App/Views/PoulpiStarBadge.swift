import SwiftUI
import SudokuCore

/// A permanent souvenir: a static SwiftUI ornament, with no extra SceneKit work.
struct PoulpiStarBadge: View {
    var size: CGFloat = 32
    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: size * 0.58, weight: .bold))
            .foregroundStyle(Color(red: 0.65, green: 0.33, blue: 0.04))
            .frame(width: size, height: size)
            .background(LisaTheme.yellow.gradient, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 2))
            .accessibilityLabel(L10n.text("L’étoile du voyage"))
    }
}
