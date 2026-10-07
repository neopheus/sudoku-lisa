import Foundation

public enum SudokuLessonID: String, CaseIterable, Identifiable, Sendable {
  case observation, nakedSingle, hiddenSingle, lockedCandidates, nakedPair
  public var id: String { rawValue }
  public var ordinal: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
  public var title: String {
    switch self {
    case .observation: L10n.text("Observer les lignes, colonnes et blocs")
    case .nakedSingle: L10n.text("Le candidat unique")
    case .hiddenSingle: L10n.text("La position unique")
    case .lockedCandidates: L10n.text("Les candidats verrouillés")
    case .nakedPair: L10n.text("La paire nue")
    }
  }
  public var explanation: String {
    switch self {
    case .observation:
      L10n.text(
        "Chaque ligne, chaque colonne et chaque bloc de 3 × 3 contient les chiffres de 1 à 9 une seule fois. Regarde d’abord une zone presque remplie : quel chiffre manque ? Les numéros autour de la grille t’aident à te repérer."
      )
    case .nakedSingle:
      L10n.text(
        "Les petits chiffres sont les candidats autorisés par la ligne, la colonne et le bloc. Si une case n’en garde qu’un seul, ce chiffre est forcément sa réponse. Compare les trois zones qui traversent cette case."
      )
    case .hiddenSingle:
      L10n.text(
        "Un chiffre peut n’avoir qu’une seule place dans une ligne, une colonne ou un bloc, même si cette case contient plusieurs candidats. Choisis un chiffre et compare toutes ses positions possibles dans la zone."
      )
    case .lockedCandidates:
      L10n.text(
        "Si tous les candidats d’un chiffre dans un bloc sont sur la même ligne ou colonne, ce chiffre sera dans ce bloc sur cette ligne ou colonne. Retire donc ce candidat des autres cases de la ligne ou colonne, à l’extérieur du bloc. La règle marche aussi d’une ligne ou colonne vers un bloc."
      )
    case .nakedPair:
      L10n.text(
        "Dans une même ligne, colonne ou bloc, deux cases qui contiennent exactement les mêmes deux candidats réservent ces deux chiffres. Leur ordre reste inconnu, mais tu peux retirer ces chiffres des autres cases de cette zone."
      )
    }
  }
  public var practicePrompt: String {
    switch self {
    case .observation:
      L10n.text(
        "Trouve une zone presque remplie. Sélectionne sa case vide, puis le chiffre manquant.")
    case .nakedSingle:
      L10n.text("Trouve une case avec un seul candidat. Sélectionne-la, puis place ce chiffre.")
    case .hiddenSingle:
      L10n.text(
        "Trouve un chiffre qui n’a qu’une seule position dans une zone. Sélectionne sa case, puis place-le."
      )
    case .lockedCandidates:
      L10n.text(
        "Repère des candidats verrouillés. Sélectionne une case où un candidat peut être retiré, puis ce candidat."
      )
    case .nakedPair:
      L10n.text(
        "Repère une paire nue. Sélectionne une autre case de la même zone, puis un candidat à retirer."
      )
    }
  }
  public var removesCandidates: Bool { self == .lockedCandidates || self == .nakedPair }
}

/// Prepared once outside the UI: candidate sets and accepted answers come from
/// the exact deduction rules used by hints and human difficulty evaluation.
public struct SudokuLessonExercise: Sendable {
  public let board: [Int]
  public let candidates: [Set<Int>]
  public let focusCells: [Int]
  public let demonstrationActions: [CandidateElimination]
  public let acceptedActions: Set<CandidateElimination>
  public let removesCandidates: Bool
  public var target: CandidateElimination { demonstrationActions[0] }
  public func accepts(index: Int, value: Int) -> Bool {
    acceptedActions.contains(CandidateElimination(index: index, value: value))
  }
}

public struct SudokuLesson: Identifiable, Sendable {
  public let id: SudokuLessonID
  public let guided: SudokuLessonExercise
  public let practice: SudokuLessonExercise
}

