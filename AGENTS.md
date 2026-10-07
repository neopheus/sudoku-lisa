# Lisa Sudoku

- App native SwiftUI, iOS 17 minimum ; règles et types partageables dans `Sources/SudokuCore`, interface et orchestration dans `App`.
- Préserver les modifications existantes. Aucun commit, push ou déploiement sans demande explicite. Aucun trailer Codex ni attribution automatique dans les commits/PR.
- Mutualiser les déductions entre difficulté, indices et tutoriels. Une grille annoncée à un niveau doit satisfaire son profil logique ; ne pas confondre solution calculée et explication humaine.
- Préserver et tester la migration des sauvegardes, notes, annulations et contextes de partie. Ne jamais écraser une sauvegarde illisible.
- Génération et analyses hors du thread principal, avec concurrence bornée, annulation et limite de travail. Pas de calcul coûteux dans `body` ni de cache sans borne.
- Respecter Réduire les animations et suspendre les animations/tâches hors écran ou en arrière-plan. Conserver la localisation via `L10n` et les identifiants d’accessibilité.
- Validation moteur : `swift test`. Validation iOS : `xcodebuild -project SudokuLisa.xcodeproj -scheme SudokuLisa -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath /tmp/lisa-validation CODE_SIGNING_ALLOWED=NO test`.
- Garder DerivedData et `.xcresult` hors du dépôt. Les tests UI avec `--uitest-reset` effacent la progression de l’installation de test : utiliser un simulateur dédié.
- Consulter `xcode-skills/swiftui-specialist/SKILL.md` pour SwiftUI. Ajouter des tests métier et de migration pertinents ; compiler, tester, relire, corriger avant livraison.
- Distinguer mesures locales/simulateur, mesures sur iPhone, bénéfices supposés et essais joueurs. Ne pas annoncer un gain batterie/GPU sans mesure adaptée.
