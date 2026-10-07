import SwiftUI
import SudokuCore

struct GenerationOverlay: View {
    @EnvironmentObject private var store: LisaStore
    @AccessibilityFocusState private var statusFocused: Bool
    var body: some View {
        if store.isGenerating {
            ZStack {
                Color.black.opacity(0.25).ignoresSafeArea().accessibilityHidden(true)
                VStack(spacing: 18) {
                    ProgressView(L10n.text("On prépare votre petite pause…"))
                        .font(LisaTheme.body())
                        .accessibilityFocused($statusFocused)
                        .accessibilityIdentifier("generationStatus")
                    Button(L10n.text("Annuler")) { store.cancelGeneration() }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("cancelGeneration")
                        .keyboardShortcut(.cancelAction)
                }
                .padding(30)
                .accessibilityElement(children: .contain)
                .accessibilityAction(.escape) { store.cancelGeneration() }
                .onAppear { statusFocused = true }
                .background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 28))
            }
        }
    }
}
