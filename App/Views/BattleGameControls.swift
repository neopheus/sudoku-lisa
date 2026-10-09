import SwiftUI
import SudokuCore

struct BattleBoard: View {
    let game: GameSession
    let selection: Int?
    let width: CGFloat
    let onSelect: (Int) -> Void
    @EnvironmentObject private var store: LisaStore
    @ObservedObject private var battle = BattleService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        let inner = max(9, width - 16)
        let side = inner / 9
        let peers = selection.map { SudokuSolver.peers(of: $0) } ?? []
        ZStack {
            VStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { column in
                            let index = row * 9 + column
                            let same = sameNumber(index)
                            let peer = store.settings.highlightPeers && index != selection && peers.contains(index)
                            let duplicate = store.settings.highlightDuplicates && battle.boardSummary.duplicates.contains(index)
                            let wrong = store.settings.autoCheck && game.isIncorrect(at: index)
                            Button { onSelect(index) } label: {
                                SudokuCellContent(value: game.values[index], notes: game.notes[index],
                                    given: game.puzzle.givens[index] != 0, wrong: wrong,
                                    duplicate: duplicate, isSelected: selection == index,
                                    sameNumber: same, peer: peer, inHintFocus: false, marks: [], side: side,
                                    colorScheme: colorScheme, differentiateWithoutColor: differentiate).equatable()
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("battleCell-\(index)")
                            .accessibilityLabel(cellLabel(index, same: same, peer: peer, duplicate: duplicate, wrong: wrong))
                            .accessibilityInputLabels([L10n.text("Case %@ %@", String(row + 1), String(column + 1))])
                            .accessibilityValue(selection == index ? L10n.text("Sélectionnée") : "")
                            .accessibilityAddTraits(selection == index ? .isSelected : [])
                        }
                    }
                }
            }
            Path { path in
                for n in 0...9 {
                    let point = CGFloat(n) * side
                    path.move(to: CGPoint(x: point, y: 0)); path.addLine(to: CGPoint(x: point, y: inner))
                    path.move(to: CGPoint(x: 0, y: point)); path.addLine(to: CGPoint(x: inner, y: point))
                }
            }.stroke(LisaTheme.actionInk.opacity(0.2), lineWidth: 0.5).allowsHitTesting(false)
            Path { path in
                for n in stride(from: 0, through: 9, by: 3) {
                    let point = CGFloat(n) * side
                    path.move(to: CGPoint(x: point, y: 0)); path.addLine(to: CGPoint(x: point, y: inner))
                    path.move(to: CGPoint(x: 0, y: point)); path.addLine(to: CGPoint(x: inner, y: point))
                }
            }.stroke(LisaTheme.actionInk.opacity(0.65), lineWidth: 2).allowsHitTesting(false)
        }
        .frame(width: inner, height: inner).background(LisaTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8)).padding(8)
        .background(LisaTheme.lavender, in: RoundedRectangle(cornerRadius: 16))
    }

    private func sameNumber(_ index: Int) -> Bool {
        let value = game.values[index]
        guard value != 0 else { return false }
        if let lockedDigit = battle.lockedDigit { return value == lockedDigit }
        return selection.map { game.values[$0] == value } ?? false
    }

    private func cellLabel(_ index: Int, same: Bool, peer: Bool, duplicate: Bool, wrong: Bool) -> String {
        let notes = game.notes[index].sorted().map(String.init).formatted(.list(type: .and).locale(L10n.locale))
        return L10n.text("Ligne %@, colonne %@, %@%@%@%@", String(index / 9 + 1), String(index % 9 + 1),
            game.values[index] == 0 ? L10n.text("vide") : String(game.values[index]),
            game.puzzle.givens[index] != 0 ? L10n.text(", chiffre donné") : "",
            notes.isEmpty ? "" : L10n.text(", notes ") + notes,
            wrong ? L10n.text(", erreur") : "")
            + (same && index != selection ? L10n.text(", chiffre mis en évidence") : "")
            + (peer ? L10n.text(", même ligne, colonne ou carré que la sélection") : "")
            + (duplicate ? L10n.text(", doublon") : "")
    }
}

struct BattleKeypad: View {
    @ObservedObject var battle: BattleService
    let canUndo: Bool
    @EnvironmentObject private var store: LisaStore
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 12) {
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))) {
                Button { battle.undo() } label: { Label(L10n.text("Annuler"), systemImage: "arrow.uturn.backward") }
                    .disabled(!canUndo).accessibilityIdentifier("battleUndo")
                Spacer(minLength: 0)
                Button { battle.erase() } label: { Label(L10n.text("Effacer"), systemImage: "eraser") }
                    .disabled(battle.selection.map { battle.session?.isEditable($0) == true } != true)
                    .accessibilityIdentifier("battleErase")
                Spacer(minLength: 0)
                Button { battle.notesMode.toggle() } label: {
                    Label(L10n.text("Notes"), systemImage: battle.notesMode ? "pencil.circle.fill" : "pencil.circle")
                }
                .accessibilityValue(L10n.text(battle.notesMode ? "Activées" : "Désactivées"))
                .accessibilityAddTraits(battle.notesMode ? .isSelected : [])
                .accessibilityIdentifier("battleNotes")
            }.font(.subheadline).buttonStyle(.bordered).controlSize(.small)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize >= .accessibility3 ? 2 : 3), spacing: 8) {
                ForEach(1...9, id: \.self) { value in
                    let remaining = battle.boardSummary.remaining[value - 1]
                    Button { if store.settings.numberFirst || battle.lockedDigit != nil { battle.lockDigit(value) } else { battle.enter(value) } } label: {
                        VStack(spacing: 1) {
                            HStack(spacing: 4) {
                                Text("\(value)").font(.title2.bold())
                                if remaining == 0 {
                                    Image(systemName: "checkmark.circle.fill").font(.caption)
                                }
                            }
                            Text(L10n.count("remaining", remaining))
                                .font(.caption2.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(remaining == 0 ? LisaTheme.muted : LisaTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 68 : 48)
                        .background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(battle.lockedDigit == value ? LisaTheme.ink : .clear, lineWidth: 2))
                    }
                    .accessibilityIdentifier("battleDigit-\(value)")
                    .accessibilityLabel("\(value), " + L10n.count("remaining", remaining))
                    .accessibilityInputLabels([String(value)])
                    .accessibilityAction(named: Text(L10n.text("Verrouiller ce chiffre"))) { battle.lockDigit(value) }
                    .accessibilityAddTraits(battle.lockedDigit == value ? .isSelected : [])
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in battle.lockDigit(value) })
                }
            }
            if let digit = battle.lockedDigit {
                Button { battle.unlockDigit() } label: {
                    Label(L10n.text("Chiffre %@ verrouillé · Libérer", String(digit)), systemImage: "lock.open")
                        .font(.caption)
                }.accessibilityIdentifier("battleUnlockDigit")
            }
            if battle.notesMode && !typeSize.isAccessibilitySize {
                Label(L10n.text("Mode notes · Touchez une case puis un chiffre."), systemImage: "pencil.tip")
                    .font(.caption).foregroundStyle(LisaTheme.muted)
                    .accessibilityIdentifier("battleNotesBanner")
            }
        }
        .onChange(of: store.settings.numberFirst) { _, _ in battle.unlockDigit() }
        .disabled(!battle.canEdit)
    }
}
