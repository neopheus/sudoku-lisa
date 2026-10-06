# Diagnostic de définition et de cadence

État courant : passe 62, visible dans `comparaison-reference-hd.html`. Les sections ci-dessous conservent l’historique ; les derniers contrôles sont en fin de document. La ressemblance exacte reste non atteinte.

La planche `/pet` comporte des cellules de 192 × 208 px. Les séquences utilisent 4 à 8 poses (hors regards), espacées de 120 à 280 ms. Le générateur source retrouvé dans `work/poulpi/assemble.py` a produit une image de 1027 × 1531 ensuite redimensionnée : il ne contient pas de poses HD cachées.

Le rendu SceneKit utilisait encore la limite de densité de pixels du modèle géométrique précédent (1,5 à 2 pixels par point). Il utilise désormais la densité native de l'écran, avec filtrage mipmap linéaire et anisotropie 4. Cela ne crée ni détails supplémentaires dans la source ni poses intermédiaires. Le coût GPU de la résolution native doit être mesuré sur appareil physique.

`poulpi-reference-hd.png` est une nouvelle référence générée à partir des quatre poses fournies, de 1254 × 1254 px avec transparence. Elle reste une référence de production, non intégrée comme remplacement statique de la mascotte animée. La prochaine étape dépend du choix entre un personnage 3D articulé fidèle à cette référence et des animations dessinées HD comportant davantage de poses. Un simple agrandissement de la planche ou une accélération de sa lecture ne résout pas le problème.


## Reconstruction 3D articulée

La version courante utilise `PoulpiRig.swift` et `App/Resources/Mascot/poulpi-rig.json`. La planche originale est archivée ici (`poulpi-original-sprites.png`) et n'est plus chargée par la mascotte.

`blender -b --python-exit-code 1 --python scripts/mascot/build_poulpi.py` reconstruit le maillage soudé, adoucit les raccords, attribue les poids des articulations, prépare 44 ventouses et précalcule l'ombrage des plis. La source Blender est `poulpi-sculpt.blend`. Le squelette exporté comporte 25 nœuds : une racine et trois articulations par bras. Le skinning est effectué par SceneKit ; aucune image de pose ne remplace le personnage. Les yeux, les iris, les sourcils et la bouche sont des géométries distinctes attachées au corps.

La peau compte actuellement 45 265 sommets / 90 526 triangles, les ventouses 7 392 sommets / 12 672 triangles. Les géométries sont partagées, les matériaux et les articulations sont propres à chaque instance. Les ombres des plis sont calculées hors ligne. Le rendu reste à la densité native avec MSAA 4× ou 2×, sans désactiver l'anticrénelage en qualité économique.

`blender -b --python-exit-code 1 --python scripts/mascot/validate_poulpi.py` contrôle la pose de liaison, les valeurs finies, l'étirement des arêtes sur 97 poses et la fermeture de boucle. Résultats : `rig-validation.json`. Il s'agit d'un contrôle géométrique, pas d'une garantie contre toute auto-intersection ni d'une mesure de FPS.

Le modèle est une reconstruction volumétrique inspirée de la référence, pas une conversion exacte du dessin. La vidéo et les captures de l'application servent à juger le rendu réel.

Mesure de la première version (avant la reprise des détails) : onze fenêtres de deux secondes à 60,0 FPS pour le rendu SceneKit et la cadence principale, sur simulateur iPhone 16 iOS 18.5 en Debug, aperçu agrandi, sans capture ni interaction pendant la mesure. Données : `rig-performance.json`. Cette mesure ne représente ni une partie complète ni un iPhone physique.

Aperçus : `../screenshots/poulpi-3d-articule.png`, `../screenshots/poulpi-3d-articule-jeu.mp4`, et inspection 360° `../screenshots/poulpi-3d-articule-360.mp4`. Le mode `--octopus-preview --octopus-turntable` est réservé au Debug.


### Reprise de ressemblance — 6 octobre

La comparaison utilise l’aperçu original du plugin et la référence HD conservée ici. Les huit trajectoires sont désormais des courbes à six points avec une paire relevée plus courte, des boucles frontales basses et des extrémités rentrantes. La tête est plus large et moins haute. Les ventouses possèdent six anneaux de profil, une lèvre arrondie et une cavité peu profonde.

