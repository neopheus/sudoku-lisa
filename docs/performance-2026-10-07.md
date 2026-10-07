# Optimisations du 7 octobre 2026

## Comportement conservé

Même modèle 3D, matériaux, densité native, trajectoires, expressions, particules et cadences cibles. La politique thermique/économie d’énergie existante n’a pas été modifiée. Aucun nouveau réglage ni migration de sauvegarde.

## Changements

- Le compteur publie ses secondes dans `LisaGameClock`, observé uniquement par le texte du chronomètre. Le magasin global et la grille ne sont plus invalidés par chaque seconde. L’instantané sauvegardé reçoit le temps courant ; la session le reçoit à la sortie et avant l’enregistrement d’une victoire.
- Les conflits de grille sont calculés une fois par changement des valeurs, en parcourant les trois unités de chaque case. Les contenus des cellules sont équatables et reçoivent seulement leurs données d’affichage.
- `SnapshotWriter` conserve l’ordre des captures et regroupe les demandes en attente. Encodage JSON et écriture atomique s’exécutent hors du fil principal. Un `flush` et une tâche d’arrière-plan UIKit protègent les écritures lors d’une désactivation. Les erreurs de la dernière capture restent présentées à l’utilisateur.
- Les nuages utilisent le même Canvas, rasterisé à la densité native puis réutilisé pendant leurs déplacements. La clé inclut dimensions, thème et échelle ; le cache partagé est limité à 16 Mio/32 entrées. Les dimensions excessives utilisent directement le Canvas.
- Les trois tailles de flocons/étoiles sont résolues une fois par image du décor, au lieu de 20 résolutions. Les constantes d’articulation de Poulpi sont précalculées et les paramètres de portrait identiques ne sont plus réappliqués. La mascotte suspend aussi son animation hors du viewport.

## Vérifications

- 40 tests Swift en Release réussis, dont équivalence des conflits sur 100 grilles, regroupement/ordre des captures, écriture hors du fil principal, reprise après erreur et aller-retour JSON de la session.
- Compilation Release pour iPhone et pour simulateur réussie. Bundle iPhone local : 23,13 Mo, sous le budget du dépôt.
- iPhone 16 simulé, iOS 18.5 : saisie/notes/annulation/reprise après relancement, chronomètre, calendrier/thème et deux scénarios d’interaction de Poulpi réussis.
- iPhone SE simulé, iOS 18.2 : rotation avec conservation des notes, cinq mondes du Voyage, chronomètre avec passage en arrière-plan/reprise, victoire et animation/pause réussis.
- Le test de victoire imposait auparavant des textes français sans fixer la langue. Son lancement fixe désormais le français ; le scénario complet passe.
- Le test d’attente de Poulpi déclenchait un dump de la hiérarchie à chaque faux résultat, bloquant l’interface du SE simulé plusieurs secondes. La lecture conditionnelle de la seule valeur passe avec le même délai de dix secondes, sans changement de l’animation de l’app.
- Pendant la fenêtre stable du test instrumenté, aucune évaluation de `GameView.body` entre 07:58:42.753 et 07:58:56.252, malgré le chronomètre actif et les sauvegardes périodiques. Les évaluations suivantes correspondent à la pause/reprise.

Les journaux, binaires et `.xcresult` sont conservés sous `/tmp/lisa-perf-*`. Certaines clôtures de rapports Xcode sur le runtime iOS 18.2 restent bloquées après les résultats des cas de test ; les succès SE ci-dessus sont ceux consignés dans les journaux XCTest, pas une affirmation que tous les bundles `.xcresult` ont été finalisés.

## Comparaison CPU de l’accueil

Référence : `9f33023`. Même iPhone 16 simulé, iOS 18.5, binaires Release arm64, même sauvegarde et mêmes réglages. Chaque lancement est stabilisé pendant 20 secondes, puis mesuré pendant environ 30 secondes ; l’ordre avant/après/après/avant limite le biais d’ordre. Mesure par différence du temps CPU du processus (`ps`) divisée par le temps réel, exprimée en pourcentage d’un cœur.

| Passage | CPU moyen | RSS en fin de passage |
| --- | ---: | ---: |
| 1 — Avant | 26.04 % | 252.4 Mio |
| 2 — Après | 19.39 % | 241.5 Mio |
| 3 — Après | 22.52 % | 277.3 Mio |
| 4 — Avant | 24.09 % | 253.8 Mio |

Moyenne CPU : **25.06 % avant, 20.96 % après**, soit **16.4 % de moins observés**. Ce résultat est indicatif : d’autres applications tournaient sur le Mac et la politique adaptative de la référence a atteint les niveaux 1/2 pendant le second passage, tandis que la version optimisée est restée au niveau 0 pendant son second passage. Il ne s’agit donc pas d’un microbenchmark à détail forcé identique. Aucun gain mémoire n’est établi à partir des RSS variables ; le cache ajoute une réserve bornée de textures.

Les [échantillons et limites](performance-2026-10-07.json) sont conservés. Les captures statiques en thèmes clair et sombre ont aussi été comparées : erreur absolue moyenne par canal inférieure à 0,031 sur 255 sur la zone de contenu, hors barre système. Les très faibles écarts concernent la rasterisation des nuages ; aucun changement de composition ou de finesse visible n’a été relevé. Les captures sont sous `/tmp/lisa-static-*`.

## Reproduction et mesures sur appareil

```sh
swift test -c release --scratch-path /tmp/lisa-perf-core
xcodebuild -project SudokuLisa.xcodeproj -scheme SudokuLisa -configuration Release -sdk iphoneos -derivedDataPath /tmp/lisa-perf-device CODE_SIGNING_ALLOWED=NO build
```

Pour diagnostiquer les invalidations SwiftUI, lancer avec `LISA_RENDER_METRICS=1` et consulter la catégorie `AnimationBudget`. `Game body evaluated` marque une évaluation du corps du jeu. Après stabilisation des animations finies, le chronomètre doit progresser sans produire une évaluation du jeu par seconde. Les autres messages mesurent la cadence des callbacks, pas le temps GPU.

Pour la validation énergétique : comparer les deux versions Release sur le même ancien iPhone puis sur un récent. Garder luminosité, température initiale et scénario identiques ; ne pas recharger pendant la mesure. Parcourir les onglets, jouer, saisir rapidement et manipuler Poulpi pendant 15 minutes. Répéter avec batterie normale, moins de 20 % sans économie d’énergie, puis économie d’énergie activée. Mesurer CPU/GPU, blocages, consommation et évolution thermique avec Instruments. Comparer des séquences animées aux mêmes phases et vérifier les passages en arrière-plan.

Aucun iPhone physique n’était accessible pendant cette intervention. Les chiffres du simulateur ne prouvent ni une réduction de chauffe ni un gain d’autonomie sur appareil. Les tentatives d’attachement Time Profiler ont échoué (`Cannot find process for provided pid`) malgré un processus visible via `ps` ; aucune mesure GPU ou énergétique n’en est déduite.
