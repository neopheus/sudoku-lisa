# Validation du 5 octobre 2026

Version locale non signée pour distribution, compilée avec Xcode 27 / Swift 6.4, cible minimale iOS 17.

| Vérification | Résultat |
| --- | --- |
| Moteur Swift en Release | 19 tests, aucune erreur |
| iPhone SE 3e génération, simulateur iOS 18.2 | 2 tests d’interface réussis |
| iPhone 16, simulateur iOS 18.5 | 2 tests d’interface réussis |
| Compilation Release arm64 iPhone | Réussie, extension iMessage incluse |
| Taille du bundle Release local | 2 533 316 octets, soit 2,53 Mo décimaux |
| Budget local <100 000 000 octets | Respecté |

Les tests d’interface vérifient la saisie, les notes, l’annulation, la pause, la conservation de la grille après terminaison et relancement du processus, le défi quotidien et la sélection persistante du thème Nuit. Une assertion vérifie que le chiffre 9 est accessible sans défilement. Les captures finales ont été inspectées visuellement : clavier complet sur iPhone SE, réglages sombres, icône originale correctement rendue.

Le moteur couvre notamment unicité des grilles sur les six choix de difficulté, déterminisme, indices, notes, annulation de plus de 600 actions, sérialisation, migration des anciennes sauvegardes et blocage des modifications après victoire.

Les sorties Xcode ne comportent pas d’erreur de compilation. L’avertissement Apple « Metadata extraction skipped, no AppIntents.framework dependency found » concerne l’absence volontaire de raccourcis App Intents. Le précédent avertissement de dimensions négatives lors du premier calcul de mise en page est corrigé ; il n’apparaît plus dans le dernier passage.

## Aperçus réels du simulateur

- [Accueil iPhone 16](screenshots/accueil-iphone16.png)
- [Partie iPhone 16](screenshots/partie-iphone16.png)
- [Clavier complet iPhone SE](screenshots/partie-iphone-se.png)
- [Réglages Nuit](screenshots/reglages-nuit.png)
- [Calendrier quotidien](screenshots/calendrier.png)

## Limites de cette validation

La taille mesurée est celle du bundle Release arm64 local, pas une mesure de téléchargement App Store. La confirmer après signature avec le rapport App Thinning et App Store Connect. Pas de publication ni d’essai sur iPhone physique. Les envois réels de stickers iMessage et les scores Game Center restent à tester sur appareil ; aucun classement Apple n’est provisionné. VoiceOver et Réduire les animations sont pris en compte dans le code, sans certification d’accessibilité ni essai utilisateur complet.

Les événements saisonniers, collections et statistiques sont implémentés mais ne disposent pas encore d’une couverture d’interface exhaustive. Le classement des difficultés combine densité et analyse logique bornée, sans garantir six classes de difficulté parfaitement séparées.

## Reproduire

```sh
swift test -c release --scratch-path /tmp/sudoku-lisa-core-validation
xcodebuild -project SudokuLisa.xcodeproj -scheme SudokuLisa -configuration Release -sdk iphoneos -derivedDataPath /tmp/sudoku-lisa-release-final CODE_SIGNING_ALLOWED=NO build
sh scripts/check_size.sh /tmp/sudoku-lisa-release-final/Build/Products/Release-iphoneos/SudokuLisa.app
```

Utiliser un chemin `.xcresult` neuf pour chaque exécution de tests UI et garder DerivedData ainsi que les rapports hors du dépôt. Les premiers passages réussis restaient bloqués pendant la clôture des rapports lorsque ces fichiers se trouvaient dans la racine du package Swift ; les passages finaux externes se terminent normalement avec `TEST SUCCEEDED`.

Rapport JSON conservé : [ui-tests-summary.json](ui-tests-summary.json). Rapport Xcode de cette session : `/tmp/sudoku-lisa-verified.xcresult`. Bundle iPhone local : `/tmp/sudoku-lisa-release-final/Build/Products/Release-iphoneos/SudokuLisa.app`.