Le visage comprend des blancs ivoire, des iris bleus à fibres fines, de plus petites pupilles, des sourcils arrondis et des lèvres tubulaires avec une commissure. Le dégradé violet/bleu, le blush et le grain de peau sont portés par les matériaux. La petite carte de normales est créée une seule fois et partagée. Le grain est atténué lorsqu’il devient trop fin à l’écran. Le maillage reste calculé hors ligne, avec 25 articulations et deux maillages principaux animés sur GPU.

La ressemblance doit être jugée visuellement ; ces changements ne constituent pas une reconstruction exacte de la référence. La validation géométrique de cette version est enregistrée dans `rig-validation.json`. Aperçu : `../screenshots/poulpi-3d-detaille.png`.

Validation de la reprise : build Release réussi, test UI de saisie avant/après le trajet spatial réussi, et 97 poses du rig validées. Sur l’aperçu agrandi du simulateur iPhone 16, douze fenêtres de mesure donnent 60,0 FPS pour SceneKit et la cadence principale (`rig-detail-performance.json`). Ce résultat ne garantit pas les performances sur appareil physique. Comparaison visuelle : `comparaison.html` ; rotation réelle : `../screenshots/poulpi-3d-detaille-360.mp4`.


### Sculpture continue et visage — seconde reprise

`sculpt_surface.py` produit une surface implicite fusionnée avec des raccords doux, puis une triangulation hors ligne. Le cou marqué de l’ancienne union de volumes disparaît. Les deux tentacules avant suivent maintenant des trajectoires tridimensionnelles qui les écartent vers l’extérieur et ramènent leur pointe. Les cavités orbitales et les joues sont modelées dans la surface. Les blancs des yeux suivent l’orientation locale du visage. La bouche est une géométrie fermée unique, avec une rainure pour le sourire.

La fermeture du maillage est vérifiée après simplification, en plus du contrôle des déformations : aucune arête ouverte ou non-manifold dans la peau. Le grain s’estompe avec la distance ; les ombres de contact du visage et la coloration restent des effets de matériau, sans passe d’ombre supplémentaire. La construction de la surface implicite ne s’exécute pas dans le jeu.


Les yeux ont ensuite été amincis en profondeur après inspection à 360°, sans réduire leur silhouette de face. Le dernier build Release passe. Le test UI de saisie avant et après le trajet spatial passe également ; la dernière retouche des yeux ne modifie que les dimensions du visage. La mesure de la sculpture continue est consignée séparément dans `rig-continuous-performance.json` pour ne pas confondre les résultats avec les versions précédentes.


### Paupières et expressions

Les yeux restent à leur taille naturelle pendant les clignements. Deux paupières passent par quatre formes précalculées et interpolées par SceneKit ; aucune géométrie n’est reconstruite par image. Un fin pli apparaît à la fermeture. Les sourcils suivent doucement les expressions et leur profondeur est ajustée pour rester au contact du front. Le retour au repos et le mode sans animation réinitialisent les pupilles, les sourcils et la bouche.

Les 48 ventouses passent de 16 à 24 segments circulaires, avec une matière crème plus mate. Elles conservent un maillage commun et les mêmes articulations. La géométrie et les 97 poses du rig restent validées. En Debug, `--octopus-preview --octopus-eyelids-half` et `--octopus-preview --octopus-eyelids-closed` permettent d’examiner les états intermédiaires. Ces options ne sont pas actives dans les builds Release.

Validation de cette passe : build Release réussi, tests de réaction/repos/pause réussis sur les simulateurs iPhone 16 et iPhone SE (ce dernier avec Réduire les animations), inspection visuelle des paupières ouvertes, à mi-course et fermées. Les poids de morphing ne sont réassignés que si la fermeture change. Mesure dédiée : `rig-eyelids-performance.json`. Vidéo de clignement : `../screenshots/poulpi-clignement.mp4`.


### Correction des bras fusionnés au visage

Les deux bras relevés avaient une deuxième attache à la tête : leur pointe pénétrait dans le volume crânien et la fusion implicite soudait les deux surfaces. La sculpture précédente avait deux anses topologiques (caractéristique d’Euler −2). Les bras partent maintenant sous le manteau, se soulèvent à l’extérieur et se recourbent vers l’intérieur en restant à distance des joues. La fusion large est limitée aux racines ; les poids du crâne ne figent plus les extrémités relevées.