public enum SudokuLessons {
  public static func makeLibrary() -> [SudokuLesson] {
    SudokuLessonID.allCases.compactMap { id in
      guard !Task.isCancelled else { return nil }
      guard let guided = makeExercise(id: id, practice: false),
        let practice = makeExercise(id: id, practice: true)
      else { return nil }
      return SudokuLesson(id: id, guided: guided, practice: practice)
    }
  }
}

extension SudokuLessonID {
  public init?(technique: SudokuTechnique) {
    switch technique {
    case .observation: self = .observation
    case .nakedSingle: self = .nakedSingle
    case .hiddenSingle: self = .hiddenSingle
    case .lockedCandidates: self = .lockedCandidates
    case .nakedPair: self = .nakedPair
    default: return nil
    }
  }
  public var technique: SudokuTechnique {
    switch self {
    case .observation: .observation
    case .nakedSingle: .nakedSingle
    case .hiddenSingle: .hiddenSingle
    case .lockedCandidates: .lockedCandidates
    case .nakedPair: .nakedPair
    }
  }
}

extension SudokuLessons {
  private static func makeExercise(id: SudokuLessonID, practice: Bool) -> SudokuLessonExercise? {
    var board = fixture(for: id)
    if practice { board = transformed(board) }
    let state = LogicalState(board: board)
    let candidates = (0..<81).map { state.candidates(at: $0) }
    let technique: SudokuTechnique = id == .observation ? .nakedSingle : id.technique
    let allDeductions = state.deductions(technique: technique)
    var deductions = allDeductions
    // Select a pedagogically useful example: a hidden single really has
    // several candidates, while a naked single needs intersecting zones.
    if id == .hiddenSingle {
      deductions = deductions.filter { deduction in
        if case .placement(let index, _) = deduction.action { return candidates[index].count > 1 }
        return false
      }
    }
    if id == .nakedSingle {
      let crossing = deductions.filter { deduction in
        guard case .placement(let index, _) = deduction.action else { return false }
        return LogicalState.units.filter { $0.contains(index) }.allSatisfy {
          $0.filter { board[$0] == 0 }.count > 1
        }
      }
      if !crossing.isEmpty { deductions = crossing }
    }
    guard let first = deductions.first else { return nil }
    func actions(_ deduction: SudokuDeduction) -> [CandidateElimination] {
      switch deduction.action {
      case .placement(let index, let value): [CandidateElimination(index: index, value: value)]
      case .eliminations(let marks): marks
      }
    }
    let demonstrated = actions(first)
    guard !demonstrated.isEmpty else { return nil }
    let focus =
      id == .observation
      ? LogicalState.units[demonstrated[0].index / 9]
      : first.focusCells
    return SudokuLessonExercise(
      board: board, candidates: candidates, focusCells: focus,
      demonstrationActions: demonstrated,
      acceptedActions: Set(allDeductions.flatMap(actions)),
      removesCandidates: id.removesCandidates)
  }

  /// Real, unique-solution boards, checked by LessonTests. No invented notes.
  /// The second exercise changes orientation and digits while preserving all
  /// Sudoku units, so learners practice the rule in a different context.
  private static func fixture(for id: SudokuLessonID) -> [Int] {
    let string: String
    switch id {
    case .observation:
      string = "091385724853427961274169583129536847487912635365748219516873492942651378738294156"
    case .nakedSingle, .hiddenSingle, .lockedCandidates:
      string = "000300020000027901070100083100506000080002035000700009506873092040050000700000006"
    case .nakedPair:
      string = "000000000150638070036470201028900007009000000740000063697500000003700000010002090"
    }
    return string.compactMap(\.wholeNumberValue)
  }
  private static func transformed(_ board: [Int]) -> [Int] {
    var result = Array(repeating: 0, count: 81)
    for index in 0..<81 {
      let row = (index % 9 + 3) % 9
      let column = (index / 9 + 3) % 9
      let digit = board[index]
      result[row * 9 + column] = digit == 0 ? 0 : (digit + 3) % 9 + 1
    }
    return result
  }
}
