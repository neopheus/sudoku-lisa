# Lisa Sudoku — améliorations du 7 octobre 2026

## Fonctionnalités livrées

1. **Déductions communes** : le moteur retourne un placement ou des éliminations atomiques, avec technique stable, cases concernées et explication. Résolution logique, classement, indices et exercices utilisent les mêmes règles.
2. **Difficultés vérifiables** : Express = candidats uniques ; Facile = positions uniques ; Moyen = candidats verrouillés ; Difficile = paires nues ; Expert = paires cachées/triplets nus ; Maître = triplets cachés/X-Wing. Le chemin de résolution doit aboutir et correspondre au profil annoncé.
3. **Indices progressifs** : observer, comprendre, puis appliquer l’étape. Une erreur n’expose plus immédiatement sa correction. Les éliminations sont persistées et annulables, distinctes des notes manuscrites. Les anciennes grilles hors du répertoire logique peuvent proposer une valeur vérifiée, explicitement sans explication logique.
4. **Cinq tutoriels** : observation, candidat unique, position unique, candidats verrouillés et paire nue. Bibliothèque disponible sans déblocage ; accès depuis le jeu et l’indice ; démonstration, pratique guidée puis autonome sur une autre grille. Les réponses alternatives valides sont acceptées. Les techniques au-delà de ces cinq exercices disposent d’une explication, sans exercice interactif dédié.
5. **Continuité** : une sauvegarde par mode existant, avec identité du défi, notes, éliminations, historique d’annulation et temps. Les autres parties sont accessibles à l’accueil. Les changements entre modes ne détruisent plus la partie précédente ; un remplacement dans le même mode Libre/Quotidien reste explicite.
6. **Après la victoire** : autre grille au même niveau, étape suivante du Voyage, prochain défi du même événement. Les limites de 25/10 étapes sont respectées. Une préparation annulée/échouée conserve la grille terminée et permet de réessayer.
7. **Saisie** : pavé stable à trois colonnes, préférence chiffre avant case, verrouillage par appui long et bouton de déverrouillage, bandeau distinct pour les notes.
8. **Poulpi** : souvenir étoilé après cinq étapes du Voyage, équipement facultatif persistant, droit rétroactif pour les anciennes progressions. Ornement SwiftUI statique réutilisé sur le compagnon et son écran, sans ajout de géométrie 3D.

Les textes ajoutés sont disponibles en français, anglais, allemand, espagnol et russe. Aucun nouveau mode, classement, achat ou mécanisme de série punitive n’a été ajouté. Aucun commit, push ou déploiement effectué.

## Architecture et maîtrise des ressources

- Corpus de **64 originaux** à solution unique, validés par les tests : huit par technique de génération. Les niveaux Expert et Maître disposent chacun de deux familles, soit seize originaux par niveau.
- Transformations de lignes/bandes, colonnes/piles, chiffres et transposition, avec nouvelle analyse du profil. Maximum **12 essais**, puis repli déterministe sur l’original validé. Pas de recherche d’unicité coûteuse pendant la préparation dans l’app.
- Génération hors du thread principal, un seul travail effectif à la fois. Annulation coopérative, contrôle de l’identité de requête et délai de deux secondes. Le dépassement de délai échoue sans changer la partie ; il ne produit pas une grille différente selon la vitesse de l’appareil pour la même graine.
- Calcul des indices dans un acteur dédié ; un seul résultat courant, aucun cache global. Les cases/candidats d’aide sont préparés une fois. Un résultat ne peut être appliqué à une grille modifiée.
- Le chronomètre possède son propre objet observable ; sa tâche est suspendue pendant pause, aide, leçon, réglages et arrière-plan. Les snapshots périodiques ne publient plus de changement de toute la vue de jeu.
- Les tâches de génération, préparation de leçons et indices sont annulées lorsqu’elles deviennent inutiles. Le chargement des leçons reste borné à dix petites grilles.
- La continuation conserve l’identité de la vue de jeu et de sa scène. Un changement de puzzle réinitialise les seules sélections, aides et célébrations, sans les confondre avec des réussites sur la nouvelle grille.
- La sauvegarde historique reste lisible ; aucune réécriture à l’ouverture avant restauration complète. Une sauvegarde illisible reste protégée. Les nouveaux snapshots conservent un maximum de cinq contextes, un par mode.

## Vérifications exécutées

| Vérification | Résultat |
| --- | --- |
| Suite complète `SudokuCore`, Swift Release | **53 tests réussis**, zéro échec |
| Tests applicatifs sur iPhone 16 simulé/iOS 18.5 | **18 réussis**, dont migration, annulation, concurrence, récompense et indices asynchrones |
| Nouveaux parcours UI sur iPhone 16 simulé | **5 réussis** |
| Parcours aide, saisie et récompense sur iPhone SE simulé/iOS 18.2 | **3 réussis** |
| Régression existante saisie/notes/annulation/pause/reprise | Réussie sur iPhone 16 simulé |
| Régression après conservation de la scène | Continuation, pavé actif et sélection réinitialisée : réussie sur iPhone 16 simulé |
| Compilation Release finale pour iPhone, sans signature | **Réussie**, après la correction de continuité |
| Catalogues de traduction et exemples pédagogiques | Contrôles inclus dans la suite moteur, cinq catalogues valides |

Les parcours UI couvrent : Voyage sauvegardé, lancement du quotidien puis redémarrage et reprise exacte des notes ; accès au tutoriel depuis l’aide puis retour sans modification de grille ; trois étapes de l’indice et application ; saisie chiffre d’abord et notes ; bibliothèque des cinq leçons et exercice d’observation entièrement réalisé ; victoire, équipement du souvenir et continuation.