Le générateur rééchantillonne la surface hors ligne avant sa simplification pour éliminer les contacts irréguliers. La validation exige désormais une peau fermée, un seul composant et une caractéristique d’Euler de 2. Elle vérifie aussi, sur 97 poses à amplitude maximale, la distance des extrémités relevées à l’ellipsoïde de la tête dans le repère du corps. Résultat : minimum 0,177 unité de modèle, au-dessus du seuil 0,025 ; étirement maximal des arêtes 2,215. Ce contrôle ciblé ne prétend pas détecter toutes les collisions possibles entre les autres bras. Résultats complets dans `rig-validation.json`.


Build Release et test UI de saisie avant/après le trajet spatial : réussis pour cette correction. Comparaison : `comparaison.html` ; vidéo sous plusieurs angles sur un cycle d’animation : `../screenshots/poulpi-bras-libres.mp4`. Les anciennes vidéos de clignement et de rotation sont conservées comme étapes historiques ; elles ne représentent pas toutes la correction des attaches.

La mesure de performance de cette correction est conservée dans `rig-free-arms-performance.json`, séparément des étapes antérieures. Le contexte reste l’aperçu agrandi du simulateur iPhone 16, sans capture ni interaction pendant la mesure ; aucune garantie de cadence sur appareil physique n’en est déduite.


### Proportions rapprochées de la référence HD — pose fixe

La tête est élargie et moins haute, le manteau raccourci et les boucles des bras rapprochées. Les bras relevés restent avancés devant le corps, avec leurs extrémités détachées des joues. Le visage reçoit des blancs, iris et pupilles plus grands, des sourcils plus épais et une bouche plus volumineuse. Les poids du crâne sont immobilisés et la transition vers les articulations est diffusée hors ligne pour éviter que les nouveaux volumes déforment les côtés de la tête.

Comparaison actuelle : `comparaison-reference-hd.html`. La capture `../screenshots/poulpi-proportions.png` est prise dans le simulateur avec `--octopus-preview --octopus-still` (Debug uniquement), puis recadrée par CSS à côté de la référence HD. La silhouette, les matières et la douceur du sourire diffèrent encore de la référence ; cet aperçu ne constitue pas une reproduction exacte.

Validation géométrique de cette étape historique : 97 poses, peau fermée, un seul composant, caractéristique d’Euler 2 ; distance minimale des pointes relevées à l’ellipsoïde crânien 0,288 unité, étirement maximal des arêtes 2,735. Les détails sont dans `rig-validation.json`, qui remplace les résultats historiques évoqués plus haut. Builds Debug simulateur et Release iOS réussis. Le test UI de saisie avant et après le trajet spatial passe également sur le simulateur iPhone 16. Aucune nouvelle mesure de FPS n’est attribuée à cette version ; les fichiers de performance précédents restent historiques.


### Boucle de comparaison détaillée — douze passes

Le suivi des différences et des essais rejetés est conservé dans `ecarts-reference.md`. La page `comparaison-reference-hd.html` propose les captures successives et des zooms du visage, de la bouche et des bras. La capture au repos de la passe 12 est `../screenshots/poulpi-loop-12.png`. La ressemblance exacte n’est pas atteinte : les écarts restants sont explicités dans le suivi.

Les lèvres ont un contour arrondi à courbes de Bézier ; les yeux suivent un contour en poire, avec iris et pupilles conformés à la courbure du blanc. Le grain est procédural en coordonnées du modèle, avec atténuation selon la taille du pixel. Le blush et les dégradés utilisent les positions du modèle. Les 44 ventouses ont un fond fermé et un espacement régulier mesuré le long des bras. Les racines, les boucles, le manteau et les poids du squelette ont été repris. Tout le calcul de sculpture et de poids reste hors ligne.

Le drapeau Debug `--octopus-still` est maintenant appliqué dans `PoulpiRig.play`, afin qu’un changement d’état de la vue ne relance pas l’animation pendant la comparaison. Captures de vérification des paupières : `../screenshots/poulpi-loop-paupieres-mi-course.png` et `../screenshots/poulpi-loop-paupieres-fermees.png`.

Le générateur et le validateur doivent être lancés avec `blender -b --python-exit-code 1 --python ...` : Blender peut autrement retourner un code zéro même après une exception Python. Le contrôle de la passe 12 valide 97 poses, une seule surface fermée de caractéristique d’Euler 2, un étirement maximal de 1,898 et une distance minimale tête/pointe de 0,268 unité. Ce contrôle ne remplace pas l’inspection visuelle et ne prouve pas une identité avec la référence.


