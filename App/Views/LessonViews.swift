import SudokuCore
import SwiftUI

private enum LessonStage: Int, CaseIterable, Identifiable {
  case observe, guided, practice
  var id: Int { rawValue }
  var title: String {
    switch self {
    case .observe: L10n.text("Observer")
    case .guided: L10n.text("Avec Lisa")
    case .practice: L10n.text("À toi")
    }
  }
}

struct InteractiveLessonView: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @AccessibilityFocusState private var feedbackFocused: Bool
  let lesson: SudokuLesson
  @State private var stage = LessonStage.observe
  @State private var selectedCell: Int?
  @State private var demonstrationShown = false
  @State private var practiceFocusShown = false
  @State private var successfulAction: CandidateElimination?
  @State private var feedback: String?
  @State private var completed = false

  private var exercise: SudokuLessonExercise {
    stage == .practice ? lesson.practice : lesson.guided
  }
  private var showFocus: Bool {
    stage != .practice || practiceFocusShown || successfulAction != nil
  }
  private var resultActions: [CandidateElimination] {
    if stage == .observe && demonstrationShown { return exercise.demonstrationActions }
    return successfulAction.map { [$0] } ?? []
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(lesson.id.title).font(LisaTheme.heading(25))
        .accessibilityIdentifier("interactive-lesson-" + lesson.id.rawValue)
      (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))) {
        ForEach(LessonStage.allCases) { item in
          Label(item.title, systemImage: stage == item ? "circle.inset.filled" : "circle").font(LisaTheme.body(13)).frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(stage == item ? LisaTheme.yellow : LisaTheme.paper, in: Capsule())
            .foregroundStyle(stage == item ? LisaTheme.accentInk : LisaTheme.muted)
            .accessibilityAddTraits(stage == item ? .isSelected : [])
        }
      }
      LessonInstruction(id: lesson.id, exercise: exercise, stage: stage)
      LessonBoardView(
        exercise: exercise, selectedCell: $selectedCell,
        focusCells: showFocus ? Set(exercise.focusCells) : [],
        targetCells: stage == .guided ? [exercise.target.index] : [],
        results: resultActions)
      if let selectedCell {
        LessonCellDetail(
          index: selectedCell, boardValue: exercise.board[selectedCell],
          candidates: exercise.candidates[selectedCell], results: resultActions,
          removesCandidates: exercise.removesCandidates)
      } else {
        Text(L10n.text("Touche une case pour voir ses candidats en grand."))
          .font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted)
      }
      if stage == .observe {
        Button {
          demonstrationShown.toggle()
        } label: {
          Label(
            L10n.text(demonstrationShown ? "Masquer la déduction" : "Voir la déduction"),
            systemImage: "eye"
          )
          .font(LisaTheme.heading(17)).padding(.vertical, 8)
        }
        if demonstrationShown {
          LessonDeductionSummary(
            actions: exercise.demonstrationActions, removesCandidates: exercise.removesCandidates)
        }
        LisaButton(title: L10n.text("Essayer avec Lisa"), icon: "arrow.right") {
          changeStage(.guided)
        }
      } else {
        LessonNumberPad(
          removesCandidates: exercise.removesCandidates,
          enabled: selectedCell.map { exercise.board[$0] == 0 } ?? false,
          solved: successfulAction != nil
        ) { submit($0) }
        if let feedback {
          LessonFeedback(message: feedback, success: successfulAction != nil)
            .accessibilityFocused($feedbackFocused)
        }
        if successfulAction != nil {
          if stage == .guided {
            LisaButton(title: L10n.text("Essayer seul"), icon: "arrow.right") {
              changeStage(.practice)
            }
          } else if !completed {
            LisaButton(title: L10n.text("J’ai compris !"), icon: "checkmark") { completed = true }
          }
        } else if stage == .practice {
          Button {
            practiceFocusShown = true
            feedback = L10n.text("Regarde les cases en pointillés. %@", lesson.id.explanation)
          } label: {
            Label(L10n.text("Un repère"), systemImage: "lightbulb").font(LisaTheme.heading(15))
          }
        }
      }
      if completed {
        LisaCard(tint: LisaTheme.mint.opacity(0.5)) {
          VStack(alignment: .leading, spacing: 8) {
            Label(L10n.text("Bien vu !"), systemImage: "checkmark.circle.fill").font(
              LisaTheme.heading(20))
            Text(
              L10n.text(
                "Tu as utilisé cette technique sur une autre grille. Retrouve cette leçon quand tu veux dans la bibliothèque."
              )
            )
            .font(LisaTheme.body())
          }
        }
      }
      if stage != .observe {
        Button(L10n.text("Revoir l’explication")) { changeStage(.observe) }.font(
          LisaTheme.heading(15))
      }
      if completed {
        Button(L10n.text("Recommencer cette leçon")) {
          changeStage(.observe)
          demonstrationShown = false
        }
        .font(LisaTheme.heading(15))
      }
    }
  }

  private func changeStage(_ next: LessonStage) {
    stage = next
    selectedCell = next == .guided ? lesson.guided.target.index : nil
    successfulAction = nil
    feedback = nil
    practiceFocusShown = false
    completed = false
  }

  private func submit(_ digit: Int) {
    defer { feedbackFocused = true }
    guard let index = selectedCell, exercise.board[index] == 0 else { return }
    // Guided work asks for a specific cell; independent work accepts every
    // deduction of this technique returned by the shared logical engine.
    let isTarget = stage == .practice || index == exercise.target.index
    if isTarget && exercise.accepts(index: index, value: digit) {
      successfulAction = CandidateElimination(index: index, value: digit)
      feedback = L10n.text("Bien vu ! %@", lesson.id.explanation)
    } else if stage == .guided && !isTarget {
      feedback = L10n.text(
        "Pour cet exercice guidé, commence par la case indiquée : ligne %@, colonne %@.",
        String(exercise.target.index / 9 + 1), String(exercise.target.index % 9 + 1))
    } else if !exercise.candidates[index].contains(digit) {
      feedback =
        exercise.removesCandidates
        ? L10n.text(
          "Ce chiffre n’est pas un candidat de cette case. Choisis un petit chiffre encore présent."
        )
        : L10n.text(
          "Ce chiffre est déjà présent dans la ligne, la colonne ou le bloc. Compare ces trois zones."
        )
    } else {
      feedback =
        exercise.removesCandidates
        ? L10n.text(
          "Cette technique ne permet pas de retirer ce candidat ici. Compare les positions du chiffre et les candidats des cases en pointillés."
        )
        : L10n.text(
          "Ce chiffre est possible, mais cette technique ne prouve pas sa place ici. Cherche une déduction certaine."
        )
    }
  }
}

