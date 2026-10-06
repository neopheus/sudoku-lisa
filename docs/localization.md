# Localisation

Langues : français (`fr`, langue de développement), anglais (`en`), russe (`ru`), allemand (`de`) et espagnol (`es`). **Réglages → Langue** dans le jeu propose directement Français, English, Русский, Deutsch et Español, ainsi que **Langue de l’iPhone** (choix par défaut). Le changement est immédiat, sans redémarrage ni fermeture des réglages. La préférence est mémorisée dans `UserDefaults` (`lisa.language`) et reste active au prochain lancement.

Les vues observent cette préférence avec `@AppStorage`, sans recréer la navigation ou la partie. Les dates, pluriels, leçons et indices utilisent la langue choisie. L’extension iMessage indépendante suit toujours la langue iOS.

Les textes de l’interface, de Poulpi, de l’apprentissage, des indices, des erreurs, du partage et de VoiceOver passent par `L10n` dans SudokuCore. Les ressources partagées sont dans `Sources/SudokuCore/Resources/<langue>.lproj`. Les descriptions iMessage ont leurs propres ressources dans `Stickers/<langue>.lproj`. Les noms Lisa, Poulpi et Sudoku Lisa restent des noms propres.

- `Localizable.strings` contient les textes et les formats à paramètres `%@`.
- `Localizable.stringsdict` gère les pluriels natifs, dont les formes russes `one`, `few`, `many`, `other`.
- Les dates suivent les formats système. Les en-têtes du calendrier sont localisés et restent alignés sur sa première colonne, le lundi.
- Les valeurs enregistrées des modes (`Libre`, `Quotidien`, `Voyage`, etc.), les clés de date et les graines ne changent pas. Seul leur affichage est traduit : les sauvegardes existantes restent compatibles.

## Vérification

```sh
python3 scripts/localization/check.py
swift test
xcodebuild -project SudokuLisa.xcodeproj -scheme SudokuLisa \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:LisaUITests/LocalizationUITests CODE_SIGNING_ALLOWED=NO test
```

`LocalizationTests` vérifie la sélection manuelle, le retour à la langue système, la couverture, les paramètres et les pluriels, notamment 0, 1, 2, 5, 11, 21, 22, 25 et 111 en russe. Le test UI lance chaque langue, vérifie les onglets et les réglages, ouvre une partie facile et conserve des captures d’écran dans le résultat Xcode.

## Validation du 6 octobre 2026

- Compilation iOS Simulator réussie, application et extension iMessage incluses.
- 34 tests du moteur réussis, dont les deux tests de localisation.
- Parcours UI réussi dans les cinq langues sur iPhone 16 / iOS 18.5 : accueil, réglages et partie facile.
- Captures contrôlées en anglais, espagnol, russe et allemand. Le titre allemand des réglages a été raccourci à « Dein Stil » pour éviter sa troncature.
- Contrôle automatique : 335 clés communes et 4 descriptions de stickers présentes dans les cinq langues.

Exemples : [anglais](screenshots/localization/en-home.png), [espagnol](screenshots/localization/es-home.png), [russe](screenshots/localization/ru-home.png), [partie en allemand](screenshots/localization/de-game.png).

Le test UI `testManualLanguageSelectionPersistsAndPreservesGame` sélectionne les cinq langues dans les réglages, change la langue pendant une partie, relance le jeu avec un système en français, reprend la partie dans la langue choisie, puis revient au choix automatique.

Sélection manuelle validée sur simulateur : les 3 tests unitaires de localisation et le parcours UI de changement/persistance/reprise ont réussi. [Réglages dans le jeu](screenshots/localization/manual-language-picker.png).
