import Foundation
@main struct Check {
 static func solutionCount(_ clues: [Int]) -> Int {
  var cells = clues
  var count = 0
  func search() {
   guard count < 2 else { return }
   guard let index = cells.firstIndex(of: 0) else { count += 1; return }
   for value in 1...4 {
    let conflict = cells.indices.contains { other in
     cells[other] == value && (other / 4 == index / 4 || other % 4 == index % 4 || (other / 8 == index / 8 && other % 4 / 2 == index % 4 / 2))
    }
    if !conflict { cells[index] = value; search(); cells[index] = 0 }
   }
  }
  search()
  return count
 }
 static func main() {
  for _ in 0..<200 {
   var game = MiniSudoku()
   assert(solutionCount(game.clues) == 1)
   for i in 0..<16 { assert((1...4).contains(game.solution[i])); if game.clues[i] != 0 { let before=game.cells; game.set(0, at:i); assert(game.cells == before) } }
   for row in 0..<4 { assert(Set(game.solution[(row*4)..<(row*4+4)]).count == 4) }
   for column in 0..<4 { assert(Set((0..<4).map {game.solution[$0*4+column]}).count == 4) }
   for start in [0,2,8,10] {assert(Set([start,start+1,start+4,start+5].map {game.solution[$0]}).count == 4)}
   let editable=(0..<16).first { game.isEditable($0) }!; let before=game.cells;game.set(game.solution[editable],at:editable);game.undo();assert(game.cells==before)
   for i in 0..<16 where game.isEditable(i) {game.set(game.solution[i],at:i)};assert(game.isComplete)
   assert(!(0..<16).contains {game.hasConflict($0)})
   let sameRow=(editable/4*4)..<(editable/4*4+4);let peer=sameRow.first {$0 != editable}!;game.set(game.cells[peer],at:editable);assert(game.hasConflict(editable));assert(!game.isComplete)
  }
  print("MiniSudoku: 200 randomized games, unique solution, clue safety, row/column/box validity, undo, completion and conflicts passed")
 }
}