private struct LessonInstruction: View {
  let id: SudokuLessonID
  let exercise: SudokuLessonExercise
  let stage: LessonStage
  var body: some View {
    LisaCard(tint: LisaTheme.lavender.opacity(0.4)) {
      VStack(alignment: .leading, spacing: 10) {
        Text(stage == .practice ? id.practicePrompt : id.explanation)
          .font(LisaTheme.body()).fixedSize(horizontal: false, vertical: true)
        if stage == .observe {
          Text(
            L10n.text(
              "Les cases en pointillés montrent la zone à comparer. Affiche la déduction pour voir le résultat."
            )
          )
          .font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted)
        } else if stage == .guided {
          Text(
            L10n.text(
              "Sélectionne la case ligne %@, colonne %@. %@", String(exercise.target.index / 9 + 1),
              String(exercise.target.index % 9 + 1),
              exercise.removesCandidates
                ? L10n.text("Quel candidat peux-tu retirer ?")
                : L10n.text("Quel chiffre peux-tu placer ?"))
          )
          .font(LisaTheme.heading(16))
        }
      }
    }
  }
}

private struct LessonDeductionSummary: View {
  let actions: [CandidateElimination]
  let removesCandidates: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      ForEach(actions, id: \.self) { action in
        Text(
          L10n.text(
            removesCandidates
              ? "Ligne %@, colonne %@ : retirer le candidat %@."
              : "Ligne %@, colonne %@ : placer le %@.", String(action.index / 9 + 1),
            String(action.index % 9 + 1), String(action.value))
        )
        .font(LisaTheme.body(14))
      }
    }
  }
}

