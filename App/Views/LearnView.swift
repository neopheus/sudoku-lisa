import SudokuCore
import SwiftUI

struct LearnView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lessonIndex = 0
    @State private var selectedAnswer: Int?
    @State private var completed = false
    @State private var mascotReaction = 0

    private var lesson: LisaLesson { LisaLesson.all[lessonIndex] }
    private var correct: Bool { selectedAnswer == lesson.answer }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text("UN PETIT DÉCLIC")).font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(2).foregroundStyle(LisaTheme.muted)
                        Text(L10n.text("Apprendre")).font(LisaTheme.heading(36)).foregroundStyle(LisaTheme.ink)
                        Text(L10n.text("La logique, ça se cultive.")).font(LisaTheme.body()).foregroundStyle(LisaTheme.muted)
                    }
                    Spacer(minLength: 0)
                    LisaMascot(size: 65, celebrating: completed, mood: completed || correct ? .happy : selectedAnswer == nil ? .thinking : .encouraging, reactionToken: mascotReaction)
                }
                LisaCard(tint: LisaTheme.lavender.opacity(0.45)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(L10n.text("La règle d’or"), systemImage: "sparkles").font(LisaTheme.heading(19))
                        Text(L10n.text("Place les chiffres de 1 à 9 une seule fois dans chaque ligne, chaque colonne et chaque bloc de 3 × 3 cases."))
                            .font(LisaTheme.body()).fixedSize(horizontal: false, vertical: true)
                        Text(L10n.text("Les chiffres déjà présents ne changent jamais. Pas besoin de calculer : observe et déduis !"))
                            .font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted)
                    }
                }
                HStack(spacing: 7) {
                    ForEach(LisaLesson.all.indices, id: \.self) { index in
                        Capsule().fill(index <= lessonIndex ? LisaTheme.coral : LisaTheme.line).frame(height: 5)
                    }
                }.accessibilityLabel(L10n.text("Leçon %@ sur %@", String(describing: lessonIndex + 1), String(describing: LisaLesson.all.count)))
                VStack(alignment: .leading, spacing: 12) {
                    LisaPill(title: L10n.text("LEÇON %@ / 3", String(describing: lessonIndex + 1)), tint: LisaTheme.yellow)
                    Text(lesson.title).font(LisaTheme.heading(25))
                    Text(lesson.instruction).font(LisaTheme.body()).foregroundStyle(LisaTheme.muted).fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 16) {
                    Text(L10n.text("UN BLOC DE 3 × 3")).font(.system(size: 11, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(LisaTheme.muted)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                        ForEach(0..<9, id: \.self) { index in
                            lessonCell(index)
                        }
                    }
                    .padding(3)
                    .background(LisaTheme.ink, in: RoundedRectangle(cornerRadius: 17))
                    .frame(maxWidth: 270)
                    Text(L10n.text("Quel chiffre va dans la case colorée ?")).font(LisaTheme.heading(16)).multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        ForEach(lesson.choices, id: \.self) { answer in
                            Button {
                                withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { selectedAnswer = answer }
                                mascotReaction += 1
                            } label: {
                                Text("\(answer)")
                                    .font(LisaTheme.heading(27))
                                    .foregroundStyle(selectedAnswer == answer && correct ? LisaTheme.accentInk : LisaTheme.ink)
                                    .frame(maxWidth: .infinity, minHeight: 58)
                                    .background(selectedAnswer == answer ? (correct ? LisaTheme.mint : LisaTheme.coral.opacity(0.35)) : LisaTheme.paper, in: RoundedRectangle(cornerRadius: 17))
                            }
                            .buttonStyle(LisaPressStyle())
                            .accessibilityLabel(L10n.text("Répondre %@", String(describing: answer)))
                            .disabled(correct)
                        }
                    }
                }
                if let selectedAnswer {
                    LisaCard(tint: correct ? LisaTheme.mint.opacity(0.55) : LisaTheme.yellow.opacity(0.4)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(correct ? L10n.text("Bien vu !") : L10n.text("Encore un petit effort"), systemImage: correct ? "checkmark.circle.fill" : "lightbulb")
                                .font(LisaTheme.heading(18))
                            Text(correct ? lesson.explanation : L10n.text("Le %@ ne convient pas. %@", String(describing: selectedAnswer), String(describing: lesson.hint)))
                                .font(LisaTheme.body(15)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if correct {
                    LisaButton(title: lessonIndex == 2 ? L10n.text("J’ai compris !") : L10n.text("La suite"), icon: "arrow.right") {
                        if lessonIndex < LisaLesson.all.count - 1 {
                            lessonIndex += 1
                            selectedAnswer = nil
                        } else {
                            completed = true
                        }
                    }
                }
                if completed {
                    LisaCard(tint: LisaTheme.yellow.opacity(0.4)) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.text("À toi de jouer ✨")).font(LisaTheme.heading(23))
                            Text(L10n.text("Commence en mode facile. Active les notes pour garder les possibilités, puis cherche les cases qui n’en ont plus qu’une.")).font(LisaTheme.body())
                            Button(L10n.text("Revoir les leçons")) { lessonIndex = 0; selectedAnswer = nil; completed = false }
                                .font(LisaTheme.heading(15)).padding(.vertical, 8)
                        }
                    }
                }
                LisaCard {
                    VStack(alignment: .leading, spacing: 13) {
                        Text(L10n.text("Les bons réflexes")).font(LisaTheme.heading(20))
                        tip("pencil", L10n.text("Prends des notes"), L10n.text("Les petits chiffres représentent les possibilités, pas les réponses."))
                        tip("eye", L10n.text("Change de perspective"), L10n.text("Si un bloc te résiste, regarde une ligne ou une colonne."))
                        tip("leaf", L10n.text("Prends ton temps"), L10n.text("La vitesse vient avec la pratique. Chaque déclic compte."))
                    }
                }
            }
            .foregroundStyle(LisaTheme.ink)
            .padding(24)
            .padding(.bottom, 24)
        }
        .background(LisaBackground())
        .navigationTitle(L10n.text("Apprendre"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lessonCell(_ index: Int) -> some View {
        let target = index == lesson.target
        return ZStack {
            RoundedRectangle(cornerRadius: 12).fill(target ? LisaTheme.yellow : LisaTheme.paper)
            if target && correct {
                Text("\(lesson.answer)").font(LisaTheme.heading(31))
            } else if let number = lesson.values[index] {
                Text("\(number)").font(LisaTheme.heading(31))
            } else if let candidates = lesson.candidates[index] {
                Text(candidates.map(String.init).joined(separator: "  "))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(target ? LisaTheme.accentInk.opacity(0.8) : LisaTheme.muted)
            } else {
                Text("?").font(LisaTheme.heading(31))
            }
        }
        .foregroundStyle(target ? LisaTheme.accentInk : LisaTheme.ink)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(L10n.text("Case %@%@ : %@", String(describing: index + 1), String(describing: target ? L10n.text(", à résoudre") : ""), String(describing: lesson.values[index].map(String.init) ?? (correct && target ? String(lesson.answer) : lesson.candidates[index]?.map(String.init).joined(separator: ", ") ?? L10n.text("vide")))))
    }

    private func tip(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 19, weight: .medium)).foregroundStyle(LisaTheme.muted).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(LisaTheme.heading(15))
                Text(detail).font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted)
            }
        }
    }
}

