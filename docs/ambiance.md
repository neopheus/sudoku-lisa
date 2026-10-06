# Sons, décors et petites victoires

## Comportement

- Huit sons originaux : sélection, saisie, notes, gomme/annulation, indice, coucou, petite réussite, victoire. Un pool borné de lecteurs évite d'empiler des sons à chaque touche.
- Musique douce facultative, désactivée par défaut, indépendante des effets sonores. La boucle dure 24 secondes. Audio suspendu en pause et en arrière-plan ; session « ambient » respectant le mode silencieux. La musique se tait lorsqu'une autre source audio est détectée et après déconnexion des écouteurs.
- Grands nuages sur plusieurs plans, bonbons flottants et vingt points de lumière à l'accueil, dans le calendrier, le Voyage et les écrans secondaires. Pendant la partie, deux nuages lents et cinq petits éléments en périphérie ; la grille ne bouge pas.
- Cinq scènes de Voyage : fleurs qui tournent et papillons, sucettes rotatives, lagon avec bulles/poisson/voilier, sommets enneigés, planètes et étoile filante. Le chemin lumineux défile ; le niveau à jouer porte un halo étoilé et une étiquette flottante.
- Ligne, colonne ou bloc correctement terminé : balayage lumineux bref. Chiffre entièrement placé : rebond de sa touche. Les réussites déjà célébrées ne se répètent pas après annulation/résaisie au cours de la session de l'app ; les unités déjà complètes sont reconnues au chargement.
- En mode zen (vérification et limite d'erreurs désactivées), aucun son ni effet de réussite intermédiaire ne révèle la solution. La victoire finale reste célébrée.
- Lisa répond au toucher à l'accueil, au calendrier et dans le Voyage, avec un coucou et trois petits messages. Les réactions de réflexion, d'encouragement et de victoire restent liées aux actions du jeu.
- Le logo, la mini-grille, les raccourcis et les badges flottent. Les boutons présentent un reflet mobile et une pression élastique. Les chiffres de la grille restent fixes.
- La victoire illumine la grille avant de présenter Lisa, des étoiles flottantes, un halo tournant, deux gerbes de confettis, la récompense et la progression. La barre du Voyage avance de l'étape précédente vers la nouvelle ; les données sont enregistrées avant cette mise en scène.
- Les réglages « Sons », « Musique douce », « Décor animé » et « Retours haptiques » sont indépendants et sauvegardés. Les anciennes sauvegardes restent compatibles.
- « Réduire les animations » fige le décor et la mascotte, supprime les rebonds/confettis et rend la récompense accessible sans attendre la mise en scène. Les horloges locales visent 30 mises à jour par seconde (15 pour le fond en partie, 24 pour les reflets). Elles sont suspendues hors écran, sous les feuilles, sur les onglets inactifs et en arrière-plan. Le réglage « Décor animé » arrête aussi les mouvements décoratifs des boutons et badges. Les confettis s’arrêtent au bout de 4,6 secondes.

## Ressources

Les neuf WAV PCM mono 22,05 kHz occupent ensemble **1 416 222 octets**. Ils sont inclus dans l'application, sans téléchargement ni dépendance tierce. Le script déterministe `python3 scripts/generate_audio.py` les régénère avec la bibliothèque standard Python. Les formes d'onde sont originales et ne proviennent pas d'une banque de sons.

## Reproduction des contrôles

```sh
swift test
xcodebuild -project SudokuLisa.xcodeproj -scheme SudokuLisa \
  -destination 'platform=iOS Simulator,id=<SIMULATEUR_QA>' \
  -derivedDataPath /tmp/lisa-atmosphere-derived \
  -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO test
```

Les tests UI réinitialisent uniquement l'installation du simulateur choisi. Utiliser une installation QA sans progression personnelle. Le scénario de fin de grille est compilé en Debug uniquement et exige conjointement `--uitest-reset` et `--uitest-finale`.

Pour le contrôle d'accessibilité, activer « Réduire les animations » dans Réglages iOS du simulateur avant la suite. Le scénario zen joint l'état système au rapport et vérifie que l'application reçoit ce réglage lorsqu'il est actif.

Une écoute sur iPhone physique reste nécessaire pour ajuster le niveau perçu des sons et confirmer les vibrations, interruptions téléphoniques, écouteurs et consommation d'énergie. Une compilation simulateur ne mesure pas la taille distribuée par l'App Store.

## Première validation locale du 5 octobre 2026

Référence antérieure au renforcement des animations et des cinq scènes décrit ci-dessus.

- Moteur : **24 tests réussis**, dont cinq nouveaux tests sur les réussites simultanées, erreurs, mode zen, annulation/résaisie et entrées inchangées.
- iPhone SE 3, iOS 18.2, simulateur QA dédié : **5 tests UI réussis** avec le véritable réglage système « Réduire les animations ». Le scénario final vérifie explicitement `UIAccessibility.isReduceMotionEnabled` dans l'application. Deux captures de l'accueil à deux secondes d'intervalle sont identiques hors barre d'état système.
- iPhone 16, iOS 18.5, simulateur QA : **5 tests UI réussis**, animations normales. Le rapport joint confirme que la réduction des animations est désactivée. Total : dix exécutions UI sans échec dans ces deux validations finales.
- Compilation Release iPhone arm64 réussie, extension incluse : **6 208 925 octets (6,21 Mo)**. Les neuf fichiers audio sont présents dans le bundle ; budget local inférieur à 100 Mo respecté.
- Ressources audio contrôlées : format, durée, absence de saturation numérique. Ce contrôle ne remplace pas une écoute sur appareil.
- Le premier test des interrupteurs cliquait au centre de la ligne SwiftUI sans actionner le contrôle : ciblage corrigé et sauvegarde vérifiée après relance complète.
- Rapports locaux : `/tmp/lisa-atmosphere-core.log`, `/tmp/lisa-atmosphere-se-final.xcresult`, `/tmp/lisa-atmosphere-large-final.xcresult`, `/tmp/lisa-atmosphere-release.log`.

[Aperçu animé de l'accueil](screenshots/ambiance-accueil.mp4) · [Victoire sur iPhone 16](screenshots/ambiance-victoire-iphone16.png) · [Victoire sur iPhone SE](screenshots/ambiance-victoire-se.png)

## Validation des animations renforcées du 5 octobre 2026

- iPhone 16, iOS 18.5 : les **6 tests UI passent**, dont la traversée des cinq mondes et l'ouverture du premier niveau. Ce dernier scénario passe de nouveau après la finition graphique des sucettes.
- iPhone SE 3, iOS 18.2 : les cinq scénarios existants passent ; le nouveau parcours des cinq mondes passe lors de sa relance ciblée. Le premier essai défilait trop loin sur le petit écran : les gestes du test ont été raccourcis, sans retirer les assertions.
- Réduction des animations activée dans les réglages système du SE : deux nouvelles captures de l'accueil espacées de deux secondes sont strictement identiques hors barre d'état.
- Compilation Release iPhone arm64 réussie, extension incluse : **6 600 565 octets (6,60 Mo)** pour le bundle local. Ce chiffre ne mesure pas la taille distribuée par l'App Store.
- Les 24 tests du moteur restent la référence de la première validation ; le moteur n'a pas changé pendant ce renforcement visuel.
- Rapports locaux : `/tmp/lisa-wow-ui.xcresult`, `/tmp/lisa-wow-map-final.xcresult`, `/tmp/lisa-wow-se.xcresult`, `/tmp/lisa-wow-se-map-final.xcresult`, `/tmp/lisa-wow-release.log`.

Les vidéos suivantes montrent l'application dans le simulateur avec les animations activées :

[Accueil animé](screenshots/wow-accueil.mp4) · [Voyage à travers les cinq mondes](screenshots/wow-voyage.mp4)

## Animation en partie et pitreries

La partie conserve une grille fixe, avec huit étincelles qui parcourent son cadre, des reflets décalés sur les touches et trois nuages plus mobiles en arrière-plan. Lisa est plus grande dans l'en-tête et peut faire une pirouette, danser ou se rapetisser puis réapparaître. Toucher « Faire rire Lisa » déclenche la prochaine pitrerie ; spontanément, elle démarre après dix secondes puis à intervalles de 18 à 28 secondes. Une réaction de jeu reste prioritaire. Aucune pitrerie n'est liée à la justesse d'une réponse.

Pause, fenêtre ouverte, arrière-plan, victoire et réglages de mouvement interrompent les pitreries. Les trois réactions tactiles sont vérifiées par le test UI `testPlayfulCompanion` sur iPhone 16. Le parcours saisie/notes/annulation/pause/reprise passe sur iPhone 16 et sur iPhone SE avec réduction des animations. Le premier test du compagnon a révélé une zone tactile vide autour de la vue SceneKit : ajout d'une surface tactile explicite, puis relance réussie des trois réactions.

Rapports locaux : `/tmp/lisa-antics-companion-final.log`, `/tmp/lisa-antics-test.log` (parcours de jeu réussi, premier essai du compagnon échoué), `/tmp/lisa-antics-se-test.log`.

## Carrés, lignes et colonnes complétés

Chaque unité nouvellement complétée correctement conserve désormais son identité dans l'événement du moteur. Une ligne reçoit un contour menthe et une traînée horizontale ; une colonne, un contour cyan et une traînée verticale ; un carré 3 × 3, un contour doré et une gerbe d'étoiles. Les effets se superposent en cas de réussite simultanée, avec un message « Combo ×2 ! » ou « Combo ×3 ! » et une danse de Lisa. Un message précis remplace le générique « Bien joué ! » pour une seule unité.

L'effet finit en 2,4 secondes et le message en 2,8 secondes, sans bloquer les touches. Réduire les animations ou désactiver le décor conserve seulement le contour temporaire. Le mode zen reste sans indication de justesse, et une annulation suivie d'une nouvelle saisie ne rejoue pas une réussite déjà célébrée.

Validation moteur : **25 tests réussis**, dont les identités des trois types d'unités isolées et le combo ligne/colonne/carré. Compilation iOS simulateur réussie. Rapports : `/tmp/lisa-units-core.log`, `/tmp/lisa-units-build.log`.

Validation UI : les deux scénarios ciblés passent sur iPhone 16, avec vérification de deux combos ×3, victoire et progression, puis absence de combo en mode zen et victoire autorisée. Rapport : `/tmp/lisa-units-ui.log`.

## Décor naturel et clavier fixe

Les neuf touches colorées n'ont plus de reflet, de rebond de réussite ni de déformation à l'appui. Leur transaction désactive aussi les animations héritées lors de la saisie. Les effets de ligne, colonne et carré restent sur la grille.

Le fond ajoute quatre papillons pendant les parties (six ailleurs) aux ailes battantes et quatre feuilles portées par le vent. Le décor reste derrière les commandes et la grille. Les nuages sont désormais des masses asymétriques avec dégradé d'ombre, lobes éclairés et base diffuse, également utilisés sur la carte du Voyage. Le réglage de réduction des animations et l'arrêt du décor continuent de figer ces éléments via l'horloge commune.

Compilation et scénario UI de saisie, notes, annulation, pause et reprise persistée réussis sur iPhone 16. Capture du décor inspectée : `docs/screenshots/decor-papillons.png`. Rapport : `/tmp/lisa-nature-ui.log`.

## Répertoire et fluidité du poulpe — 6 octobre

Neuf pitreries se succèdent : pirouette, danse, cache-cache, ondulation gélatineuse, nage, révérence, curiosité, rire et décollage. Une interaction manuelle repousse les pitreries spontanées pour éviter leur chevauchement.

Le modèle utilise maintenant un nœud de geste distinct du corps qui respire. Une réaction interrompue conserve sa pose visible puis rejoint la nouvelle trajectoire progressivement ; les gestes ont une enveloppe douce et se terminent au repos. Le changement d'humeur et le compteur de réaction ne déclenchent plus deux fois la même action.

Optimisations : les positions de base des huit pointes et quarante ventouses sont calculées à la création ; chaque image ne met à jour que leur déplacement vertical, au lieu de recalculer 48 courbes trigonométriques. Les petites sphères utilisent 12 ou 20 segments au lieu de 32 ; les yeux et la tête gardent 32 segments. Le lecteur SceneKit ne reçoit plus de commandes play/pause et d'invalidation à chaque mise à jour SwiftUI lorsque son état n'a pas changé. La cible reste 60 images/s, sans mesure garantie sur appareil physique à ce stade.

Les sauts ont été limités pour conserver la tête dans le cadrage compact ; les rebonds utilisent une courbe sinusoïdale au carré pour éviter une inversion brusque de vitesse. Le premier lancement UI avait conservé l'ancien exécutable du runner (trois gestes) : suppression des installations QA et nouvelle installation avant de vérifier effectivement les neuf messages. Les scénarios de victoire et de jeu sur SE avec réduction des animations passent également. Rapports : `/tmp/lisa-fluid-nine-final.log`, `/tmp/lisa-fluid-victory-final.log`, `/tmp/lisa-fluid-se.log`. La dernière vérification du cadrage est consignée dans `/tmp/lisa-fluid-framing-final.log`.

Le contrôle de retour au repos a rencontré une valeur d'accessibilité vide instable. Le compagnon expose désormais explicitement « Au repos », ce qui est aussi plus clair pour VoiceOver ; le test attend cet état après chacun des neuf gestes. Rapport final : `/tmp/lisa-fluid-framing-final2.log`.

La relance finale réussit les neuf gestes et leurs retours au repos. Le décollage a été inspecté dans la vidéo finale avec la tête entièrement visible. Aperçu : [pitreries du poulpe](screenshots/poulpe-neuf-pitreries.mp4). Les contrôles simulateur ne constituent pas une mesure de cadence ou de consommation sur appareil physique.

## Déplacements et petits numéros comiques

Lisa dispose maintenant d'une scène dans l'en-tête de partie, entre Retour et Réglages. Elle se promène latéralement au repos ; poursuite, moonwalk et vol traversent cette zone. La grille compacte réserve la hauteur de cet en-tête afin de garder les neuf touches à portée.

Le répertoire comporte 18 numéros : les neuf pitreries précédentes, poursuite d'un papillon, moonwalk musical, jonglage étoilé, cache-cache dans un nuage, éternuement scintillant, roulade, bonbon en équilibre, vertige étoilé et vol de super-poulpe. Les neuf nouvelles scènes durent 4,4 secondes, avec message retiré à 4,8 secondes. Elles restent déclenchables au toucher ou occasionnellement pendant la partie.

Une seule horloge locale anime déplacements et accessoires, avec un nombre fixe d'objets ; le garde de configuration SceneKit ignore les mises à jour dont humeur, réaction et lecture n'ont pas changé. Les commandes et le clavier ne bougent pas. Réduction des animations, décor désactivé, pause et fenêtres interrompent aussi le déplacement.

Les contrôles de saisie, notes, annulation, pause et reprise passent sur iPhone 16 et SE, ainsi que la désactivation du compagnon avec la réduction des animations sur SE. La vérification des scènes a demandé une attente plus longue que celle prévue pour les anciens gestes de 2,2 secondes ; elle conserve les assertions de chaque numéro et de retour au repos. Rapports : `/tmp/lisa-comedy-ui.log`, `/tmp/lisa-comedy-se.log`, `/tmp/lisa-comedy-final.log`.

[Aperçu des déplacements et accessoires](screenshots/poulpe-comedien.mp4)

La relance finale valide les 18 numéros, chacun suivi du retour explicite « Au repos », puis la mise en pause. Aperçu vidéo exporté et contrôlé (54 secondes).

## Effets adaptatifs et cadence — 6 octobre

Les pitreries sont accompagnées d'un halo, de deux rubans colorés et d'étincelles orbitales, dessinés dans un Canvas sur l'horloge existante. Les effets restent finis et le nombre d'éléments est borné.

Trois niveaux de qualité privilégient la cadence :

| Niveau | Particules de scène | Décor (maximum) | Anticrénelage 3D | Échelle de rendu 3D |
| --- | ---: | ---: | --- | --- |
| Complet | 24 | 30 Hz | 4× | Échelle de l'écran |
| Allégé | 14 | 20 Hz | 2× | Au plus 2× |
| Économique | 7 | 12 Hz | Désactivé | Au plus 1,5× |

Au niveau économique, les 40 ventouses et huit pointes miniatures sont masquées, leurs déplacements inutiles ne sont plus recalculés, et les bulles 3D sont masquées. La tête, les yeux, le sourire et les tentacules restent présents.

Le poulpe et ses déplacements demandent la fréquence maximale de l'écran (60 ou jusqu'à 120 Hz), avec autorisation ProMotion dans Info.plist. En charge persistante, la cible est plafonnée à 60 ; économie d'énergie impose aussi 60 au plus et une qualité allégée ; état thermique sérieux/critique impose 30 et la qualité économique. iOS reste décisionnaire de la fréquence réellement accordée.

Un seul CADisplayLink partagé surveille le fil principal, seulement lorsqu'une surface animée est active. Un délégué SceneKit agrège aussi les callbacks de rendu par fenêtres de deux secondes, sans publier chaque image dans SwiftUI. Plus de 15 % d'intervalles tardifs abaisse la qualité ; huit fenêtres stables sont nécessaires pour la remonter. Un blocage actif d'au moins 250 ms est également traité comme une surcharge. Pause, arrière-plan, réduction des animations et sortie de l'écran suspendent les horloges concernées ; la visibilité est transmise au rendu 3D.

Validation : 28 tests moteur réussis, dont trois sur dégradation, récupération et plafonds thermiques/énergétiques. Les tests UI des effets/pause/reprise et de victoire passent en Debug ; le scénario effets/pause/reprise passe aussi en Release sur iPhone 16 simulé.

Une capture de télémétrie Release, sans compilation concurrente ni enregistrement vidéo, donne **58,75 FPS médians pour les callbacks SceneKit** (47 à 60, dix fenêtres) et **57 FPS médians pour le CADisplayLink principal** (20 à 58,7, onze fenêtres). Elle inclut des interactions et captures automatisées ; les fenêtres stables après adaptation se situent vers 58–59 FPS pour SceneKit. Ce n'est ni une mesure GPU de présentation, ni un avant/après, ni une garantie sur appareil physique. Cette capture précède les derniers gardes d'arrêt hors écran et de blocage long.

Télémétrie opt-in via `LISA_RENDER_METRICS=1`, catégorie OSLog `AnimationBudget`. [Mesures brutes structurées](animation-performance.json) · [Aperçu des effets](screenshots/wahoo-adaptatif.png). Rapports locaux : `/tmp/lisa-adaptive-all-core.log`, `/tmp/lisa-adaptive-ui.log`, `/tmp/lisa-adaptive-release-ui.log`, `/tmp/lisa-adaptive-release-cadence.log`.

Vérifications finales : build Release iPhone arm64 réussi (`/tmp/lisa-adaptive-final-release2.log`) ; scénario effets/pause/reprise réussi en Release sur iPhone SE avec réduction des animations (`/tmp/lisa-adaptive-final-se.log`). La capture de cadence ci-dessus reste un résultat simulateur, sans extrapolation aux appareils physiques ou au mode 120 Hz.


## Déplacements en profondeur — révision du 6 octobre 2026

Cette révision remplace les rubans, étoiles et accessoires de la mascotte en partie : l'effet recherché vient désormais de son animation. Les décors et les célébrations de grille restent indépendants ; les touches numériques restent fixes.

- Un seul poulpe traverse la surface de jeu sur une courbe fermée de 32 secondes, avec des déplacements horizontaux, verticaux et en profondeur. La position et la vitesse sont continues, y compris au raccord de boucle.
- Une caméra en perspective produit le rapprochement et l'éloignement réels. Le corps s'incline selon la trajectoire ; tentacules et bouche accompagnent les pitreries.
- Un masque de profondeur aligné sur la grille cache les passages derrière celle-ci. Le poulpe réapparaît au premier plan lorsqu'il revient vers la caméra. Le bouton « Lisa ! » déclenche les pitreries ; le personnage ne capture aucun toucher.
- SceneKit calcule le parcours sans mise à jour SwiftUI à chaque image. La qualité adaptative conserve une résolution minimale de 1,5 pixel par point pour le personnage, avec un plafond de 2 ; les détails et l'anticrénelage diminuent selon la charge.
- Les mouvements sont suspendus en pause, hors écran et sous les fenêtres. « Réduire les animations » et « Décor animé » désactivé conservent une pose fixe.

Validation : 30 tests du noyau passent, dont la couverture des trois axes et la continuité de la trajectoire. Les scénarios UI vérifient la saisie pendant le vol, un tour complet et la pause/reprise. Le contrôle sur iPhone SE avec « Réduire les animations » passe également, ainsi que la compilation Release pour iPhone (sans signature). La capture `screenshots/poulpe-profondeur.mp4` montre le rendu sur simulateur iPhone 16. Les mesures FPS de la section précédente concernent l'ancienne surface de rendu ; elles ne constituent pas une mesure de cette version plein écran ni une garantie sur appareil physique.


## Tentacules et ventouses

Les huit tentacules ondulent avec des phases décalées et trois cadences, avec une flexion amplifiée sur les trois axes. Chaque bras porte cinq ventouses creuses à rebord clair, orientées sur sa surface vers l'avant. Les ventouses utilisent les mêmes poids de déformation que leur tentacule : elles restent attachées pendant les ondulations et les pitreries. Un maillage regroupe les cinq ventouses de chaque bras, sans mise à jour individuelle de leur position à chaque image. Elles restent visibles en qualité économique ; seules les petites sphères de finition peuvent être masquées. Les pauses et le réglage de réduction des animations restent respectés.

Vérification : parcours complet et saisie pendant le vol validés par le test UI, compilation Release iPhone réussie, inspection du modèle agrandi dans `screenshots/poulpe-ventouses.png`. Vidéo : `screenshots/poulpe-tentacules.mp4`.


## Silhouette adoucie d'après la référence visuelle

La tête est plus ronde, les yeux possèdent désormais un iris et une pupille distincts avec deux reflets, et la bouche conserve une petite lèvre arrondie. Le manteau relie le corps aux huit bras plus dodus. Les pointes sont arrondies dans le maillage, sans sphère de finition séparée. Les matériaux utilisent un éclairage physique avec une peau plus mate.

Correction anatomique : les ventouses sont désormais placées sur la face inférieure des bras. Leur orientation est transportée le long de la courbe : elles regardent vers le sol à la base, puis se révèlent lorsque la pointe se relève ou se recourbe. Cette version remplace leur orientation antérieure vers la caméra. Les ventouses restent regroupées par bras et suivent les mêmes déformations ; elles sont conservées en mode économique.

Aperçu final : `screenshots/poulpe-mignon.png` et `screenshots/poulpe-mignon.mp4` (modèle agrandi animé). Compilation Debug et Release iPhone réussie ; saisie pendant un tour complet validée par le test UI. Les sections des bras utilisent un repère continu pendant les replis, avec des normales tenant compte du rétrécissement des pointes.


## Intégration du Poulpi original de `/pet`

Le modèle procédural est remplacé par le dessin original fourni, sans retouche. Source : `/Users/xavier/Documents/Codex/2026-10-05/pets-plugin-work-pets-openai-curated/outputs/poulpi-violet-bleu.png`. Copie embarquée : `App/Resources/Mascot/poulpi-original.png`, SHA-256 `79b38446c0f3c30228535cd192d86b3b215feb4efd4eb6d135d9fe558eede16f` (identique à la validation source).

La planche RGBA de 1536 × 2288 contient 73 images utiles, dans des cellules de 192 × 208. Neuf animations et seize regards sont disponibles. `PoulpiArtwork` découpe et partage les images en mémoire, puis change la texture seulement au changement d'image, aux cadences originales de 120 à 280 ms. Il ne génère aucune image intermédiaire. Le personnage conserve donc exactement ses proportions, son éclairage dessiné et ses ventouses.

Le dessin est porté par un plan dans la scène en perspective : la trajectoire continue sur les trois axes, le rapprochement et l'occlusion par la grille sont conservés. C'est une représentation 2,5D : les inclinaisons sont bornées pour éviter de voir une tranche plate ; aucune vue arrière nouvelle n'est inventée. Les anciennes pitreries utilisent les animations disponibles et leurs mouvements de scène. Le mode statique, la pause et la suspension hors écran sont conservés. L'agrandissement est limité par la résolution originale des cellules.

Cette section remplace les descriptions précédentes de géométrie du personnage. Les captures précédentes restent des étapes de travail, et leurs anciennes mesures FPS ne décrivent pas ce nouveau rendu.

Contrôles de l'intégration : hash de la ressource identique à l'original, aperçu agrandi inspecté, parcours enregistré dans `screenshots/poulpi-original-jeu.mp4`, compilation Release iPhone réussie, réaction/pause sur iPhone 16 et réduction des animations sur iPhone SE vérifiées. Le premier contrôle d'accessibilité de la touche 9 en fin de parcours a rencontré une erreur XCTest de point d'activation ; le scénario vérifie désormais une saisie effective et la valeur de la case.
Le scénario renforcé passe : saisies avant et après le tour complet, valeurs de la case confirmées, puis mise en pause.


## Version 3D articulée du Poulpi

Le dessin animé est remplacé par un maillage continu préparé dans Blender d'après la référence HD. `PoulpiRig` charge le maillage validé, crée 24 articulations de bras, puis fait déformer la peau et les 40 ventouses par le GPU. Le visage est géométrique, avec iris, reflets, paupières, sourcils et bouche. Respiration, clignements, regards et ondulations des huit bras sont continus ; ils ne dépendent plus des 4 à 8 poses des anciennes séquences.

La caméra en perspective, les rotations libres, les passages derrière la grille et les interactions existantes sont conservés. L'éclairage suit la position de la mascotte pour éviter les variations d'exposition lors des passages près de la caméra. Le rendu reste en résolution native, avec MSAA 4× ou 2× même lorsque la qualité adaptative diminue. La réduction des animations et la pause arrêtent les articulations.

Sources et procédure : `docs/mascot-hd/README.md`, `scripts/mascot/build_poulpi.py`, `scripts/mascot/validate_poulpi.py`. Le rapport géométrique est `docs/mascot-hd/rig-validation.json`. La planche `/pet` est archivée dans la documentation ; le moteur de lecture de sprites a été retiré de l'application.

Validation fonctionnelle : réaction/pause sur iPhone 16, saisie avant/après le parcours complet, réduction des animations sur iPhone SE ; compilation Release iPhone sans signature. Les captures historiques montrent les versions précédentes et ne décrivent pas le modèle actuel.