private struct LessonFeedback: View {
  let message: String
  let success: Bool
  var body: some View {
    LisaCard(tint: success ? LisaTheme.mint.opacity(0.5) : LisaTheme.yellow.opacity(0.35)) {
      Label {
        Text(message).font(LisaTheme.body(15)).fixedSize(horizontal: false, vertical: true)
      } icon: {
        Image(systemName: success ? "checkmark.circle.fill" : "lightbulb")
      }
    }
    .accessibilityIdentifier(success ? "lesson-success" : "lesson-feedback")
    .accessibilityElement(children: .combine)
  }
}

private struct LessonNumberPad: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let removesCandidates: Bool
  let enabled: Bool
  let solved: Bool
  let action: (Int) -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(L10n.text(removesCandidates ? "Retirer un candidat" : "Placer un chiffre")).font(
        LisaTheme.heading(17))
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 3 : 5), spacing: 8)
      {
        ForEach(1...9, id: \.self) { digit in
          Button {
            action(digit)
          } label: {
            Text(String(digit)).font(LisaTheme.heading(25)).frame(
              maxWidth: .infinity, minHeight: 48
            )
            .background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 14))
          }
          .buttonStyle(LisaPressStyle())
          .accessibilityLabel(
            L10n.text(removesCandidates ? "Retirer le candidat %@" : "Placer le %@", String(digit))
          )
          .accessibilityInputLabels([String(digit), L10n.text(removesCandidates ? "Retirer le candidat %@" : "Placer le %@", String(digit))])
          .accessibilityIdentifier("lesson-digit-" + String(digit))
        }
      }
      .disabled(!enabled || solved)
      .opacity(enabled && !solved ? 1 : 0.55)
    }
  }
}

private struct LessonCellDetail: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let index: Int
  let boardValue: Int
  let candidates: Set<Int>
  let results: [CandidateElimination]
  let removesCandidates: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(L10n.text("Ligne %@, colonne %@", String(index / 9 + 1), String(index % 9 + 1))).font(
        LisaTheme.heading(17))
      if boardValue != 0 {
        Text(L10n.text("Chiffre donné : %@", String(boardValue))).font(LisaTheme.body())
      } else {
        Text(L10n.text("Candidats de la case")).font(LisaTheme.body(14)).foregroundStyle(
          LisaTheme.muted)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: dynamicTypeSize.isAccessibilitySize ? 3 : 9), spacing: 5) {
          ForEach(1...9, id: \.self) { digit in
            let possible = candidates.contains(digit)
            let removed =
              removesCandidates
              && results.contains(CandidateElimination(index: index, value: digit))
            Text(String(digit)).font(LisaTheme.heading(18))
              .strikethrough(removed || !possible, color: LisaTheme.actionInk)
              .frame(maxWidth: .infinity, minHeight: 34)
              .background(
                possible ? LisaTheme.yellow.opacity(0.5) : LisaTheme.line.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 8)
              )
              .foregroundStyle(possible ? LisaTheme.ink : LisaTheme.muted.opacity(0.5))
              .accessibilityLabel(
                L10n.text(
                  "%@ : %@", String(digit),
                  removed
                    ? L10n.text("retiré") : possible ? L10n.text("possible") : L10n.text("exclu")))
          }
        }
      }
    }
  }
}
