import SwiftUI
import SudokuCore

struct GenerationOverlay: View {
    @EnvironmentObject private var store: LisaStore
    var body: some View {
        if store.isGenerating {
            ZStack {
                Color.black.opacity(0.25).ignoresSafeArea()
                VStack(spacing: 18) {
                    ProgressView(L10n.text("On prépare votre petite pause…"))
                        .font(LisaTheme.body())
                    Button(L10n.text("Annuler")) { store.cancelGeneration() }
                        .accessibilityIdentifier("cancelGeneration")
                }
                .padding(30)
                .background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 28))
            }
        }
    }
}
