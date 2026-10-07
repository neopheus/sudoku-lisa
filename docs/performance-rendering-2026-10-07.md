# Deuxième passe : mémoire et rendu de Poulpi

Comparaison avec la première passe d’optimisation du 7 octobre, et non avec le commit initial. Les données brutes sont dans [performance-rendering-2026-10-07.json](performance-rendering-2026-10-07.json).

## Changements sans réduction du rendu

- Les tableaux issus du JSON de sculpture sont libérés après conversion en buffers SceneKit. Le fichier source reste inchangé.
- Les poids du squelette, indices des os et matrices inverses sont partagés entre instances. Chaque instance conserve ses propres os, expressions et matériaux.
- Les quatre coques des yeux partagent une géométrie immuable ; chaque géométrie est copiée avant affectation de ses matériaux.
- Les indices des triangles passent de 32 à 16 bits lorsque leur maximum le permet. Le repli 32 bits reste disponible pour de futurs modèles plus grands.
- Aucun sommet ni triangle supprimé, aucun changement de texture, shader, éclairage, antialiasing, résolution, trajectoire, vitesse ou politique thermique.

## Mesures de mémoire

Six lancements Release, sans compilation concurrente, sur le simulateur iPhone 16/iOS 18.5, dans l’ordre référence/après/après/référence/référence/après. Le test crée huit modèles, relève leur mémoire, les détruit, puis effectue deux rendus. Les buffers accessibles via SceneKit sont dédupliqués par adresse ; cette métrique n’est pas une mesure de VRAM. Les médianes de mémoire globale dépendent aussi de l’allocateur et de l’hôte.

| Mesure | Référence | Après | Évolution |
| --- | ---: | ---: | ---: |
| Buffers uniques, un modèle | 6 733 324 octets | 5 430 832 octets | −19,3 % |
| Buffers uniques, huit modèles | 21 198 012 octets | 15 892 416 octets | −25,0 % |
| Indices, un modèle, comptés par géométrie | 2 047 284 octets | 1 023 648 octets | ≈ −50 % |
| Empreinte physique du processus avec huit modèles, médiane | 66 931 328 octets | 55 495 296 octets | −17,1 % |
| Empreinte physique après libération, médiane | 48 237 232 octets | 40 143 560 octets | −16,8 % |
| Triangles par modèle | 156 784 | 156 784 | identique |
| Éléments géométriques par modèle | 16 | 16 | identique |

Les huit modèles **et** leurs huit racines de scène sont libérés dans chacun des six essais, après vidange du pool et des transactions SceneKit. Cela valide ce cycle de vie précis ; ce n’est pas une preuve d’absence de fuite dans toute l’application. Une première lecture trop précoce retenait encore les racines dans le pool d’autorelease ; le diagnostic attend désormais un passage de boucle avant de conclure.

## CPU et GPU : limites des chiffres

Le rendu est exécuté avec animations actives, 4× MSAA et tailles fixes de 840 × 840 et 1179 × 2556. Chaque cas exclut 20 images de chauffe puis mesure 120 images. Le chronométrage de l’encodage mesure le temps écoulé de l’appel SceneKit, pas le temps CPU total de l’application.

Les médianes d’encodage des trois passages sont de 0,130 → 0,110 ms en portrait et de 0,110 → 0,103 ms en vol. La construction des huit modèles passe de 306,5 à 301,5 ms en médiane. Le premier modèle, qui comprend le chargement des ressources, reste comparable : 283,0 → 281,9 ms. Les 21 créations suivantes mesurées par version passent de 3,33 à 2,85 ms en médiane, soit environ **14,5 % de moins**. Ces valeurs sont indicatives : elles ne certifient pas une accélération globale de l’application sur appareil.

Un essai intermédiaire utilisait `Data(contentsOf:options:.mappedIfSafe)`. Les timings à froid étaient moins bons et variables ; cette option a été retirée. Les six relevés finaux ci-dessus portent tous sur le chargement classique, avec les mêmes réglages pour les deux versions.

Les timestamps des command buffers sont lus après leur achèvement, mais le périphérique se déclare « Apple iOS simulator GPU ». Ses temps autour de 0,03 ms ne représentent pas le GPU d’un iPhone. `currentAllocatedSize` renvoie zéro : cette mesure de mémoire Metal est indisponible dans cet environnement, et non nulle. Aucun gain GPU ou d’autonomie n’est déduit de ces valeurs.

## Fidélité et validation

Les captures fixes utilisent le même cadrage et le même anticrénelage. Sur 705 600 pixels du portrait, 106 diffèrent, sans changement d’alpha ; l’écart absolu moyen maximal par canal est de 0,000117 sur 255. En vol, 22 pixels sur 3 013 524 diffèrent, avec un maximum de deux niveaux. La comparaison visuelle ne révèle pas de perte de finesse. Ces captures statiques complètent les tests d’interaction, sans prétendre couvrir toutes les phases d’animation.

- 40 tests Swift Release réussis.
- Compilation Release iPhone réussie, sans outil de diagnostic dans le parcours de production.
- Compilation Release du diagnostic pour simulateur réussie.
- Trois scénarios UI réussis : rotation/zoom/lecture automatique, caméra avec animations désactivées, puis saisie avant et après un cycle complet de vol et mise en pause.
- Les deux premiers scénarios passent en Release. Le troisième avait échoué sur sa préparation, car `--uitest-reset` est réservé au Debug ; il passe en Debug (50,37 s). Aucun correctif du produit ou des assertions n’a été nécessaire. Comme lors de la première passe, Xcode reste bloqué en finalisation de rapport ; les résultats cités proviennent des lignes de fin de cas XCTest, puis les processus de test ont été arrêtés.

## Reproduire le diagnostic

`LisaRenderingProbe.swift` n’est compilé qu’en Debug ou avec `LISA_PERFORMANCE_DIAGNOSTICS`. Le lancement normal n’exécute jamais la sonde.

```sh
xcodebuild -project SudokuLisa.xcodeproj -scheme SudokuLisa \
  -configuration Release -sdk iphonesimulator -arch arm64 \
  -derivedDataPath /tmp/lisa-rendering-probe \
  'OTHER_SWIFT_FLAGS=$(inherited) -DLISA_PERFORMANCE_DIAGNOSTICS' \
  CODE_SIGNING_ALLOWED=NO build
```

Installer le binaire puis lancer avec `--profile-rendering`. Récupérer `Documents/RenderingProbe/report.json`, `portrait.png` et `flight.png` dans le conteneur de l’application. Les comparaisons de cette intervention sont aussi disponibles dans `/tmp/lisa-unmapped-probe-*` tant que les fichiers temporaires existent.

Pour conclure sur la chauffe, poursuivre le protocole sur appareil décrit dans [la première passe](performance-2026-10-07.md), avec CPU, GPU, mémoire et état thermique, notamment sous 20 % de batterie. Aucun iPhone physique n’était accessible pendant cette intervention.

Références API Apple : [sources de géométrie SceneKit](https://developer.apple.com/documentation/scenekit/scngeometrysource), [temps GPU d’un command buffer](https://developer.apple.com/documentation/metal/mtlcommandbuffer/gpustarttime).