La passe 12 abaisse les extrémités des bras avant, ouvre les boucles latérales et prolonge le manteau entre les racines. La palette et un léger rebond diffus local rendent la jonction moins sombre. La validation UI (saisie avant/après le trajet et réaction/repos/pause) a passé sur la passe 11 ; la passe 12 ne change que la sculpture et les matières, et ses builds Debug/Release ainsi que le contrôle géométrique passent. Une rotation de contrôle actuelle est disponible dans `../screenshots/poulpi-boucle-12-360.mp4`.


Mesure de la passe 12 : quatorze fenêtres d’environ deux secondes, médiane SceneKit 60,0 FPS (minimum 59,5 ; maximum 60,0), cadence principale médiane 60,0 FPS. Contexte : aperçu agrandi animé sur simulateur iPhone 16 iOS 18.5 en Debug, sans capture, compilation ni interaction avec l’app pendant la fenêtre. Résultats et empreintes des sources : `rig-loop-performance.json`. Cela ne mesure pas une partie entière ni les performances d’un appareil physique. Le relief des paupières a également été réduit après inspection de profil, puis vérifié à mi-course et fermé.


### Boucle — passes 13 à 18

La capture de la passe 18 est : `../screenshots/poulpi-loop-18.png`, également conservée sous `poulpi-proportions.png`. Les proportions de tête ont été mesurées et corrigées après un essai trop allongé. Les bras arrière sont repliés sous le manteau, les boucles relevées raccourcies, la bouche agrandie, les sourcils épaissis et les iris indigo préservés des reflets blancs supplémentaires. Les ventouses ont un contour ovale et sont regroupées sur les courbes relevées. Les normales sont corrigées pour cette ovalisation.

Le domaine de sculpture englobe désormais les bras arrière et un contrôle explicite rejette toute surface qui atteint sa frontière. Cette vérification intervient avant le comblement de trous : celui-ci ne peut plus masquer une troncature du modèle. La passe 18 conserve 25 articulations, 44 ventouses et les deux mêmes maillages principaux ; sculpture, poids et ombres de plis restent calculés hors ligne.

Validation de la passe 18 : Debug et Release compilent ; 97 poses validées, peau fermée, un seul composant, Euler 2, étirement maximal 1,841 et distance minimale des pointes relevées à la tête 0,257 unité. La rotation de contrôle est `../screenshots/poulpi-boucle-18-360.mp4`. Son cadrage Debug a été élargi pour éviter de couper les bras arrière pendant la rotation ; la comparaison de face conserve sa caméra habituelle. Les tests UI de la passe 11 restent historiques.

La ressemblance n’est pas identique : la page liste séparément les écarts actuels sur les yeux, les lèvres, les joues, les espaces entre bras et les ventouses. Les étapes 13 à 18 figurent dans le sélecteur, avec l’essai 14 trop allongé clairement identifié.


Cadence de la passe 18 : 13 fenêtres de mesure, SceneKit et cadence principale à 60,0 FPS (minimum, médiane et maximum). Mesure séparée de la vidéo, sans compilation ni interaction avec l’app, sur l’aperçu animé Debug du simulateur iPhone 16 iOS 18.5. Ce résultat ne garantit pas les performances sur appareil physique. Sources et empreintes : `rig-loop18-performance.json`.


### Boucle — passes 19 à 27

Les blancs ont été recalés par échantillonnage de zones comparables (`face-color-samples.json`), les iris et pupilles amincis horizontalement sans réduire leur hauteur, et les reflets replacés. Les anciennes sphères de reflet ont été supprimées après détection d’une pénétration dans la paupière à mi-clignement : des masques filtrés sont maintenant portés par les surfaces courbes des yeux. Cela supprime quatre géométries et conserve l’occlusion des reflets pendant le clignement.

La bouche a un pli moins creusé, une vallée supérieure moins profonde et une position légèrement remontée. Le grain de peau comporte deux échelles, le blush a été repris et le rebond bleu local recentré. Les bras avant rejoignent plus progressivement le manteau. Les bras relevés sont amincis, leur naissance déplacée vers les côtés et leurs pointes écartées : les petits vides entre pointes et corps sont visibles. Le contour oculaire élargi de l’essai 25 a été rejeté car il masquait les blancs.

