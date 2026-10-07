import SwiftUI
import SudokuCore

struct HintCoachView: View {
    let hint: SudokuHint
    @Binding var stage: Int
    var animationEnabled: Bool
    let close: () -> Void
    let learn: () -> Void
    let apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                LisaMascot(size: 48, mood: .thinking, reactionToken: stage, animationEnabled: animationEnabled)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("Un indice pour comprendre")).font(LisaTheme.heading(17))
                    Text(L10n.text("Étape %@ sur 3", String(describing: stage + 1)))
                        .font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted)
                }
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(LisaTheme.muted)
                }.accessibilityLabel(L10n.text("Fermer"))
            }
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { step in
                    Capsule().fill(step <= stage ? LisaTheme.coral : LisaTheme.line).frame(height: 5)
                }
            }
            Text(stage == 0 ? hint.detail : stage == 1 ? "\(hint.technique). \(hint.explanation)" : deductionSummary(hint))
                .accessibilityIdentifier("hintExplanation")
                .accessibilityValue(stage >= 1 ? eliminationAccessibilityDescription : "")
                .font(LisaTheme.body(15)).fixedSize(horizontal: false, vertical: true).foregroundStyle(LisaTheme.ink)
            if stage == 1, !hint.eliminatedCandidates.isEmpty {
                HStack(spacing: 8) {
                    Text(L10n.text("Candidats à éliminer")).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted)
                    ForEach(hint.eliminatedCandidates, id: \.self) { digit in
                        Text("\(digit)").font(LisaTheme.heading(15)).strikethrough()
                            .foregroundStyle(LisaTheme.coral).padding(7)
                            .background(LisaTheme.coral.opacity(0.12), in: Circle())
                    }
                }
            }
            Button(action: learn) { Label(L10n.text("Comprendre cette technique"), systemImage: "book") }
                .font(LisaTheme.body(14)).accessibilityIdentifier("hintTutorial")
            HStack {
                Spacer()
                if stage < 2 {
                    LisaButton(title: L10n.text("Voir la suite"), icon: "arrow.right") { stage += 1 }
                } else {
                    Button(action: close) {
                        Text(L10n.text("Je continue seul")).font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted).padding(.horizontal, 10)
                    }
                    LisaButton(title: L10n.text("Appliquer cette étape"), icon: "checkmark", action: apply).accessibilityIdentifier("applyHint")
                }
            }
        }
        .padding(18)
        .background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(LisaTheme.line.opacity(0.55), lineWidth: 1))
        .shadow(color: LisaTheme.ink.opacity(0.18), radius: 20, y: 8)
        .padding(.horizontal, 16).padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var eliminationAccessibilityDescription: String {
        hint.eliminationMarks.map { mark in
            L10n.text("Ligne %@, colonne %@ : retirer le candidat %@.", String(mark.index / 9 + 1), String(mark.index % 9 + 1), String(mark.value))
        }.joined(separator: " ")
    }

    private func deductionSummary(_ hint: SudokuHint) -> String {
        guard let deduction = hint.deduction else { return hint.explanation }
        switch deduction.action {
        case let .placement(index, value):
            return L10n.text("La valeur vérifiée est %@, en ligne %@, colonne %@.", String(value), String(index / 9 + 1), String(index % 9 + 1))
        case let .eliminations(marks):
            return L10n.text("Retire les candidats barrés dans les cases colorées (%@ éliminations). Aucun chiffre n’est placé à cette étape.", String(marks.count))
        }
    }

}
