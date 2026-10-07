import SudokuCore
import SwiftUI

/// Always available from the library; a hint can open the matching lesson directly.
struct LearnView: View {
  @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.lisaMotionAllowed) private var motionAllowed
  @State private var selectedLesson: SudokuLessonID?
  @State private var lessons: [SudokuLesson] = []
  @State private var loadingFailed = false
  private let initialTechnique: SudokuTechnique?

  init(initialTechnique: SudokuTechnique? = nil) {
    self.initialTechnique = initialTechnique
    _selectedLesson = State(initialValue: initialTechnique.flatMap(SudokuLessonID.init(technique:)))
  }

  var body: some View {
    NavigationStack {
      ScrollViewReader { reader in
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            LessonLibraryHeader()
            if let technique = initialTechnique, SudokuLessonID(technique: technique) == nil {
              AdvancedTechniqueExplanation(technique: technique)
            }
            LessonLibraryPicker(selection: $selectedLesson)
            VStack(alignment: .leading, spacing: 20) {
              if let selectedLesson, let lesson = lessons.first(where: { $0.id == selectedLesson })
              {
                InteractiveLessonView(lesson: lesson).id(lesson.id)
              } else if loadingFailed {
                Text(
                  L10n.text("Les exercices sont indisponibles. Rouvre cette page pour réessayer.")
                )
                .font(LisaTheme.body()).foregroundStyle(LisaTheme.muted)
              } else if lessons.isEmpty {
                ProgressView(L10n.text("Préparation des exercices…"))
              } else {
                LisaCard(tint: LisaTheme.lavender.opacity(0.45)) {
                  VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.text("Cinq déclics, à ton rythme")).font(LisaTheme.heading(23))
                    Text(
                      L10n.text(
                        "Choisis une leçon. Observe une vraie grille, fais une déduction avec Lisa, puis essaie seul sur un autre exemple. Tu peux revenir ici à tout moment."
                      )
                    )
                    .font(LisaTheme.body()).fixedSize(horizontal: false, vertical: true)
                  }
                }
              }
            }
            .id("lesson-content")
          }
          .foregroundStyle(LisaTheme.ink)
          .frame(maxWidth: 640)
          .padding(20)
          .frame(maxWidth: .infinity)
          .padding(.bottom, 24)
        }
        .onChange(of: selectedLesson) { _, _ in
          withAnimation(
            reduceMotion || !motionAllowed || scenePhase != .active
              ? nil : .easeInOut(duration: 0.2)
          ) {
            reader.scrollTo("lesson-content", anchor: .top)
          }
        }
        .onChange(of: lessons.count) { _, _ in
          if selectedLesson != nil { reader.scrollTo("lesson-content", anchor: .top) }
        }
      }
      .background(LisaBackground(motionEnabled: false, quiet: true))
      .navigationTitle(L10n.text("Apprendre"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(L10n.text("Fermer")) { dismiss() }
            .accessibilityIdentifier("lesson-close")
        }
      }
      .environment(\.lisaMotionAllowed, motionAllowed && !reduceMotion && scenePhase == .active)
      .task {
        guard lessons.isEmpty, !loadingFailed else { return }
        let preparation = Task.detached(priority: .userInitiated) { SudokuLessons.makeLibrary() }
        let prepared = await withTaskCancellationHandler {
          await preparation.value
        } onCancel: {
          preparation.cancel()
        }
        guard !Task.isCancelled else { return }
        lessons = prepared
        loadingFailed = prepared.count != SudokuLessonID.allCases.count
      }
    }
  }
}

private struct LessonLibraryHeader: View {
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 8) {
        Text(L10n.text("UN PETIT DÉCLIC")).font(LisaTheme.heading(11))
          .tracking(2).foregroundStyle(LisaTheme.muted)
        Text(L10n.text("Apprendre")).font(LisaTheme.heading(36))
        Text(L10n.text("La logique, ça se cultive.")).font(LisaTheme.body()).foregroundStyle(
          LisaTheme.muted)
      }
      Spacer(minLength: 0)
      LisaMascot(size: 58, mood: .thinking)
    }
  }
}

private struct LessonLibraryPicker: View {
  @Binding var selection: SudokuLessonID?
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(SudokuLessonID.allCases) { lesson in
        Button {
          selection = lesson
        } label: {
          HStack(spacing: 12) {
            Text(String(lesson.ordinal)).font(LisaTheme.heading(17))
              .padding(8).frame(minWidth: 32, minHeight: 32).background(LisaTheme.yellow, in: Circle())
              .foregroundStyle(LisaTheme.accentInk)
            Text(lesson.title).font(LisaTheme.heading(16)).multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            Image(systemName: selection == lesson ? "checkmark.circle.fill" : "chevron.right")
          }
          .padding(12)
          .background(
            selection == lesson ? LisaTheme.mint.opacity(0.45) : LisaTheme.paper,
            in: RoundedRectangle(cornerRadius: 18)
          )
          .foregroundStyle(LisaTheme.ink)
        }
        .buttonStyle(LisaPressStyle())
        .accessibilityInputLabels([lesson.title])
        .accessibilityIdentifier("lesson-" + lesson.rawValue)
        .accessibilityAddTraits(selection == lesson ? .isSelected : [])
      }
    }
  }
}

private struct AdvancedTechniqueExplanation: View {
  let technique: SudokuTechnique
  var body: some View {
    LisaCard(tint: LisaTheme.lavender.opacity(0.45)) {
      VStack(alignment: .leading, spacing: 12) {
        Label(technique.label, systemImage: "lightbulb.fill").font(LisaTheme.heading(23))
        Text(technique.explanation).font(LisaTheme.body()).fixedSize(horizontal: false, vertical: true)
        Text(L10n.text("Cette technique n’a pas encore d’exercice interactif. La bibliothèque propose cinq leçons pour pratiquer les bases, les candidats verrouillés et les paires nues."))
          .font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted).fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityIdentifier("advanced-technique-explanation")
  }
}