La dernière capture fixe est `../screenshots/poulpi-loop-27.png`, affichée par défaut dans la comparaison. Le cadrage animé est recentré pour laisser de la marge aux bras dans toute leur amplitude ; la caméra du mode de comparaison fixe est conservée. Les captures de contrôle du clignement sont `../screenshots/poulpi-loop27-paupieres-mi-course.png` et `../screenshots/poulpi-loop27-paupieres-fermees.png`.

La géométrie exportée de la passe 26 est conservée pour la passe 27 : 45 265 sommets / 90 526 triangles de peau, 44 ventouses et 25 articulations. Validation sur 97 poses : peau fermée, un seul composant, Euler 2, étirement maximal 1,845, distance minimale tête/pointe 0,257 unité. La ressemblance exacte reste non atteinte : insertion des yeux dans le visage, nuances des iris, modelé des boucles latérales et relief des ventouses avant restent différents.


Contrôles de la passe 27 : builds Debug et Release réussis. Les deux tests UI de réaction/repos/pause et de saisie avant/après le trajet spatial passent (2 tests, 0 échec ; 80,723 s). Résultat : `/tmp/lisa-units-ui-derived/Logs/Test/Test-SudokuLisa-2026.10.06_13-14-40-+0200.xcresult`. Le rig exporté de la passe 26 est inchangé, avec ses 97 poses validées.


Contrôle du cadrage animé : vidéo `../screenshots/poulpi-boucle-27-cycle.mp4` de 40,53 s, avec 160 images échantillonnées à 4 Hz. La silhouette garde au moins 28 pixels de marge en bas du cadre observé (`portrait-loop27-bounds.json`). Ce contrôle échantillonné complète l’inspection visuelle ; il ne mesure pas les FPS. Rotation de contrôle : `../screenshots/poulpi-boucle-27-360.mp4` de 46,35 s. Les captures à mi-fermeture et fermées ne montrent plus de reflet traversant les paupières.


Cadence de la passe 27 : 28 fenêtres de mesure, minimum/médiane/maximum à 60,0 FPS pour SceneKit et la cadence principale, sur l’aperçu agrandi animé du simulateur iPhone 16 iOS 18.5. Mesure sans capture, compilation ni interaction avec l’app, avec empreintes des sources et du modèle dans `rig-loop27-performance.json`. Ce résultat ne garantit pas une cadence sur appareil physique.


## Passe 35 — lèvres sculptées hors ligne

La bouche est désormais un maillage fermé pré-calculé, composé de deux lèvres fusionnées. Le relief orbital supérieur est intégré à la peau, les iris comportent davantage de variations et les normales des extrémités des tubes sont corrigées. Les tentatives 28 à 35 sont disponibles dans le comparatif et détaillées dans `ecarts-reference.md`.

Debug et Release compilent. Le rig passe 97 poses, la bouche est fermée et connexe. Mesure de l'aperçu animé sur simulateur : médiane 60 FPS, minimum SceneKit 57 FPS (`rig-loop35-performance.json`). Les tests UI présentent un échec intermittent de retour au repos ; le cas passe ensuite sans modification fonctionnelle après redémarrage. Le journal détaille les limites de cette validation. La ressemblance exacte reste non atteinte.


## Passe 39 — volume et placement des ventouses

Ventouses plus épaisses, 1 056 triangles dégénérés supprimés, placement par rayon depuis le centre du bras et espacement mesuré sur la peau. Les ventouses avant ne se chevauchent plus dans le portrait de contrôle ; celles des pointes sont plus ovales. Les bras avant sont plus pleins et les blancs des yeux plus bombés.

Debug/Release compilent ; validateur à 97 poses réussi. Le clignement contrôlé aux deux positions masque correctement les iris. Aperçu sur simulateur : 22 fenêtres à 60 FPS ; cycle animé échantillonné avec 20 pixels de marge inférieure minimale. Voir `ecarts-reference.md`, `rig-loop39-performance.json`, `cup-spacing-loop39.json` et `portrait-loop39-bounds.json` pour les preuves et limites. La ressemblance exacte reste non atteinte.


## Passe 44 — iris issus de la référence

