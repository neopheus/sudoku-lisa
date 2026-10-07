import SudokuCore
import SwiftUI

struct LessonBoardView: View {
  let exercise: SudokuLessonExercise
  @Binding var selectedCell: Int?
  let focusCells: Set<Int>
  let targetCells: Set<Int>
  let results: [CandidateElimination]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(L10n.text("UNE VRAIE GRILLE DE 9 × 9")).font(
        .system(size: 11, weight: .bold, design: .rounded)
      ).tracking(1).foregroundStyle(LisaTheme.muted)
      .accessibilityIdentifier("lesson-board")
      GeometryReader { geometry in
        let side = geometry.size.width / 10
        VStack(spacing: 0) {
          HStack(spacing: 0) {
            Text(" ").frame(width: side, height: side)
            ForEach(1...9, id: \.self) { column in
              Text(String(column)).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted)
                .frame(width: side, height: side).accessibilityHidden(true)
            }
          }
          ForEach(0..<9, id: \.self) { row in
            HStack(spacing: 0) {
              Text(String(row + 1)).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted)
                .frame(width: side, height: side).accessibilityHidden(true)
              ForEach(0..<9, id: \.self) { column in
                let index = row * 9 + column
                LessonBoardCell(
                  index: index, value: exercise.board[index],
                  candidates: exercise.candidates[index],
                  side: side, focused: focusCells.contains(index),
                  target: targetCells.contains(index),
                  selected: selectedCell == index,
                  resultDigits: Set(results.filter { $0.index == index }.map(\.value)),
                  removesCandidates: exercise.removesCandidates
                ) { selectedCell = index }
              }
            }
          }
        }
      }
      .aspectRatio(1, contentMode: .fit)
      Text(
        L10n.text(
          "Violet : cases à comparer. Bord rose : ta sélection. Chiffres barrés : candidats retirés."
        )
      )
      .font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted).fixedSize(
        horizontal: false, vertical: true)
    }
  }
}

private struct LessonBoardCell: View {
  let index: Int
  let value: Int
  let candidates: Set<Int>
  let side: CGFloat
  let focused: Bool
  let target: Bool
  let selected: Bool
  let resultDigits: Set<Int>
  let removesCandidates: Bool
  let select: () -> Void

  private var placedValue: Int {
    value != 0 ? value : removesCandidates ? 0 : resultDigits.sorted().first ?? 0
  }
  private var accessibilityDescription: String {
    let content =
      placedValue != 0
      ? String(placedValue)
      : L10n.text(
        "candidats %@",
        candidates.sorted().map(String.init).formatted(.list(type: .and).locale(L10n.locale)))
    return L10n.text(
      "Ligne %@, colonne %@ : %@", String(index / 9 + 1), String(index % 9 + 1), content)
  }

  var body: some View {
    Button(action: select) {
      ZStack {
        (placedValue != value
          ? LisaTheme.mint
          : target
            ? LisaTheme.yellow.opacity(0.6)
            : focused ? LisaTheme.lavender.opacity(0.55) : LisaTheme.paper)
        if placedValue != 0 {
          Text(String(placedValue)).font(
            .system(size: side * 0.58, weight: value == 0 ? .heavy : .semibold, design: .rounded)
          )
          .foregroundStyle(LisaTheme.ink)
        } else {
          LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 0
          ) {
            ForEach(1...9, id: \.self) { digit in
              Text(candidates.contains(digit) ? String(digit) : " ")
                .font(.system(size: max(8, side * 0.24), weight: .medium, design: .rounded))
                .strikethrough(
                  removesCandidates && resultDigits.contains(digit), color: LisaTheme.coral
                )
                .foregroundStyle(
                  removesCandidates && resultDigits.contains(digit)
                    ? LisaTheme.coral : LisaTheme.muted)
            }
          }
          .padding(2)
        }
        Rectangle().strokeBorder(LisaTheme.line, lineWidth: 0.5)
        if selected { Rectangle().strokeBorder(LisaTheme.coral, lineWidth: 2.5) }
      }
      .frame(width: side, height: side)
      .overlay(alignment: .leading) {
        if index % 3 == 0 {
          Rectangle().fill(LisaTheme.ink).frame(width: 1.5).allowsHitTesting(false)
        }
      }
      .overlay(alignment: .top) {
        if index / 9 % 3 == 0 {
          Rectangle().fill(LisaTheme.ink).frame(height: 1.5).allowsHitTesting(false)
        }
      }
      .overlay(alignment: .trailing) {
        if index % 9 == 8 {
          Rectangle().fill(LisaTheme.ink).frame(width: 1.5).allowsHitTesting(false)
        }
      }
      .overlay(alignment: .bottom) {
        if index / 9 == 8 {
          Rectangle().fill(LisaTheme.ink).frame(height: 1.5).allowsHitTesting(false)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityDescription)
    .accessibilityValue(
      selected
        ? L10n.text("sélectionnée")
        : target ? L10n.text("à résoudre") : focused ? L10n.text("repère") : ""
    )
    .accessibilityHint(L10n.text("Afficher les candidats en grand"))
    .accessibilityIdentifier("lesson-cell-" + String(index))
  }
}