Les premières exécutions UI ont permis de corriger les requêtes de test, les identifiants d’accessibilité hérités des conteneurs et le panneau d’aide qui masquait des cases. Les captures finales ont été inspectées, notamment sur l’écran compact du SE. Le jeu reste consultable au-dessus du panneau d’aide ; l’édition est désactivée pendant le coaching. VoiceOver dispose des coordonnées et candidats éliminés.

Commandes utilisées (adapter les UUID et les chemins temporaires) :

```sh
swift test -c release --scratch-path /tmp/lisa-logic-release-build
xcodebuild -project SudokuLisa.xcodeproj -scheme SudokuLisa \
  -destination 'platform=iOS Simulator,id=F60920A4-E595-4FAD-9DD0-C7FC876233A7' \
  -derivedDataPath /tmp/lisa-store-20261007 CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:LisaStoreTests \
  -only-testing:LisaUITests/GameplayImprovementUITests test
```

Artefacts locaux : `/tmp/lisa-gameplay-final-20261007.xcresult`, `/tmp/lisa-gameplay-se-20261007.xcresult`. Les artefacts dans `/tmp` ne sont pas pérennes. Les anciens documents et préférences du simulateur SE QA ont été sauvegardés puis restaurés après les tests.

## Mesures et limites

Le [journal complet du moteur](gameplay-validation/core-release.log) et les [mesures structurées](gameplay-validation/metrics.json) sont conservés dans le dépôt.

Mesures Swift Release **sur Mac**, 240 grilles (graines 0 à 39 pour chacun des six niveaux), sans extrapolation vers un iPhone :

| Travail | Médiane | Maximum observé |
| --- | ---: | ---: |
| Préparation d’une grille | 0,339 ms | 0,815 ms |
| Premier indice | 0,077 ms | 0,548 ms |

Chaque niveau produit 40 grilles distinctes dans cet échantillon, toutes classées dans le profil attendu. Les tests vérifient aussi l’unicité des 64 originaux et la validité des actions. Les transformations préservent mathématiquement l’unicité.

Le moteur expose également le nombre de placements, d’étapes et de candidats éliminés, la fréquence de la technique maximale et la plus longue chaîne d’éliminations. Dans l’échantillon, cette chaîne va de 1 à 6 pour Moyen, de 1 à 7 pour Difficile, de 2 à 6 pour Expert et de 1 à 12 pour Maître. **Les plages se recouvrent** : le niveau technique est vérifié, mais l’effort et le temps ressentis ne sont pas encore calibrés auprès de joueurs. Aucun seuil d’effort arbitraire n’a été ajouté.

Instruments Time Profiler est accessible. Une première capture de 8,59 secondes, sur l’app **Debug sous automatisation UI** dans le simulateur iPhone 16, a enregistré un microblocage de 348,9 ms pendant la transition de victoire. Les échantillons impliquent principalement SwiftUI/AttributeGraph et incluent la construction d’une nouvelle scène. La reconstruction forcée de `GameView` a été retirée ; le test final de continuation confirme une grille jouable et une sélection réinitialisée après cette correction. La tentative de seconde capture n’a pas pu s’attacher au processus, encore absent à cet instant : aucune réduction du microblocage n’est donc chiffrée. Ce relevé isolé n’est pas une mesure de consommation réelle ni une preuve de gain CPU/GPU. Instruments signale par ailleurs une table sans source connue ; la trace reste exportable et lisible.

La compilation finale conserve un avertissement de concurrence SceneKit dans `OctopusScene.swift` (capture de `SCNNode` non-Sendable) et le message de métadonnées AppIntents non applicables. La compilation réussit ; cela ne vaut pas validation complète du mode strict Swift 6.

Les contraintes d’espace disque ont interrompu une tentative de compilation et le démarrage d’un nouveau simulateur. Seuls les sorties temporaires et le simulateur créés pour cette intervention ont été nettoyés ; les validations ont ensuite repris sur les simulateurs QA. Aucun fichier utilisateur ou cache partagé n’a été supprimé.

### Ce qui reste à mesurer

- Batterie, chauffe, GPU et mémoire sur un véritable iPhone pendant une session prolongée : aucun iPhone physique n’était disponible.
- Difficulté perçue, compréhension autonome, plaisir et envie de revenir : essais joueurs nécessaires.
- Le corpus apporte de nombreuses variantes mais repose sur 64 structures originales, pas sur un nombre illimité de nouvelles structures logiques.
- La compatibilité VoiceOver est renseignée dans l’interface, mais une évaluation complète avec des utilisateurs de VoiceOver reste distincte des tests automatisés.

## Captures

- [Indice sur iPhone SE](gameplay-validation/hint-iphone-se.png)
- [Exercice autonome terminé](gameplay-validation/lesson-completed.png)
- [Première récompense du Voyage](gameplay-validation/journey-reward.png)

## Modèles et orchestration

Trois sous-agents explicitement sélectionnés en **GPT-6.1 Sol** ont réalisé moteur/tests, sauvegardes/tests et tutoriels/traductions, puis des revues ciblées des fichiers des autres intervenants. L’agent principal a coordonné les contrats, intégré les vues, relu les résultats et réalisé la validation globale. Aucun appel Astra n’a été nécessaire. Le modèle principal ne peut pas être changé par les outils exposés ; aucun changement de modèle n’a été simulé. Aucune commande `/loop` appelable n’était disponible : les boucles compilation/tests/corrections ont été exécutées directement.

Un [AGENTS.md court](../AGENTS.md) décrit maintenant les conventions, migrations et commandes de validation du projet.