Les deux régions d'iris de `poulpi-reference-hd.png` sont projetées par UV sur les calottes courbes des yeux. Une image mise en cache est partagée, avec filtrage linéaire, mipmaps et anisotropie. Le pigment est opaque malgré l'alpha partiel du PNG. Deux surfaces de pupilles et les anciens shaders de fibres/reflets sont supprimés. Les sourcils ont des extrémités plus finement arrondies et le regard remonte légèrement.

La copie de texture ajoute environ 1,3 Mo au contenu source de l'app ; le personnage reste une sculpture 3D articulée. Régions et empreinte dans `iris-reference-mapping.json`. Debug/Release compilent, clignements à mi-course et fermés contrôlés, rotation disponible. 23 fenêtres de mesure à 60 FPS sur le simulateur (`rig-loop44-performance.json`), sans garantie pour les appareils physiques. Les blancs et leur contour, la matière des sourcils et du corps, la bouche et les boucles latérales restent différents de la référence.


## Passe 47 — blancs des yeux et grain des sourcils

L'essai 45, trop jaune, est rejeté au profit d'une correction limitée des ombres (46). Les sourcils reçoivent ensuite le grain filtré de la peau avec un matériau plus bleu (47). Le code de grain est partagé ; la région du corps contrôlée reste identique pixel pour pixel entre 46 et 47. Les échantillons de couleur et leurs limites sont dans `eye-white-samples-loop47.json`.

Debug et Release compilent. Aperçu sur simulateur : médiane 60 FPS, minimum SceneKit 59,5 FPS (`rig-loop47-performance.json`). La géométrie et l'animation restent celles validées précédemment ; rotation et clignements de la passe 44 sont explicitement historiques. L'identité visuelle n'est toujours pas atteinte.


## Passe 51 — contour et matière des lèvres

La bouche est reconstruite depuis le contour mesuré de la référence (`measure_mouth.py`, `mouth-reference-contour.json`). Le creux est sculpté, le volume fermé, puis le maillage réduit à 18 926 triangles avec contrôle de déviation (`mouth-reduction.json`). La texture des lèvres partage le même fichier que les iris, sur ce volume 3D. Le rendu conserve une part d'éclairage peinte dans la texture.

Le corps, les ventouses et le squelette restent identiques à la passe 47. Validation à 97 poses et UV réussie ; Debug/Release compilent ; 30 fenêtres à 60 FPS sur l'aperçu du simulateur (`rig-loop51-performance.json`). La rotation 50 est disponible. Le contour de bouche est plus proche selon le contrôle local documenté dans `mouth-silhouette-loop51.json`, sans que cela constitue un score de ressemblance globale. Texture du corps, raccords des yeux, boucles latérales et rangées arrière restent à améliorer.


## Passe 54 — couleur de peau et ombres

L'inversion de l'éclairage (52) est rejetée. Le dégradé violet/bleu, le contact sous la bouche et le bleu des courbes basses sont repris (53–54), sans toucher au maillage ni aux animations. Onze petites zones de couleur montrent une baisse d'écart moyen de 12,00 à 7,64 niveaux RGB ; ce n'est pas un score global de ressemblance. Détails et limites : `skin-colour-loop54.json` et `ecarts-reference.md`. La comparaison affiche désormais 54 ; les différences de forme et de texture restent visibles.

Validation de 54 : builds Debug simulateur et Release iOS réussis. Aperçu animé sur simulateur iPhone 16 iOS 18.5, sans compilation, capture ni interaction pendant la mesure : SceneKit minimum 59,5 / médiane 60 / maximum 60 FPS ; cadence principale 59,7 / 60 / 60 FPS. Empreintes et fenêtres dans `rig-loop54-performance.json`. Cela ne garantit ni les appareils physiques ni le jeu complet. Les 56 choix du comparatif chargent et `git diff --check` passe. Les vidéos et contrôles géométriques antérieurs restent historiques.


## Passe 62 — profondeur des boucles latérales

Les deux bras latéraux sont abaissés et leurs pointes avancées pour les rendre visibles. Plusieurs trajectoires provoquant des contacts sont rejetées par le contrôle topologique. La version retenue est fermée, connexe, Euler 2 et passe les 97 poses. Les rangées latérales comportent quatre ventouses orientées vers le dessous extérieur, soit 40 pour le personnage. Le journal détaille les essais 55 à 62. Les boucles restent moins creusées que celles de la référence ; l'identité visuelle n'est pas atteinte.
