import XCTest

@testable import SudokuCore

final class LessonTests: XCTestCase {
  func testEveryLessonHasTwoDifferentValidExercisesFromSharedRules() throws {
    let lessons = SudokuLessons.makeLibrary()
    XCTAssertEqual(lessons.map(\.id), SudokuLessonID.allCases)
    for lesson in lessons {
      XCTAssertNotEqual(
        lesson.guided.board, lesson.practice.board, "Practice must use a different context")
      for exercise in [lesson.guided, lesson.practice] {
        XCTAssertEqual(exercise.board.count, 81)
        XCTAssertEqual(SudokuSolver.countSolutions(exercise.board), 1)
        let solution = try XCTUnwrap(SudokuSolver.solve(exercise.board))
        let state = LogicalState(board: exercise.board)
        XCTAssertTrue(state.isConsistent)
        for index in 0..<81 {
          XCTAssertEqual(exercise.candidates[index], state.candidates(at: index))
          XCTAssertEqual(
            exercise.candidates[index], SudokuSolver.candidates(in: exercise.board, at: index))
        }
        let technique: SudokuTechnique =
          lesson.id == .observation ? .nakedSingle : lesson.id.technique
        let deductions = state.deductions(technique: technique)
        XCTAssertFalse(deductions.isEmpty)
        let engineActions = Set(
          deductions.flatMap { deduction -> [CandidateElimination] in
            switch deduction.action {
            case .placement(let index, let value):
              return [CandidateElimination(index: index, value: value)]
            case .eliminations(let marks): return marks
            }
          })
        XCTAssertTrue(exercise.acceptedActions.isSubset(of: engineActions))
        XCTAssertTrue(Set(exercise.demonstrationActions).isSubset(of: exercise.acceptedActions))
        for answer in exercise.acceptedActions {
          XCTAssertTrue(exercise.accepts(index: answer.index, value: answer.value))
          XCTAssertEqual(exercise.board[answer.index], 0)
          XCTAssertTrue(exercise.candidates[answer.index].contains(answer.value))
          if exercise.removesCandidates {
            XCTAssertNotEqual(
              solution[answer.index], answer.value, "A lesson may never eliminate the solution")
          } else {
            XCTAssertEqual(solution[answer.index], answer.value)
          }
        }
        XCTAssertFalse(exercise.accepts(index: -1, value: 1))
        XCTAssertFalse(exercise.accepts(index: exercise.target.index, value: 0))
        for deduction in deductions {
          var updated = state
          XCTAssertTrue(updated.apply(deduction))
          XCTAssertTrue(updated.isConsistent)
          for index in 0..<81 where updated.board[index] == 0 {
            XCTAssertTrue(updated.candidates(at: index).contains(solution[index]))
          }
        }
      }
    }
  }

  func testExamplesTeachTheIntendedDistinctionAndAcceptAlternativeDeductions() throws {
    let lessons = SudokuLessons.makeLibrary()
    let hidden = try XCTUnwrap(lessons.first { $0.id == .hiddenSingle })
    for exercise in [hidden.guided, hidden.practice] {
      XCTAssertGreaterThan(
        exercise.candidates[exercise.target.index].count, 1,
        "A position-unique example must not simply be a naked single")
      XCTAssertGreaterThan(
        exercise.acceptedActions.count, 1,
        "Independent practice must accept alternate valid deductions")
    }
    let naked = try XCTUnwrap(lessons.first { $0.id == .nakedSingle })
    XCTAssertEqual(naked.guided.candidates[naked.guided.target.index].count, 1)
    for unit in LogicalState.units where unit.contains(naked.guided.target.index) {
      XCTAssertGreaterThan(unit.filter { naked.guided.board[$0] == 0 }.count, 1)
    }
    let pair = try XCTUnwrap(lessons.first { $0.id == .nakedPair })
    let pairState = LogicalState(board: pair.guided.board)
    let deduction = try XCTUnwrap(pairState.nextDeduction(technique: .nakedPair))
    XCTAssertEqual(deduction.focusCells.count, 2)
    let possibilities = deduction.focusCells.map { pairState.candidates(at: $0) }
    XCTAssertEqual(possibilities[0].count, 2)
    XCTAssertEqual(possibilities[0], possibilities[1])
    XCTAssertEqual(SudokuLessonID(technique: .lockedCandidates), .lockedCandidates)
    XCTAssertNil(SudokuLessonID(technique: .solutionReveal))
  }
}