private struct LisaLesson {
    let title: String
    let instruction: String
    let values: [Int?]
    let candidates: [Int: [Int]]
    let target: Int
    let choices: [Int]
    let answer: Int
    let explanation: String
    let hint: String

    static var all: [LisaLesson] { [
        .init(title: L10n.text("Le chiffre manquant"), instruction: L10n.text("Un bloc contient les neuf chiffres. Ici, huit sont déjà placés. Trouve celui qui manque."), values: [1, 2, 3, 4, 5, 6, 7, 8, nil], candidates: [:], target: 8, choices: [6, 9, 3], answer: 9, explanation: L10n.text("Les chiffres de 1 à 8 sont présents. Seul le 9 manque : il va dans la dernière case."), hint: L10n.text("Un chiffre ne peut pas apparaître deux fois dans le même bloc.")),
        .init(title: L10n.text("Une seule possibilité"), instruction: L10n.text("Les petits chiffres sont les candidats, déjà vérifiés avec les lignes et colonnes. Regarde ceux de la case colorée."), values: [1, 2, 3, nil, 5, 6, nil, 8, nil], candidates: [3: [4], 6: [7, 9], 8: [7, 9]], target: 3, choices: [7, 4, 9], answer: 4, explanation: L10n.text("La case n’a plus qu’un candidat : le 4. On appelle cette technique le candidat unique."), hint: L10n.text("La case colorée n’a qu’un petit chiffre. C’est sa seule possibilité.")),
        .init(title: L10n.text("Le chiffre bien caché"), instruction: L10n.text("Cette fois, chaque case vide a plusieurs candidats. Mais l’un des chiffres n’apparaît que dans une seule case du bloc…"), values: [1, 2, 3, 4, 5, 6, nil, nil, nil], candidates: [6: [7, 8], 7: [7, 8, 9], 8: [7, 8]], target: 7, choices: [7, 8, 9], answer: 9, explanation: L10n.text("Le 9 ne peut aller que dans la case du milieu : les deux autres cases ne l’acceptent pas. C’est un chiffre unique caché !"), hint: L10n.text("Compare les candidats des trois cases : où le 9 peut-il aller ?"))
    ] }
}
