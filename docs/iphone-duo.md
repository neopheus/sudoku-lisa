# Interface adaptative et iPhone Duo

## Comportement

- En dessous de 600 points de largeur disponible, la grille reste au-dessus des commandes. Le clavier utilise cinq colonnes sur les fenêtres courtes pour garder les neuf chiffres accessibles.
- À partir de 600 points, grille à gauche et clavier à droite. Le dimensionnement dépend de la fenêtre dans sa zone sûre, sans reconnaître un nom de modèle ni supposer une orientation physique. La grille peut atteindre 680 points.
- `AnyLayout` change l’axe sans remplacer l’écran de jeu. Sélection, mode notes, pause et présentations restent dans les mêmes états SwiftUI ; partie et historique d’annulation restent dans `LisaStore`.
- Poulpi passe également à deux colonnes ; la rotation, le zoom et la pose sont conservés. La liste de poses conserve sa propre zone de défilement.
- Les écrans de lecture ont une largeur limitée ; les réglages conservent la présentation système. La pause peut défiler sur une fenêtre courte.
- Le portrait et les deux paysages sont autorisés. iOS 17 reste la version minimale.
- Les animations vérifient leur visibilité par rapport à la fenêtre. La cadence et la densité de rendu utilisent l’écran de la scène, sans `UIScreen.main`.

## Validation locale

Contrôles du 6 octobre 2026 avec Xcode 27.0 :

| Contrôle | Résultat |
| --- | --- |
| `swift test` | 35 tests réussis |
| iPhone 16, iOS 18.5 | 3 tests UI réussis : redimensionnement, Poulpi, sauvegarde/reprise |
| iPhone SE, iOS 18.2 | 2 tests UI réussis : redimensionnement et Poulpi |
| Grande fenêtre, iPad mini A17 Pro, iOS 18.5 | 1 test UI réussi : grille et commandes côte à côte, réglages, Poulpi |
| Release iPhone, signature désactivée | Compilation réussie ; iOS 17 minimum et famille iPhone `[1]` conservés |

Le test UI préalable a bien échoué sur le verrouillage du portrait avant adaptation. Les tests utilisent des simulateurs dédiés et une progression de test réinitialisée.

Le bundle Release local mesuré fait environ 22,75 Mo, sous le budget de 100 Mo. Ce n’est pas une mesure de téléchargement App Store.

Un avertissement SceneKit de capture de `SCNNode` non Sendable était déjà présent avant les changements. Les tests ont aussi émis des diagnostics d’inversion de priorité. Ces résultats fonctionnels ne constituent pas une mesure de fluidité ou d’énergie sur un vrai Duo.

Les tests `AdaptiveLayoutUITests` vérifient sélection, notes, annulation, réglages, pause et caméra de Poulpi au changement de dimensions. Les captures sont jointes aux résultats `.xcresult`. En paysage, les captures utilisent `XCUIScreen.main` ou `simctl io screenshot` : `app.screenshot()` produit un recadrage incorrect avec ces runtimes et ce Xcode.

Un simulateur iPad avec une compilation de contrôle `TARGETED_DEVICE_FAMILY=1,2` peut servir à vérifier une grande fenêtre. Cette surcharge ne modifie pas les cibles du projet distribué et ne constitue pas une validation de l’iPhone Duo.

## Validation spécifique au Duo encore nécessaire

1. Installer Xcode 27.1 et son runtime iOS 27.1, puis choisir le simulateur iPhone Duo dans Device Hub.
2. Recompiler avec le SDK 27.1 pour bénéficier du plein écran prévu pour le Duo.
3. Pendant une partie, sélectionner une case, ajouter des notes, ouvrir et fermer le téléphone plusieurs fois, puis vérifier sélection, notes, chronomètre et annulation.
4. Vérifier les deux orientations, les différentes postures et Split View des deux côtés : grille, touches, réglages et reprise doivent rester visibles hors de la caméra et des éléments système.
5. Contrôler les fenêtres de réglages, les indices, la victoire, l’accueil, le calendrier et Poulpi ; conserver son zoom et sa pose pendant les transitions.
6. Contrôler sur appareil les gestes, VoiceOver, les grandes tailles de texte, Réduire les animations, le mode économie d’énergie et la fluidité.

Ne pas annoncer une validation Duo ou TestFlight sur la seule base des tests de redimensionnement locaux. Aucun envoi App Store Connect n’est inclus dans cette adaptation.

Références Apple : [préparer l’app](https://developer.apple.com/videos/play/tech-talks/111461/), [ressources et Xcode](https://developer.apple.com/iphone-duo/).

## Captures contrôlées

- [Jeu dans une grande fenêtre](screenshots/duo-grande-fenetre.png) — simulateur iPad de contrôle, pas un iPhone Duo.
- [Poulpi et ses commandes côte à côte](screenshots/duo-poulpi-large.png) — même simulateur de contrôle.
- [Jeu sur petit écran en paysage](screenshots/duo-petit-paysage.png) — capture directe du simulateur iPhone SE.

Les résultats structurés et les chemins des rapports locaux sont dans [iphone-duo-validation.json](iphone-duo-validation.json).
