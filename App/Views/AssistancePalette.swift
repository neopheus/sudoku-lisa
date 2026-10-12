import SwiftUI
import SudokuCore

/// Presented independently of the board layout: opening an aid never moves the game.
struct AssistancePalette: View {
    @ObservedObject var model: LogicalAssistanceModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    let ready: Bool
    let explain: () -> Void
    let fill: () -> Void
    let clean: () -> Void
    let clear: () -> Void
    let hasNotes: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(L10n.text("Aides"), systemImage: "slider.horizontal.3")
                    .font(LisaTheme.heading(23))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.body.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(LisaTheme.lavender.opacity(0.35), in: Circle())
                }
                .accessibilityLabel(L10n.text("Fermer"))
                .accessibilityIdentifier("assistanceClose")
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AssistanceNotesActions(ready: ready && model.snapshot?.isConsistent == true,
                        hasNotes: hasNotes, fill: fill, clean: clean, clear: clear)
                    VStack(spacing: 0) {
                        Toggle(isOn: $model.candidatesEnabled) {
                            Label(L10n.text("Candidats en direct"), systemImage: "square.grid.3x3")
                        }
                        .accessibilityIdentifier("assistanceCandidates")
                        .padding(14)
                        Divider().padding(.horizontal, 14)
                        Toggle(isOn: $model.trailEnabled) {
                            Label(L10n.text("Piste"), systemImage: "viewfinder")
                        }
                        .accessibilityIdentifier("assistanceTrail")
                        .padding(14)
                    }
                    .background(LisaTheme.lavender.opacity(0.22), in: RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 10) {
                        Button { model.focusPickerPresented.toggle() } label: {
                            HStack {
                                Label(L10n.text("Focus chiffre"), systemImage: "scope")
                                Spacer()
                                if let digit = model.focusDigit {
                                    Text("\(digit)").fontWeight(.heavy)
                                }
                                Image(systemName: model.focusPickerPresented ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.bold))
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("assistanceFocus")
                        .accessibilityValue(model.focusDigit.map(String.init) ?? L10n.text("Désactivé"))
                        if model.focusPickerPresented {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 3 : 5), spacing: 8) {
                                ForEach(1...9, id: \.self) { digit in
                                    Button { model.focusDigit = model.focusDigit == digit ? nil : digit } label: {
                                        Text("\(digit)")
                                            .font(LisaTheme.heading(20))
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                            .background(model.focusDigit == digit ? LisaTheme.yellow : LisaTheme.lavender.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(model.focusDigit == digit ? LisaTheme.ink : .clear, lineWidth: 2))
                                    }
                                    .accessibilityAddTraits(model.focusDigit == digit ? .isSelected : [])
                                    .accessibilityIdentifier("assistanceFocus-\(digit)")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)

                    if model.isWorking { Text(L10n.text("Recherche…")).foregroundStyle(LisaTheme.muted) }
                    if model.failed { Text(L10n.text("Analyse interrompue. Réactivez une aide pour réessayer.")) }
                    if model.trailEnabled, ready, let snapshot = model.snapshot {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.text(!snapshot.isConsistent ? "Une contradiction empêche la piste." : snapshot.deduction == nil ? "Aucune déduction disponible." : "Observez les cases entourées."))
                                .font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted)
                                .accessibilityIdentifier("assistanceStatus")
                            if snapshot.deduction != nil {
                                Button(action: explain) {
                                    Label(L10n.text("Expliquer"), systemImage: "lightbulb")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(LisaTheme.yellow.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                                }
                                .accessibilityIdentifier("assistanceExplain")
                            }
                        }
                    }
                    Divider()
                    if model.isActive {
                        Button { model.hideOverlays(); dismiss() } label: {
                            Label(L10n.text("Masquer les aides"), systemImage: "eye.slash")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .foregroundStyle(LisaTheme.muted)
                        .accessibilityIdentifier("assistanceHide")
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
            .accessibilityIdentifier("assistanceScroll")
        }
        .font(LisaTheme.body(16))
        .foregroundStyle(LisaTheme.ink)
        .tint(LisaTheme.actionInk)
        .buttonStyle(.plain)
    }
}

/// Keep the one-shot note actions distinct from the live visual overlays.
private struct AssistanceNotesActions: View {
    let ready: Bool
    let hasNotes: Bool
    let fill: () -> Void
    let clean: () -> Void
    let clear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: fill) {
                HStack(spacing: 12) {
                    Image(systemName: "pencil.and.list.clipboard").font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("Notes automatiques")).fontWeight(.bold)
                        Text(L10n.text("Complète les cases sans notes. Vos annotations sont conservées."))
                            .font(LisaTheme.body(13)).foregroundStyle(LisaTheme.muted)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(14)
                .background(LisaTheme.yellow.opacity(0.45), in: RoundedRectangle(cornerRadius: 18))
                .opacity(ready ? 1 : 0.5)
            }
            .disabled(!ready)
            .accessibilityIdentifier("assistanceFill")
            DisclosureGroup {
                Button(action: clean) {
                    Label(L10n.text("Nettoyer les notes"), systemImage: "sparkles")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .disabled(!ready || !hasNotes)
                .accessibilityIdentifier("assistanceClean")
                .accessibilityHint(L10n.text("Retire seulement les possibilités devenues impossibles."))
                Button(action: clear) {
                    Label(L10n.text("Effacer toutes les notes"), systemImage: "eraser")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .disabled(!hasNotes)
                .accessibilityIdentifier("assistanceClear")
                Text(L10n.text("Chaque action peut être annulée en un geste."))
                    .font(LisaTheme.body(13)).foregroundStyle(LisaTheme.muted)
            } label: {
                Text(L10n.text("Gérer les notes")).frame(minHeight: 44)
            }
            .padding(.horizontal, 8)
        }
    }
}
