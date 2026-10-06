# Poulpi — suivi des écarts avec la référence

Référence : `poulpi-reference-hd.png`. Comparaison : `comparaison-reference-hd.html`.
La référence reste affichée à gauche ; les rendus de droite viennent de l’application.
Un build ou un test géométrique réussi ne valide pas la ressemblance.

## État initial de la boucle (6 octobre)

| Zone | Différence constatée | Correction recherchée |
| --- | --- | --- |
| Silhouette | Tête trop étroite par rapport à l’envergure des bras ; manteau pincé et bras avant massifs. | Tête dominante, continuité souple du bas des joues vers les racines. |
| Yeux | Blancs trop petits, ovales réguliers, liseré violet trop épais. | Blancs plus larges, légèrement en poire, bord intégré au visage. |
| Regard | Pupilles trop centrées, reflets spéculaires supplémentaires. | Regard légèrement convergent, grands iris indigo, reflet principal doux. |
| Sourcils | Trop courts et brillants, petites extrémités anguleuses. | Deux coussinets courbes avec bouts ronds et matière identique à la peau. |
| Bouche | Coins pointus, sourire en croissant rigide, orange brillant. | Contour arrondi en deux lobes, lèvres épaisses, pli courbe discret. |
| Peau | Surface plastique, grain presque invisible, sommet rose-violet. | Grain organique fin, violet bleuté, transition douce vers le bleu. |
| Joues | Rose trop discret et trop peu diffus. | Blush rose tendre visible sous les yeux. |
| Ventouses | Petits anneaux percés visuellement, très brillants, positions parfois hors de la face inférieure. | Coussinets crème plus grands, petite dépression fermée, orientation cohérente sous chaque bras. |
| Bras relevés | Boucles trop ouvertes et trop écartées, mains petites. | Boucles compactes, extrémités rondes, libres devant les joues. |
| Bras avant | Volumes larges, extrémités peu lisibles et ventouses sur le devant supérieur. | Deux U plus fins, extrémités remontant vers l’extérieur, ventouses sur le bord inférieur. |
| Éclairage | Blancs écrêtés et reflets durs. | Volumes lisibles, éclairage doux, crème et violet non surexposés. |

## Règles de validation

- Capture au repos, même caméra, même cadrage, sans modifier l’image du modèle.
- Inspecter aussi le clignement et plusieurs angles après une modification de géométrie.
- Conserver huit bras articulés et les pointes libres de la tête.
- Valider le maillage et les déformations ; contrôler le coût réel avant toute affirmation de FPS.
- Ne pas remplacer le personnage 3D par la référence plate pour fausser la comparaison.
- Ne pas déclarer « identique » tant que des différences visibles restent présentes.

## Passes de la boucle

1. Lèvres à contour de Bézier arrondi, yeux agrandis, ventouses fermées plus volumineuses et matériaux moins brillants. Le premier grain était trop régulier.
2. Yeux en poire, tête élargie, bras latéraux dégagés, correction du drapeau de pose fixe. La texture normale cylindrique révélait des stries sur les bras : rejetée.
3. Grain procédural en coordonnées du modèle, filtré selon la taille du pixel ; sourcils plus longs et pupilles sans reflets spéculaires parasites.
4. Visage repositionné à partir des rapports observés sur la référence : yeux plus espacés et plus bas, sourcils abaissés, envergure réduite. Couleurs et blush positionnés dans le volume. La diffusion des poids a été renforcée hors ligne après échec du contrôle des déformations ; validation réussie ensuite.
5. Boucles relevées plus basses et plus proches du visage, bras avant amincis, dessous des tentacules tourné progressivement vers l’avant pour montrer les ventouses. Validation : 97 poses, étirement maximal de peau 2,304, distance minimale tête/pointe relevée 0,281 unité.
6. Raccord du manteau élargi et répartition des ventouses à distance égale le long des courbes. Validation géométrique réussie.
7. Essai de ventouses sans éclairage physique : rejeté après capture, leur volume devenait visuellement plat. Bouche avancée pour conserver tout le contour.
8. Éclairage de rebond sous le personnage et nouveau raccord du manteau. Le relief des ventouses revient, mais le nouveau volume masque le bord inférieur des blancs des yeux : à corriger avant conservation.
9. envergure des bras réduite indépendamment de la tête, yeux avancés pour éliminer cette intersection, éclairage inférieur atténué et grain plus fin.
10. Racines avant amincies avec davantage de volume dans les courbes basses ; rayons des bras relevés repris et axes des yeux inclinés. L’essai d’iris plus fins révèle une intersection avec le blanc : rejet de ces sphères aplaties.
11. Iris et pupilles construits sur des calottes qui suivent la courbure du blanc. Les captures au repos, à mi-fermeture et fermées ne montrent plus les débordements observés auparavant.
12. Extrémités des bras avant abaissées, boucles latérales plus ouvertes, manteau prolongé entre les racines. Palette ajustée et ombre du raccord adoucie par un rebond diffus local. La direction d’éclairage inversée lors d’un essai a été rejetée ; celle de la passe précédente est conservée.

13. Bras arrière repliés sous le manteau pour occuper une partie du vide central, avec des indices de ventouses visibles derrière les bras avant.
14. Descente du volume crânien et agrandissement du domaine de sculpture. Un contrôle empêche maintenant qu’un bras soit tronqué puis artificiellement refermé à la frontière du domaine. Le crâne devient trop allongé : cette proportion n’est pas conservée. Fibres d’iris moins fines pour rester visibles à la taille de rendu.
15. Tête rééquilibrée à partir des contours mesurés ; bouche agrandie de 10 % et avancée pour préserver les lobes. Le centre vertical du contour supérieur passe de 0,314 à 0,339 hauteur de personnage (référence : 0,337), sa demi-largeur de 0,353 à 0,342 (référence : 0,339). Ces mesures ne qualifient ni les matières ni la ressemblance globale.

16. Boucles relevées raccourcies verticalement pour dégager les bras latéraux. Iris indigo sans reflet PBR blanc supplémentaire ; leur calotte, le reflet cornéen et le mouvement du regard sont conservés. Validation : 97 poses, étirement maximal 1,841, distance tête/pointe 0,257 unité.

17. Ventouses ovalisées dans le sens du bras, avec correction des normales ; les quatre ventouses des bras relevés sont resserrées sur l’arc extérieur. Fréquences des fibres d’iris réduites pour limiter leur disparition sous le filtrage à petite taille.

18. Ruban inférieur des bras relevés tourné davantage vers l’avant, avec dernière ventouse replacée avant le sommet de la boucle ; sourcils épaissis et plus inclinés.

19. Blancs d’yeux moins jaunes, iris plus nuancés, rebond bleu dans la pupille et pli des lèvres moins creusé. La capture révèle encore une ombre trop sombre au bas du blanc, et un rebond de pupille trop marqué : essai intermédiaire.
20. Rebond diffus local au bas du blanc et réduction du rebond bleu des pupilles. Trois zones de l’œil sont mesurées sur les captures de référence et du modèle (`face-color-samples.json`) : les couleurs se rapprochent, sans que ces échantillons prouvent une identité du regard.
21. Grain de peau à deux échelles, avec filtrage selon la taille du pixel ; bleu du raccord sous la tête renforcé et blush repris. Le grain reste calculé dans les coordonnées du modèle, sans texture étirée sur les tentacules. Le bleu déborde encore légèrement vers les joues et le raccord géométrique demeure trop marqué.

22. Racines des bras avant remontées et raccordées progressivement au manteau, avec fusion locale réservée à ces deux bras. Le brusque départ vers l’avant est atténué ; le rebond bleu reste centré, hors des joues.
23. Naissance des bras relevés décalée vers les côtés, avec rayon décroissant davantage vers les pointes. Les extrémités restent libres et le contrôle topologique conserve une seule surface sans poignée.
24. Iris et pupilles amincis horizontalement, avec hauteur conservée : le zoom révélait des iris presque circulaires au lieu des ovales de la référence. Fibres atténuées pour éviter un aspect strié ; blanc de l’œil droit légèrement réchauffé.
25. Essai de contour oculaire plus large : rejeté, car sa surface recouvre le bord des blancs et forme un anneau épais. La correction indépendante du sourire est conservée : vallée supérieure moins profonde et bouche légèrement remontée.

26. Pointes relevées déplacées légèrement vers l’extérieur et le haut ; les petites ouvertures entre ces pointes et le corps redeviennent visibles. Le contour oculaire de l’essai 25 est retiré ; son sourire est conservé. Rig : 97 poses validées, étirement maximal 1,845, distance tête/pointe 0,257 unité.
27. Reflets du regard remontés et décalés comme sur la référence. Le contrôle à mi-clignement détecte une pénétration des anciennes petites sphères de reflet dans la paupière. Elles sont remplacées par des masques filtrés sur les surfaces courbes de l’iris et de la pupille : quatre géométries sont supprimées et les reflets suivent l’occlusion réelle de l’œil. Le cadrage animé est recentré pour laisser de la marge aux bras, tandis que la caméra fixe de comparaison conserve ses paramètres.

Les captures numérotées sont des étapes, pas une promesse de résultat identique. La passe 1 pouvait encore bouger lors de la capture ; le verrouillage de la pose a été corrigé à partir de la passe 2. Les mesures de FPS historiques ne sont pas attribuées aux nouvelles passes.


## Écarts encore visibles après la passe 27

- Les boucles latérales sont plus verticales et moins enveloppantes que dans la référence ; les bras arrière restent moins distincts de face.
- Le raccord sous la tête et la distribution des volumes des deux bras avant ne suivent pas encore exactement le contour original.
- Le relief des paupières fermées a été réduit après inspection de profil ; la référence fournie ne montre pas cette pose HD et ne permet pas d’en confirmer une ressemblance exacte.
- La texture de l’iris, le grain de peau et les reflets ne reproduisent pas exactement le rendu photographique stylisé de la référence.
- Les ventouses sont correctement fermées et mieux espacées, mais leurs orientations et leur coloration diffèrent encore par endroits.

Mesure indicative de la silhouette : largeur/hauteur 1,037 avant la boucle, 0,908 à la passe 11, référence 0,917. Cela mesure uniquement l’encombrement, pas un pourcentage de ressemblance. Méthode et bornes : `visual-measurements.json`.


Contrôles de la passe 12 : builds Debug/Release réussis, géométrie validée sur 97 poses, vérification visuelle des yeux ouverts/mi-clos/fermés et rotation. Tests UI de saisie spatiale et de réaction/repos/pause réussis sur la passe 11, avant la dernière retouche de sculpture et de matériaux. Cadence mesurée séparément : médiane SceneKit 60 FPS, minimum 59,5 FPS, sur simulateur uniquement (`rig-loop-performance.json`).

## Prochaine passe ciblée

Le contour supérieur des yeux reste trop plat et leur insertion paraît moins naturelle que dans la référence. L’essai 25 montre qu’agrandir simplement la coque violette recouvre les blancs ; il faut travailler la courbure du visage autour des orbites. Les iris ont de meilleures proportions, mais leur texture et leur profondeur restent différentes. Les espaces près des pointes relevées sont revenus, tout en restant plus étroits que dans l’image. Les boucles latérales, le profil des ventouses avant et la douceur des matières restent à rapprocher de la référence.


Contrôles de la passe 18 : builds Debug/Release réussis, 97 poses validées, 45 989 sommets / 91 974 triangles pour la peau. L’inspection en rotation a révélé un recadrage trop serré en vue arrière ; seul le cadrage du mode Debug de rotation a été élargi. La capture fixe conserve les mêmes paramètres de caméra que les passes précédentes.


Cadence de la passe 18 : 13 fenêtres de mesure, SceneKit et cadence principale à 60,0 FPS (minimum, médiane et maximum). Mesure séparée de la vidéo, sans compilation ni interaction avec l’app, sur l’aperçu animé Debug du simulateur iPhone 16 iOS 18.5. Ce résultat ne garantit pas les performances sur appareil physique. Sources et empreintes : `rig-loop18-performance.json`.


Contrôles de la passe 27 : builds Debug et Release réussis. Les deux tests UI de réaction/repos/pause et de saisie avant/après le trajet spatial passent (2 tests, 0 échec ; 80,723 s). Résultat : `/tmp/lisa-units-ui-derived/Logs/Test/Test-SudokuLisa-2026.10.06_13-14-40-+0200.xcresult`. Le rig exporté de la passe 26 est inchangé, avec ses 97 poses validées.


Contrôle du cadrage animé : vidéo `../screenshots/poulpi-boucle-27-cycle.mp4` de 40,53 s, avec 160 images échantillonnées à 4 Hz. La silhouette garde au moins 28 pixels de marge en bas du cadre observé (`portrait-loop27-bounds.json`). Ce contrôle échantillonné complète l’inspection visuelle ; il ne mesure pas les FPS. Rotation de contrôle : `../screenshots/poulpi-boucle-27-360.mp4` de 46,35 s. Les captures à mi-fermeture et fermées ne montrent plus de reflet traversant les paupières.


Cadence de la passe 27 : 28 fenêtres de mesure, minimum/médiane/maximum à 60,0 FPS pour SceneKit et la cadence principale, sur l’aperçu agrandi animé du simulateur iPhone 16 iOS 18.5. Mesure sans capture, compilation ni interaction avec l’app, avec empreintes des sources et du modèle dans `rig-loop27-performance.json`. Ce résultat ne garantit pas une cadence sur appareil physique.


## Passes 28 à 33 — contour des yeux et volume des lèvres

- **28** : relief orbital supérieur sculpté dans la peau, sans agrandir la coque des yeux. Le bord est plus intégré, mais la lumière reste plus dure que sur la référence.
- **29** : convergence des pupilles légèrement accrue. Essai de pli du sourire trop haut ; cette position n'est pas conservée.
- **30** : bouche resserrée et rehaussée, pli ramené plus bas avec une teinte rouge dans le creux. Le maillage radial montre encore une transition anguleuse au centre.
- **31, rejetée** : essai de bosses gaussiennes pour les lèvres. Volume trop massif et silhouette moins fidèle ; retour à la surface de la passe 30.
- **32** : correction du seuil de normalisation des petites faces. Cela atténue un défaut central mais ne résout pas la construction radiale des lèvres.
- **33** : remplacement de cette construction par deux lèvres sculptées hors ligne et fusionnées en un maillage fermé. Le creux a une profondeur réelle, visible en géométrie. Le sourire est encore trop creusé en U ; la densité initiale (59 582 triangles pour la bouche) est excessive.

Les captures numérotées sont celles du simulateur, à caméra fixe. Builds Debug réussis pour 28 à 33. Le rig de la passe 28 comporte 90 882 triangles de peau et 12 672 de ventouses ; ses 97 poses passent le contrôle de déformation, avec une distance minimale tête/pointe relevée de 0,2565 unité. La passe 33 ajoute une bouche fermée (Euler 2, aucun bord ouvert/non manifold). Les mesures de cadence et tests UI de la passe 27 restent des résultats historiques, pas des mesures de ces nouvelles passes.


## Passes 34 et 35 — lèvres, iris et normales

La passe 34 réduit la courbure en U de la bouche et ramène son maillage à 25 486 triangles (contre 59 582 en passe 33, soit 57 % de moins). Son matériau est moins saturé et moins rugueux. Le contrôle vérifie désormais explicitement une seule composante connexe, des triangles non dégénérés et des normales unitaires, en plus de la fermeture et d'Euler 2.

La passe 35 abaisse légèrement les lèvres pour retrouver leur position sous les yeux. Les iris reçoivent des variations radiales et angulaires supplémentaires, avec filtrage des fibres fines. Les normales des tubes des sourcils et des plis de paupières sont calculées sur leur surface réelle, y compris les extrémités effilées ; leur section passe de 16 à 24 côtés. Ces calculs sont faits à la construction, pas à chaque image.

Écarts encore visibles : blanc des yeux moins bombé, contour inférieur trop sombre, relief et matière des sourcils différents ; iris moins profonds ; commissures de bouche trop régulières ; grain de peau moins organique ; ouvertures des bras relevés plus petites, espaces entre bras avant et arrière trop marqués ; ventouses avant plus plates et certaines trop claires. L'identité visuelle n'est pas atteinte.

Builds Debug et Release de la passe 35 réussis. Le corps et les ventouses passent les 97 poses du validateur ; bouche fermée, une composante, normales unitaires. Les vidéos de la passe 27 restent explicitement historiques.


Validation complémentaire de la passe 35 :

- Le test spatial passe (48,046 s). Le test réaction/repos/pause échoue deux fois sur le délai de retour au repos. L'instrumentation temporaire observe ensuite le retour effectif après 4,856 s et ce test passe. Après retrait des traces et redémarrage du simulateur, le test normal passe également (31,292 s), sans augmenter son délai ni changer la logique de l'app. La cause des deux premiers échecs n'est pas démontrée.
- Plusieurs sessions Xcode restent ouvertes après la fin des cas de test ; elles sont arrêtées explicitement. Une tentative pendant cette phase échoue au lancement du simulateur et n'est pas utilisée comme validation. Le résultat exploitable est le journal des cas passés, pas un statut global `TEST SUCCEEDED` de la dernière commande (interrompue après son cas passé).
- Cadence indépendante des tests et captures : 21 fenêtres SceneKit, minimum 57,0 / médiane 60,0 / maximum 60,0 FPS ; 20 fenêtres de cadence principale, 60,0 / 60,0 / 60,1 FPS. Aperçu animé agrandi, simulateur iPhone 16 iOS 18.5, Debug. Sources et modèle identifiés par empreinte dans `rig-loop35-performance.json`. Ce n'est ni une mesure du jeu complet ni une garantie sur appareil physique.
- Les 37 choix de captures du comparatif chargent correctement. `git diff --check` passe.


Rotation de la passe 35 : `../screenshots/poulpi-boucle-35-360.mp4`, 21,79 s. Inspection des vues trois-quarts et latérale : le volume des lèvres est lisible ; les yeux restent trop rapportés sur la tête et le raccord arrière du manteau demeure marqué. Cette rotation ne sert pas de mesure de cadence.


## Passe 36 — volume des ventouses

Le rebord des ventouses est épaissi, avec un creux central peu profond. Chaque centre est désormais un sommet axial unique ; les anciennes faces dégénérées entre les sommets centraux superposés sont supprimées. Les 44 ventouses passent de 7 392 sommets / 12 672 triangles à 6 380 sommets / 11 616 triangles. Le validateur contrôle aussi les normales unitaires, l'absence de triangles dégénérés et les 44 bases ouvertes enterrées dans les bras. Les 97 poses passent.

L'essai de matière moins blanche produit cependant un dessous trop sombre et doré : cette teinte n'est pas retenue telle quelle. Le gros plan des bras confirme le manque de volume des deux bras avant et une ouverture centrale trop large. Capture de contrôle : `../screenshots/poulpi-loop-36.png`. Build Debug réussi.


## Passes 37 à 39 — bras avant, courbure oculaire et espacement

**37** : le rayon des deux bras avant augmente de 0,02 unité, ce qui réduit l'ouverture centrale et rapproche leur volume de la référence. La tentative de matière de ventouses reste trop sombre. Corps : 46 106 sommets / 92 208 triangles, fermé, connexe, Euler 2. Le contrôle des 97 poses passe ; distance minimale des pointes relevées à la tête : 0,2566 unité.

**38** : le bombé des blancs passe de 0,0565 à 0,07458 unité et la projection des iris suit la même surface. Contrôle visuel avec `poulpi-loop38-paupieres-mi-course.png` et `poulpi-loop38-paupieres-fermees.png` : pas de blanc, iris ou reflet visible au travers des paupières fermées ; les reflets sont aussi correctement masqués à mi-course. La matière des ventouses reçoit davantage de lumière de remplissage par son émission, sans lumière ni passe de rendu supplémentaire. Leur dessous est plus lisible, mais la teinte reste localement trop dorée.

**39** : le placement par point de surface le plus proche est remplacé par un rayon depuis le centre de chaque bras, dans la direction de son dessous. L'espacement est mesuré sur ce chemin de surface plutôt que sur l'axe interne du bras. Les ventouses avant ne se tassent plus deux à deux ; celles des pointes sont plus ovales. Entre les passes 35 et 39, la distance minimale des centres des faces de ventouses adjacentes sur les bras avant passe d'environ 0,04 à 0,151 unité (`cup-spacing-loop39.json`). Cette comparaison inclut l'épaississement des bras de la passe 37 ; ce n'est pas une preuve d'absence de collision pour toute pose possible.

Le validateur vérifie maintenant les 44 boucles de bord des bases des ventouses, leurs normales unitaires et l'absence de triangles dégénérés. Les 97 poses et les boucles d'animation passent. Debug et Release de la passe 39 compilent. Aucune modification de logique de jeu ou de temporisation ; les tests UI de la passe 35 restent historiques, avec l'intermittence documentée.

La ressemblance exacte reste non atteinte : grain et lumière trop uniformes, bouche aux commissures trop régulières, yeux encore rapportés, sourcils différents, boucles latérales et ouvertures des bras relevés à reprendre.


Contrôles finaux de la passe 39 :

- Aperçu animé sur simulateur iPhone 16 iOS 18.5 : 22 fenêtres SceneKit et 22 fenêtres de cadence principale, minimum/médiane/maximum 60,0 FPS. Mesure sans compilation, capture ou interaction, avec empreintes vérifiées dans `rig-loop39-performance.json`. Cela ne garantit pas les performances sur appareil physique.
- Cycle animé de 46,15 s (`../screenshots/poulpi-boucle-39-cycle.mp4`), 182 images échantillonnées à 4 Hz : marge inférieure minimale de 20 pixels dans le cadre observé, selon `portrait-loop39-bounds.json`. Le personnage reste dans le cadre sur cet échantillon ; ce contrôle n'est pas une mesure de cadence.
- Rotation de 31,02 s (`../screenshots/poulpi-boucle-39-360.mp4`). La vue trois-quarts montre les rangées avant régulièrement espacées ; l'implantation des rangées arrière reste différente de la référence et doit encore être affinée.
- Les 41 choix du comparatif chargent. La capture courante correspond exactement au fichier de la passe 39. `git diff --check` passe.


## Passes 40 à 44 — détails des iris de référence

**40, rejetée** : premier essai de texture des iris sur leurs calottes courbes. Les coordonnées verticales étaient inversées pour la texture UIImage utilisée par SceneKit ; la capture montre la mauvaise région de l'image.

**41** : le repérage corrigé échantillonne séparément les deux iris de la référence. Les fibres et reflets sont plus fidèles, mais la transparence du PNG éclaircit les pupilles au-dessus des blancs.

**42** : le pigment de l'iris est rendu opaque dans le shader. Cela supprime les éclaircissements parasites et conserve le bleu profond. Une seule calotte courbe par œil remplace les deux surfaces iris/pupille ; les reflets font partie de la texture et sont masqués par les paupières. La référence complète est conservée comme texture partagée de 1254 × 1254, mais seules ses deux régions d'iris sont échantillonnées. Les autres parties du personnage restent sculptées et animées en 3D. Provenance et régions dans `iris-reference-mapping.json`.

**43** : les sourcils passent de 17 à 49 sections longitudinales. Le profil arrondi aux extrémités dépend désormais de la distance réelle le long du tube et de son rayon, plutôt que d'un nombre fixe de sections. Longueur légèrement augmentée, rayon de 0,044 à 0,046 et inclinaison au repos de 0,22 à 0,28 radian. L'animation utilise la même nouvelle base. Les plis de paupières, construits par la même fonction, bénéficient aussi du profil calculé en longueur réelle.

**44** : le regard remonte de 0,02 unité ; la projection de la calotte sur le blanc est recalculée à cette position. Les iris et les reflets s'alignent mieux avec le portrait de référence. Les captures `poulpi-loop44-paupieres-mi-course.png` et `poulpi-loop44-paupieres-fermees.png` ne montrent pas de débordement de reflets ou d'iris au travers des paupières.

Debug et Release de la passe 44 compilent. Le maillage articulé et sa validation à 97 poses sont inchangés depuis la passe 39 ; les changements concernent le visage. La mesure indépendante de l'aperçu sur simulateur donne minimum/médiane/maximum à 60 FPS pour SceneKit et la cadence principale (`rig-loop44-performance.json`). Cette mesure ne garantit pas les appareils physiques ni le jeu complet. Les tests UI de la passe 35 restent historiques, avec leur intermittence documentée.

Écarts encore visibles : contraste et teinte des blancs, raccord des yeux à la peau, grain absent des sourcils, commissures de bouche trop régulières, texture du corps et lumière plus uniformes, courbure des bras latéraux et rangées arrière de ventouses différentes. L'identité visuelle n'est pas atteinte.


Contrôles complémentaires de la passe 44 : 23 fenêtres à 60 FPS pour chacune des deux cadences, empreintes des sources, du rig et de la texture vérifiées. La texture est bien copiée dans le bundle Debug. Rotation `../screenshots/poulpi-boucle-44-360.mp4` de 64,55 s ; inspection trois-quarts : les détails des iris restent sur les yeux courbes pendant la rotation. Les 46 choix de captures du comparatif chargent et `git diff --check` passe. Le cycle frontal de la passe 39 reste explicitement étiqueté comme historique.


## Passes 45 à 47 — couleur des blancs et texture des sourcils

**45, rejetée** : réchauffement général des blancs et augmentation de leur lumière de remplissage. Les six zones de couleur échantillonnées montrent un écart plus important : les yeux deviennent trop jaunes, et l'œil droit est trop assombri.

**46** : retour à la matière de la passe 44, avec correction limitée de la lumière dans les ombres basses et une faible réduction du bleu de l'œil droit. Les médianes RGB de six zones 7 × 7, approximativement correspondantes, sont conservées dans `eye-white-samples-loop47.json`. Sur ces seules zones, l'écart RGB absolu moyen passe de 4,44 niveaux en 44 à 11,56 en 45 puis 3,61 en 46. Ce diagnostic local de couleur n'est pas une mesure de ressemblance globale.

**47** : les sourcils reçoivent le même grain volumétrique à deux échelles que la peau, filtré selon la taille des pixels pour les vues lointaines. Leur matériau est plus bleu et légèrement moins rugueux. Les définitions du grain sont mutualisées dans le code ; la région de corps (150,1380,880,420) des captures 46 et 47 présente un écart RGB maximal nul. Les sourcils seuls changent dans cette passe.

Debug et Release passent. La géométrie articulée reste inchangée depuis 39 ; les iris et leurs déplacements restent ceux de 44, ainsi que les contrôles de clignement. Nouvelle mesure indépendante de l'aperçu sur simulateur : SceneKit minimum 59,5 / médiane 60,0 / maximum 60,0 FPS ; cadence principale 60,0 / 60,0 / 60,1 FPS. Empreintes dans `rig-loop47-performance.json`. Cela ne mesure pas les appareils physiques ni le jeu complet.

Restent les raccords des yeux, la silhouette et le pli de la bouche, les détails de matière et de lumière du corps, les boucles latérales des bras et certaines orientations de ventouses. La bouche est le prochain écart de forme le plus visible dans le gros plan du visage.


## Passes 48 à 51 — bouche reconstruite depuis la référence

**48** : `measure_mouth.py` relève le contour orange et ajuste une parabole au pli du sourire, sans modifier l'image source. La bouche couvre [544,555] à [706,658] pixels. `mouth_surface.py` construit un volume fermé suivant ce contour, avec une profondeur réelle et un creux. Le premier rendu est trop creusé et son bord trop irrégulier ; il compte 53 662 triangles.

**49** : creux réduit, contour lissé, hauteur ajustée et matériau plus chaud. Le maillage haute résolution lissé compte 54 076 triangles ; la réduction hors ligne en conserve 18 926 (environ 65 % de moins). Les distances bidirectionnelles échantillonnées aux sommets et aux centres des triangles restent inférieures à 0,000072 unité avant la mise à l'échelle x/y (`mouth-reduction.json`). Ce contrôle porte sur la réduction, pas sur le lissage précédent ni sur une borne exhaustive de Hausdorff. Le volume est fermé, connexe, Euler 2, avec des normales unitaires.

**50** : la texture de la bouche de référence est projetée par UV sur ce volume. Elle partage l'image déjà utilisée pour les iris. Le pigment est opaque, ce qui évite de laisser apparaître la peau derrière les zones sombres. L'éclairage frontal est en partie peint dans la texture : il ne se recalcule pas comme un matériau PBR, mais la géométrie, les déformations et l'occlusion restent 3D. La rotation de contrôle montre le relief en vue latérale.

**51** : alignement légèrement corrigé et ombre de contact douce sous les lèvres. Dans le test local de silhouette orange, sans recalage des captures, le recouvrement intersection/union passe de 0,824 en 47 à 0,934 en 51. Les limites du seuil de couleur et du repérage CSS sont explicites dans `mouth-silhouette-loop51.json` ; ce n'est pas un score de ressemblance du personnage.

Le corps, les ventouses et le squelette sont identiques à ceux de la passe 47, vérifiés dans les données exportées. Le validateur passe 97 poses et contrôle aussi les UV de la bouche. Debug et Release de la passe 51 compilent. Les nouvelles captures restent à caméra fixe. Les contrôles de clignement de 44 et les tests UI historiques restent explicitement ceux des versions précédentes ; aucune logique de jeu n'est modifiée.

Restent surtout la texture et la lumière du corps, le raccord des yeux à la tête, les boucles latérales et les rangées arrière de ventouses. Le raccord inférieur de la bouche est encore moins doux que celui de la référence. L'identité visuelle n'est pas atteinte.


Contrôles finaux de la passe 51 : aperçu animé sur simulateur iPhone 16 iOS 18.5, 30 fenêtres SceneKit et 30 fenêtres de cadence principale, minimum/médiane/maximum à 60 FPS. Mesure séparée de la compilation et des captures, avec empreintes dans `rig-loop51-performance.json`. Pas de garantie sur appareil physique ou pour le jeu complet. Rotation de la passe 50 : 44,24 s, réencodée en H.264 CRF 18 pour réduire le poids du fichier de revue ; elle n'est pas utilisée pour mesurer les FPS.


## Passes 52 à 54 — dégradé et lumière de la peau

**52, rejetée** : inversion gauche/droite des deux lumières principales. Malgré l'hypothèse initiale tirée de la référence, le rendu réel dégrade l'asymétrie des yeux et des tempes. Sur onze petites zones de peau, l'écart RGB absolu moyen augmente de 12,00 à 14,64. Les positions des lumières reviennent exactement à celles de 51.

**53** : transition violet/bleu plus haute et douce, baisse de la lumière uniforme du manteau et ombre de contact élargie sous la bouche. Cette ombre atténue aussi l'émission. Les onze zones donnent 9,85 niveaux d'écart moyen.

**54** : baisse du vert au milieu du visage et remplissage bleu local sur les courbes basses des tentacules. Les ventouses gardent leur matériau indépendant. Les onze zones donnent 7,64 niveaux d'écart moyen. `skin-colour-loop54.json` conserve les coordonnées et médianes 9 × 9 des quatre passes ; les correspondances restent approximatives et ce diagnostic de couleur n'est pas une mesure de ressemblance globale.

La géométrie, les UV, le squelette et la logique d'animation sont inchangés. Les différences encore importantes sont les ouvertures et courbures des bras latéraux, la taille et l'orientation des ventouses, la douceur du raccord des yeux, les ombres et le grain de peau. Les tempes restent trop claires et les couleurs ne sont pas identiques.

Validation de 54 : builds Debug simulateur et Release iOS réussis. Aperçu animé sur simulateur iPhone 16 iOS 18.5, sans compilation, capture ni interaction pendant la mesure : SceneKit minimum 59,5 / médiane 60 / maximum 60 FPS ; cadence principale 59,7 / 60 / 60 FPS. Empreintes et fenêtres dans `rig-loop54-performance.json`. Cela ne garantit ni les appareils physiques ni le jeu complet. Les 56 choix du comparatif chargent et `git diff --check` passe. Les vidéos et contrôles géométriques antérieurs restent historiques.


## Reprise des boucles latérales — essais 55 et suivants

**55, étape intermédiaire** : abaissement des deux courbes latérales (bras 2 et 5), sans modification des racines. Les extrémités passent de y ≈ −0,35 à −0,52. Le rendu rapproche leur hauteur, mais cache encore leurs crochets derrière les bras relevés et montre certaines ventouses trop haut sur la boucle. Cette étape n'est pas retenue comme aboutissement. Capture fixe `poulpi-loop-55.png`.

Le validateur de 55 passe : peau fermée, un composant, Euler 2 ; 97 poses, étirement maximal 1,893 et distance minimale des pointes relevées à la tête 0,250. Debug compile. La forme reste à corriger en profondeur.


**56 à 59, rejetées avant validation visuelle** : les premières trajectoires avancées créent des contacts secondaires entre bras. Le validateur de 56 et 58 échoue sur Euler −2 ; les comptages des maillages de 57 et 59 sont également incompatibles avec la surface fermée sans anse attendue. Aucune de ces tentatives n'est présentée comme version validée. Les écarts entre courbes sont ensuite mesurés pour localiser le contact : d'abord les bras relevés, puis les bras avant.

**60** : passage latéral abaissé et décalé vers l'extérieur, pointe avancée en profondeur. Les distances minimales échantillonnées entre les tubes analytiques libres et les bras voisins sont d'environ 0,099 (bras avant) et 0,108 (bras relevés), avant fusion et remeshing. Le contrôle du maillage final passe : un composant, fermé, Euler 2, 97 poses. Le rendu montre les pointes mais place certaines ventouses sur le dessus.

**61, intermédiaire** : orientation des ventouses latérales vers le dessous. La rangée de six est trop tassée sur la petite boucle.

**62** : quatre coussinets par bras latéral et orientation vers le dessous extérieur. Le modèle comprend 40 ventouses au total, 5 800 sommets / 10 560 triangles pour ce maillage. La peau compte 47 930 sommets / 95 856 triangles. Validation : 97 poses, étirement maximal peau 1,893, ventouses 1,015, fermeture de boucle exacte ; distance minimale mesurée des pointes relevées à la tête 0,251. Le contrôle ciblé ne constitue pas une recherche exhaustive de toutes les collisions animées. La bouche et ses UV restent inchangés.

Le comparatif affiche 62, avec les captures intermédiaires réellement produites (55, 60, 61). Les pointes sont visibles, mais les boucles latérales restent moins creusées et plus basses que la référence. L'ouverture des bras relevés, le raccord des yeux, le grain et la matière des ventouses restent à rapprocher. Identité visuelle non atteinte.

Validation de 62 : Debug simulateur et Release iOS compilent. Rotation de contrôle de 46,87 s, réencodée pour la revue, inspection de profil effectuée ; cet enregistrement ne mesure pas les FPS. Mesure indépendante sur simulateur iPhone 16 iOS 18.5 : 33 fenêtres, SceneKit min/médiane/max 57,5/60/60 FPS, cadence principale 60/60/60,1 FPS (`rig-loop62-performance.json`). Aucune garantie pour un appareil physique ou le jeu complet.


## Passes 63 à 66 — silhouette des yeux et clignement

**63** : correction de l'inclinaison du groupe oculaire, largeur 1,16 → 1,12, hauteur 0,91 → 0,88 et position verticale abaissée de 0,006. Les iris et paupières restent dans le même groupe. Quatre lignes de contour par œil montrent un écart moyen de 6,375 pixels en 62 contre 3,5625 en 63, dans le repère de la référence. Les lignes, seuils et limites sont conservés dans `eye-outline-loop66.json`. C'est un diagnostic local de contour, pas un score de ressemblance globale.

**64** : le changement de groupe ayant légèrement réduit et remonté les iris, rayon horizontal 0,120 → 0,125, rapport vertical 1,35 → 1,30, position verticale 0,006 → −0,010 et convergence 0,092 → 0,096. Le calcul de profondeur des calottes est recalé sur cette position. La capture à mi-fermeture révèle un petit débordement sombre pendant le mouvement du regard ; cette régression n'est pas ignorée.

**65** : profondeur de la paupière 0,100 → 0,112. Le diagnostic analytique échantillonné passe d'une pénétration de −0,00057 à une marge de 0,00242, sans prétendre couvrir la triangulation et toutes les phases interpolées (`lid-clearance-loop66.json`). Deux captures à mi-course ne montrent plus le débordement. Le pli de fermeture est cependant enfoui par ce changement.

**66** : le pli est replacé sur la nouvelle surface. Une constante commune pilote sa profondeur et celle des paupières. La capture fermée retrouve le pli et masque les iris ; le contour ouvert garde l'amélioration mesurée en 63. Les images intermédiaires sont conservées pour rendre les régressions vérifiables.

Debug et Release compilent. Le corps, les ventouses et le rig exporté restent ceux de 62 ; leur validation à 97 poses n'a pas été réattribuée à une nouvelle géométrie. Mesure séparée de la compilation et des captures : 36 fenêtres sur simulateur iPhone 16 iOS 18.5, SceneKit min/médiane/max 59,5/60/60 FPS, cadence principale 59,6/60/60 FPS (`rig-loop66-performance.json`). Aucune garantie sur appareil physique ou jeu complet. La rotation 62 reste explicitement historique pour le visage.

Restent le raccord supérieur des yeux, les nuances des blancs, les sourcils, le grain et les ombres de peau, ainsi que les boucles et matières des tentacules/ventouses. L'identité visuelle n'est pas atteinte.


## Passes 67 à 72 — diagnostic et reprise du raccord des yeux

**67, diagnostic non retenu** : suppression de l'ombre de contact ajoutée par shader. Elle ne suffit pas à supprimer la bande sombre supérieure. Le shader de 66 est rétabli.

**68, diagnostic non retenu** : suppression du contour violet distinct. La bande reste visible dans la sculpture. L'hypothèse initiale attribuant le défaut principalement à cette pièce est donc corrigée ; la pièce est rétablie pour conserver le fin bord de l'œil.

**69** : relief orbital sculpté abaissé de 0,045 à 0,022 unité, largeur du profil 0,18 → 0,24. La marche sombre est atténuée. Le maillage reconstruit compte 47 776 sommets / 95 548 triangles de peau ; le validateur passe 97 poses, peau fermée et connexe, Euler 2, étirement maximal 1,839, marge minimale des bras relevés à la tête 0,251. La bouche et les trajectoires des bras restent inchangées ; le remeshing peut modifier leurs sommets et poids.

**70, intermédiaire** : matériau du contour assombri (RGB 0,16/0,10/0,38, rugosité 0,90). Cela révèle un dépassement supérieur trop épais.

**71, retenue** : rayon du contour 0,233 → 0,231, échelle verticale 1,17 → 1,14, décalage y = −0,006 comme le blanc. Le bord devient fin et régulier. Le raccord reste moins organique et moins modelé que sur la référence ; cette étape ne prouve pas une identité visuelle.

**72, rejetée** : groupe oculaire reculé de z=0,555 à 0,515. La peau masque le blanc près des iris et déforme son contour. Retour exact au code de 71. La capture de cet essai est conservée, mais la version affichée par défaut est 71.

Les contrôles des paupières de 65–66 restent ceux de la géométrie oculaire conservée, et les vidéos de 62 sont historiques. Le contrôle du rig reconstruit est consigné dans `rig-validation.json`.

Validation finale de 71 : builds Debug simulateur et Release iOS réussis après restauration du code retenu. Mesure indépendante sur iPhone 16 simulateur iOS 18.5, 38 fenêtres, minimum/médiane/maximum à 60 FPS pour SceneKit et la cadence principale (`rig-loop71-performance.json`). Pas de garantie pour un appareil physique ou le jeu complet. `git diff --check` passe.


## Passes 73–74 — ombres des blancs

**73, intermédiaire** : ajout d'une ombre douce selon la profondeur locale de la surface ivoire. Le haut des yeux gagne du volume, mais l'ombre assombrit trop leur partie basse, déjà trop foncée. La géométrie ne change pas.

**74** : l'ombre est limitée au haut et aux côtés par un fondu vertical. Un faible remplissage des ombres inférieures, proportionnel à la quatrième puissance de la courbe de rebond existante, préserve la clarté du centre. Six médianes RGB 5 × 5 près des bords donnent un écart moyen de 13,28 en 71, 11,39 en 73 et 4,72 en 74. Coordonnées, couleurs, empreintes et limites dans `eye-rim-colour-loop74.json` : ce diagnostic local n'est pas une mesure de ressemblance globale. Le côté droit reste trop froid et son ombre basse encore trop sombre.

Debug et Release passent. Sur 36 fenêtres indépendantes de compilation/capture dans l'aperçu animé du simulateur iPhone 16 iOS 18.5, SceneKit minimum/médiane/maximum 59,5/60/60 FPS, cadence principale 60/60/60 (`rig-loop74-performance.json`). Aucun résultat sur appareil physique ou jeu complet n'en est déduit. Géométrie, rig, iris et paupières inchangés : les validations géométriques et de clignement précédentes restent datées de leurs passes respectives.

Le comparatif affiche 74. Restent notamment le modelé du raccord oculaire, les sourcils, la texture de peau, les boucles et la matière des ventouses. L'identité visuelle n'est pas atteinte.


## Passe 75 — grain de peau selon la zone

Le diagnostic à échelle égale montre deux écarts opposés : le front est trop uniforme, le manteau trop contrasté. Le grain de peau reçoit une intensité variant doucement de 0,70 en bas à 2,10 sur le haut de la tête. La même intensité pilote les deux échelles de couleur et le relief des normales ; les fréquences et le filtrage par dérivées restent inchangés. Les sourcils conservent leur intensité précédente grâce au paramètre de la fonction de shader partagée. Il n'y a pas de texture supplémentaire ni de géométrie reconstruite pendant l'animation.

`skin-grain-loop75.json` compare deux petites régions à la résolution de capture, avec rééchantillonnage bilinéaire de la référence. Sur le front, les écarts-types des gradients X/Y passent de 1,53/1,49 à 3,16/3,05, contre 3,47/3,09 dans la référence. Sur le manteau, 2,83/3,35 deviennent 2,01/2,37, contre 1,92/2,26. Le contraste haute fréquence est donc rapproché dans ces zones, sans démontrer une identité de motif, de personnage ou une stabilité temporelle exhaustive.

La géométrie et les trajectoires restent celles validées précédemment. Les couleurs globales, le raccord oculaire, les sourcils, les boucles et la matière des ventouses restent différents. L'identité visuelle n'est pas atteinte.


## Passe 76 — correction du clignement entre les poses

Le cycle enregistré en 75 révèle un débordement de l'iris dans une paupière partiellement fermée, visible notamment vers 9 secondes. Les contrôles fixes de 65–66 et leur diagnostic analytique ne couvraient pas cette interpolation : ils ne prouvaient donc pas l'absence de ce défaut en mouvement. L'enregistrement 75 est conservé comme preuve historique, pas présenté comme une animation sans défaut.

Les cibles de morphing passent de 4 à 16, espacées de π/16 plutôt que π/4. Le calcul des poids dépend du nombre de cibles et ne conserve que deux poids voisins non nuls. Les formes sont précalculées et mises en cache ; aucune géométrie n'est reconstruite par image. Les intervalles plus petits limitent l'aplatissement de la surface interpolée entre deux formes courbes.

Le mode Debug `--octopus-eyelids-intermediate` fixe la fermeture à 0,625 pour inspecter cette zone. La capture `poulpi-loop76-paupieres-intermediaires.png` ne montre pas le débordement. Le grain de 75, la sculpture et les autres animations sont conservés. La capture statique 76 reste comparable aux précédentes. Le comparatif affiche désormais 76 et son nouveau cycle animé ; l'identité visuelle avec la référence reste non atteinte.


Validation de 76 : Debug et Release passent. Le nouvel enregistrement dure 174,51 s ; les images contrôlées à 4,70 s et 8,68 s ne montrent pas le débordement observé en 75. Une extraction est conservée dans `poulpi-loop76-clignement-video.png`. Cette inspection échantillonnée ne prétend pas couvrir chaque image. L'enregistrement, réencodé pour la revue, n'est pas une mesure de FPS.

Mesure indépendante après l'encodage : 35 fenêtres sur iPhone 16 simulateur iOS 18.5, SceneKit min/médiane/max 59,5/60/60 FPS, cadence principale 59,7/60/60 (`rig-loop76-performance.json`). Pas de garantie sur appareil physique ou jeu complet. `git diff --check` passe. Le diagnostic de grain de 75 s'applique à la matière inchangée de 76 ; le clignement seul est repris dans cette dernière passe.


## Passes 77 à 80 — forme et matière des sourcils

**77** : rayon variable le long du sourcil, avec une pointe extérieure plus fine et un bout intérieur plus plein. Le générateur de tube accepte un profil optionnel ; les plis de paupières gardent le profil constant précédent. Les normales sont recalculées sur la surface obtenue. Le premier effilement est un peu trop pointu.

**78** : courbure de la ligne centrale réduite de 0,020 à 0,008 et inclinaison au repos 0,28 → 0,34 radian. Initialisation, réinitialisation et animation partagent cette base corrigée.

**79** : matériau plus profond, RGB 0,29/0,28/0,72 → 0,24/0,20/0,64, rugosité inchangée. La teinte reste calculée par l'éclairage du volume, avec le grain partagé existant.

**80** : les extrémités extérieures retrouvent un peu de volume. Le profil varie doucement de 0,75 à 1,15 fois le rayon 0,046, au lieu de 0,55 à 1,15. Les caps restent arrondis selon la distance le long de la courbe. Aucun sommet supplémentaire ni calcul géométrique par image : le profil est évalué à la construction seulement.

Le comparatif affiche 80 et conserve 77–79. L'appréciation de ce rapprochement est visuelle, sans score automatique de ressemblance attribué aux sourcils. Leur raccord au front reste moins doux que la référence. Les yeux, le corps, les ventouses et le clignement conservent les versions précédentes.

Debug et Release passent. Sur 39 fenêtres indépendantes de compilation/capture, dans l'aperçu animé du simulateur iPhone 16 iOS 18.5 : SceneKit min/médiane/max 59,5/60/60 FPS, cadence principale 59,8/60/60 (`rig-loop80-performance.json`). Pas de garantie pour un appareil physique ou le jeu complet. Les validations géométriques et vidéos précédentes restent historiques. Identité visuelle non atteinte.


## Passes 81–82 — matière et creux des ventouses

**81** : couleur diffuse RGB 0,72/0,64/0,46 → 0,76/0,69/0,53, rugosité 0,66 → 0,76, remplissage des ombres 0,48/0,35/0,15 → 0,50/0,40/0,24. Le rendu est plus crème et moins doré.

**82** : la hauteur centrale du profil passe de 0,56 à 0,63, pour un sommet du bourrelet à 0,66. La dernière couronne passe de 0,59 à 0,64. Le creux est donc moins marqué ; les coussinets restent des volumes fermés au centre, attachés au dessous des bras. Leur implantation et leur nombre ne changent pas. Aucune géométrie n’est reconstruite pendant l’animation.

La capture comparée montre encore des ventouses avant trop frontales et rondes, des ouvertures de bras relevés trop étroites et des boucles latérales trop basses. La matière manque encore de nuances d’ombre. La passe 82 est affichée par défaut ; 81 est conservée. L’identité visuelle n’est pas atteinte.

Debug et Release passent. Le contrôle géométrique passe 97 poses : peau fermée, connexe, Euler 2 ; étirement maximal 1,839 ; marge minimale des bras relevés à la tête 0,251. Les 40 ventouses totalisent 5 800 sommets / 10 560 triangles, avec 40 ouvertures de base enfouies, sans face dégénérée ; étirement maximal 1,015. Ce contrôle n’exclut pas toute collision possible.

Mesure indépendante de compilation et de capture : 42 fenêtres sur iPhone 16 simulateur iOS 18.5, aperçu animé Debug. SceneKit et cadence principale : minimum/médiane/maximum 60/60/60 FPS (`rig-loop82-performance.json`). Aucun résultat sur appareil physique ou jeu complet n’en est déduit. Les vidéos de 62 et 76 restent historiques et ne représentent pas les ventouses de 82.


## Passe 83 — largeur des ventouses aux pointes avant

Le profil transversal est réduit progressivement jusqu’à 22 % entre t=0,78 et t=0,885 sur les deux bras avant. Le fondu utilise la même interpolation douce que leur allongement existant. La longueur, le centre, les points d’attache, les poids et le nombre de sommets restent inchangés ; les normales tiennent compte de cette échelle anisotrope. La forme est calculée hors ligne.

Le comparatif montre des coussinets plus ovales. Leur orientation reste différente de la référence, comme la courbure des bras qui les portent ; cette passe ne corrige pas ces autres écarts. La capture 83 remplace 82 par défaut, les deux restant accessibles. L’identité visuelle n’est pas atteinte.

Le contrôle sur 97 poses passe : peau fermée et connexe (Euler 2), 40 ouvertures de base des ventouses, aucun triangle dégénéré ; aire double minimale des triangles de ventouses 0,00013946. L’étirement maximal reste 1,015 pour les ventouses et 1,839 pour la peau. La mesure FPS de 82 est historique : elle n’est pas présentée comme une mesure de 83.

Validation de 83 : builds Debug simulateur et Release iOS réussis ; `git diff --check` passe.


## Passe 84 — rapprochement des bras avant rejeté

Deux points par bras sont rapprochés de 0,04 unité : x=0,25 → 0,21 et x=0,32 → 0,28. Malgré une validation géométrique réussie sur 97 poses (peau fermée et connexe, Euler 2), le lissage ferme trop bas l’ouverture centrale. La capture `poulpi-loop-84.png` montre cette régression visuelle. L’essai est rejeté ; la validité topologique ne suffit pas à juger la fidélité de la sculpture.


## Passes 85–89 — ouverture centrale des bras avant

**85** : retour du point supérieur à x=0,25, point inférieur x=0,32 → 0,30. L’ouverture se resserre, mais son sommet reste trop bas.

**86–88, intermédiaires** : réduction du lissage de l’union des bras avant au centre, sous le manteau. Le masque transversal est exp(−(x/0,15)⁴), le masque vertical progresse de y=−0,22 à −0,40. Les intensités 0,50 et 0,34 ouvrent trop haut ; 0,15 ouvre plus bas que la référence. Ces captures sont conservées pour documenter le réglage.

**89, retenue** : intensité 0,23. Le raccord conserve son lissage hors de cette petite zone. L’ouverture centrale est visuellement plus proche en largeur et en hauteur ; ses ombres et sa courbure ne sont pas identiques. Les boucles latérales, les ouvertures des bras relevés et les matières restent différentes. Aucun calcul de sculpture n’est ajouté pendant l’animation.

La validation sur 97 poses passe, ainsi que les builds Debug simulateur et Release iOS. Le contrôle du maillage ne constitue pas une preuve exhaustive d’absence d’auto-intersection. L’identité visuelle n’est pas atteinte.

Le cycle animé de 89 dure 43,02 s. Les poses inspectées à 4, 12 et 20 s conservent une séparation centrale et des bras relevés distincts du visage. Cette inspection est échantillonnée, pas une validation exhaustive de toutes les images. Le cycle est disponible dans le comparatif ; la vidéo réencodée ne sert pas à mesurer les FPS.

Mesure indépendante : 35 fenêtres sur iPhone 16 simulateur iOS 18.5, aperçu animé Debug. SceneKit et cadence principale donnent minimum/médiane/maximum 60/60/60 FPS (`rig-loop89-performance.json`). Cela ne mesure ni un appareil physique ni le jeu complet. `git diff --check` passe.


## Passes 90–91 — reflets de peau

**90, intermédiaire** : rugosité de la peau 0,82 → 0,62. Les volumes des bras sont plus visibles mais des reflets trop brillants apparaissent près des raccords.

**91, retenue** : rugosité 0,70. Le modelé conserve des reflets plus doux. Le changement ne touche que cette constante du matériau : ni lumière supplémentaire, ni géométrie, texture ou calcul par image ajouté. La comparaison est visuelle ; aucun score global de ressemblance n’est attribué à cette passe.

La vue entière montre encore des boucles latérales trop rondes, des ventouses relevées trop frontales et un relief violet au-dessus des yeux moins marqué que la référence. Les couleurs, les ombres et certains raccords restent différents. L’identité visuelle n’est pas atteinte.

Debug et Release passent. La géométrie conserve la validation de 89 ; sa vidéo et ses mesures FPS restent datées de 89 et ne sont pas présentées comme des mesures de 91.


## Passes 92–93 — relief supérieur des yeux

**92, intermédiaire** : amplitude du relief orbital sculpté 0,022 → 0,032. Une teinte violette est ajoutée sur le haut de ce relief. La première largeur de masque (0,24) et sa couleur RGB 0,40/0,25/0,85, mélangée à 65 %, produisent un halo trop clair et trop large.

La compilation partagée a temporairement échoué sur des appels `L10n` pendant un chantier parallèle de traduction. La capture 92 provient d’une copie dans `/tmp/lisa-mascot92-preview`, avec les mêmes fichiers de rendu et de mascotte, mais deux fichiers SudokuCore pris dans HEAD et un adaptateur de chaînes exclusivement dans cette copie. Elle sert au diagnostic visuel, pas à valider le projet partagé. Aucun fichier du chantier de traduction n’a été corrigé ou restauré par cette passe.

**93, retenue** : masque de pigment réduit à 0,12, teinte RGB 0,25/0,15/0,65 mélangée à 45 %. Le halo est atténué. La capture 93 et la pose de paupières intermédiaire proviennent du projet partagé, dont Debug et Release passent après l’apparition des fichiers de traduction. La pose intermédiaire à 0,625 ne montre pas de débordement de l’iris ; ce contrôle fixe ne prouve pas chaque interpolation en mouvement.

Le maillage reconstruit est validé sur 97 poses : 48 030 sommets / 96 056 triangles de peau, peau fermée et connexe, Euler 2, étirement maximal 1,891, marge minimale des bras relevés à la tête 0,251. Les ventouses restent à 5 800 sommets / 10 560 triangles. Les mesures FPS et la vidéo de 89 restent historiques ; aucune nouvelle cadence n’est attribuée à 93.

Le bourrelet reste moins sculpté que dans la référence. Les paupières ont une matière plus uniforme et plus violette que la peau ; les boucles, l’orientation des ventouses et les ombres restent à rapprocher. L’identité visuelle n’est pas atteinte.


## Passes 94–95 — matière des paupières

**94, intermédiaire** : teinte diffuse RGB 0,41/0,25/0,80 → 0,30/0,23/0,70, rugosité 0,72 → 0,70. Le matériau partagé par les deux paupières reçoit le même grain filtré par dérivées que les petites surfaces du visage. L’intensité 1,25 paraît trop forte en fermeture complète. Les captures intermédiaire et fermée sont conservées.

**95, retenue** : intensité du grain réduite à 0,65. La fermeture complète est visuellement moins rose et moins lisse que 93, avec un grain plus discret que 94. La forme des paupières, leurs 16 cibles de morphing et le pli de fermeture restent inchangés. Le changement se voit pendant le clignement ; la pose ouverte du comparatif conserve presque le même aspect que 93. Aucun sommet ni texture supplémentaire n’est ajouté ; le shader de grain est désormais évalué sur les deux petites surfaces des paupières également.

Debug et Release passent. Les poses inspectées ne montrent pas de débordement des iris, mais ne constituent pas un contrôle exhaustif de toutes les images animées. La géométrie garde la validation de 92–93. Le raccord des paupières, les boucles latérales, les ventouses et le modelé restent différents de la référence ; identité visuelle non atteinte.

Mesure de 95 après compilation et captures : 39 fenêtres dans l’aperçu animé Debug du simulateur iPhone 16 iOS 18.5. SceneKit min/médiane/max 59,5/60/60 FPS ; cadence principale 59,9/60/60 (`rig-loop95-performance.json`). Aucune garantie pour les appareils physiques ou le jeu complet. `git diff --check` passe.


## Passe 96 — crochet latéral rejeté par la topologie

Pointe latérale (1,00; −0,52; 0,88) → (0,91; −0,47; 0,94), avant facteur x de 0,90. Le contrôle détecte Euler 0 au lieu de 2 : une liaison supplémentaire se forme entre des volumes. L’essai n’est pas installé pour revue et aucune capture 96 n’est publiée. Cette forme est rejetée avant validation visuelle.


## Passes 97–99 — pointes latérales et contrôle des connexions

**97, rejetée** : pointe à (0,91; −0,43; 1,08), avant facteur x de 0,90. La séparation accrue en profondeur ne résout pas la liaison supplémentaire (Euler 0).

**98, rejetée** : réduction locale du lissage jusqu’à 65 % sur les parties extérieures et avancées des bras latéraux. Euler reste 0. Un diagnostic par étapes observe la liaison après le remeshing et avant la décimation finale ; il ne localise pas précisément la liaison et ne prouve pas la cause exacte. Cette réduction du lissage est retirée. Aucune capture 97 ou 98 n’est publiée.

**99, retenue** : pointe à (0,97; −0,47; 0,96), contre (1,00; −0,52; 0,88) en 95, avant facteur x de 0,90. Les pointes sont un peu plus relevées et tournées vers le centre. Le nouveau zoom « Bras latéraux — côté gauche » montre mieux la limite restante : la référence a un crochet creusé, le modèle une extrémité encore trop frontale et bombée. Le déplacement est une étape, pas une restitution identique.

La validation passe sur 97 poses : peau fermée et connexe, Euler 2, 48 478 sommets / 96 952 triangles, étirement maximal 1,892, marge minimale des bras relevés à la tête 0,251. Ventouses : 5 800 sommets / 10 560 triangles, étirement maximal 1,015. Debug et Release passent. Ce contrôle géométrique n’exclut pas toute collision pendant toute animation possible.

Mesure de 99 : 35 fenêtres dans l’aperçu animé Debug, iPhone 16 simulateur iOS 18.5, après compilation et captures. SceneKit min/médiane/max 59,5/60/60 FPS, cadence principale 60/60/60 (`rig-loop99-performance.json`). Pas de garantie pour les appareils physiques ou une partie complète. Les vidéos antérieures restent historiques. `git diff --check` passe.


## Essais 100–103 — crochet latéral, retour à 99

**100, rejeté avant capture** : deux derniers points (1,06; −0,62; 0,62), (0,97; −0,47; 0,76). La topologie donne Euler −2.

**101, rejeté visuellement** : même courbe, rayon aminci progressivement de 0,030 unité sur t=0,60…1. La topologie et les 97 poses passent, mais la capture montre une pointe trop droite et trop fine, sans le crochet recherché. L’image reste accessible comme essai rejeté.

**102, rejeté avant capture** : pointe ramenée à (0,84; −0,48; 0,76), affinement conservé. Euler −4.

**103, rejeté avant capture** : pointe reculée à (0,84; −0,35; 0,30). Euler −2. Ces résultats ne localisent pas précisément les connexions ; les hypothèses sur les bras voisins et le lissage ne constituent pas une preuve de leur emplacement exact.

Retour aux courbes et rayons de 99. Le JSON reconstruit est identique octet pour octet à celui référencé par `rig-loop99-performance.json` (SHA-256 4baa3af24c4e838854b93a29c807cf8d27e15483761ea1bcc039f76971de115e). La validation sur 97 poses repasse. La galerie conserve 99 comme version courante : cette série ne constitue pas un progrès de ressemblance retenu.

Le générateur contrôle désormais Euler 2 dès la fin de la reconstruction de peau, avant les poids, les ombres et l’export. Le validateur complet reste nécessaire pour les composantes et les poses. Ce contrôle précoce évite d’exporter les formes à connexions supplémentaires observées ici ; il ne détecte pas toutes les collisions possibles.

Le test de rejet sur la forme 100 s’arrête avec « Unexpected sculpt handle before export », Euler −2, code 1. L’empreinte du modèle 99 reste inchangée après ce test. La compilation Debug de la restauration passe et cette application est réinstallée sur le simulateur. `git diff --check` passe.


## Passes 104–105 — reconstruction des courbes latérales

**104** : reprise de toute la courbe, avec les points (0,22; −0,20; −0,04), (0,60; −0,55; 0), (0,94; −0,72; 0,13), (1,08; −0,61; 0,30), (1,08; −0,42; 0,32), (0,91; −0,46; 0,32), avant facteur x de 0,90. Rayon latéral 0,15 × (1−t) + 0,090. Le contrôle précoce et les 97 poses passent. Le crochet devient visible, mais monte trop haut et une ventouse atteint sa partie supérieure.

**105, retenue** : les deux derniers points sont abaissés de 0,04 en y (−0,46 et −0,50). La rangée de quatre ventouses latérales couvre t=0,36…0,70, contre 0,36…0,885 ; la pointe reste libre. Les autres rangées gardent leurs paramètres. Le retour du crochet est plus lisible, mais son ouverture intérieure est encore moins profonde que la référence et son sommet reste un peu haut. Le comparatif affiche 105 et conserve 104. L’identité visuelle n’est pas atteinte.

Debug et Release passent. Validation sur 97 poses : peau fermée, connexe, Euler 2, 46 884 sommets / 93 764 triangles ; étirement maximal 1,887 ; marge minimale des bras relevés à la tête 0,244. Ventouses : 5 800 sommets / 10 560 triangles, étirement maximal 1,015, 40 bases ouvertes enfouies. Cela ne constitue pas une preuve exhaustive d’absence d’auto-intersection.

Le cycle de 105 dure 48,22 s. Les poses examinées à 8 et 20 s conservent les ventouses sur les bras et ne montrent pas de liaison des bras relevés au visage. Cette inspection est échantillonnée ; elle ne couvre pas toutes les images. La vidéo réencodée sert à la revue et ne constitue pas une mesure de FPS.

Mesure de 105 : 40 fenêtres après encodage, aperçu animé Debug sur iPhone 16 simulateur iOS 18.5. SceneKit minimum/médiane/maximum 58,5/60/60 FPS ; cadence principale 60/60/60,1 (`rig-loop105-performance.json`). La médiane reste 60, avec un minimum inférieur à celui de 99 ; cette mesure seule ne permet pas d’attribuer la variation au modèle. Aucun résultat sur appareil physique ou partie complète n’en est déduit. Les 97 images du sélecteur se chargent ; `git diff --check` passe.


## Passes 106–108 — parcours des ventouses des bras relevés

**106** : torsion utilisée pour leur implantation 2,4 → 1,1. La rangée se déplace vers le bord extérieur sans résoudre la différence recherchée.

**107, rejetée** : torsion 0,45 et fin de parcours t=0,73 au lieu de 0,79. Les ventouses sont trop extérieures. Les captures de ces deux essais restent accessibles.

**108, retenue** : torsion rétablie à 2,4 ; parcours t=0,38…0,73 au lieu de 0,45…0,79. Les quatre ventouses restent réparties à distance égale le long de la surface projetée. La rangée se rapproche visuellement des positions de référence. Les coussinets sont encore trop frontaux, surtout celui du bas ; la teinte et le relief restent différents. L’identité visuelle n’est pas atteinte.

Les 97 poses passent ; aucune courbe de bras ou surface de peau n’est changée par cette série, seulement l’implantation et l’orientation des ventouses. Debug et Release ont réussi avant qu’une modification externe de l’installation Xcode rende `xcrun` inutilisable (Info.plist et DVTSystemPrerequisites manquants). Après redémarrage du simulateur, la capture 108 provient du binaire Debug compilé avec succès, installé et lancé via le `simctl` de CoreSimulator. Aucun composant Xcode n’a été modifié par ce travail.

La mesure FPS et le cycle de 105 restent historiques ; aucune nouvelle cadence n’est attribuée à 108. Le nombre de sommets et de triangles des ventouses ne change pas.


## Passe 109 — profil du coussinet bas des bras relevés

Le coussinet de base reçoit une largeur transversale réduite de 50 %, avec un fondu cubique de t=0,38 à t=0,50 vers la largeur précédente. Sa longueur tangentielle, son centre et son implantation restent inchangés. Les normales utilisent déjà l’inverse de cette échelle transversale ; aucun sommet ni calcul géométrique pendant l’animation n’est ajouté.

La capture montre une silhouette plus ovale, visuellement plus proche du coussinet bas de référence. L’inclinaison, la teinte et les ombres restent différentes ; les autres coussinets paraissent encore trop frontaux. L’identité visuelle n’est pas atteinte.

Xcode est de nouveau disponible (27.1, build 27A9275). Debug et Release passent ; le simulateur arrêté est redémarré, l’application reconstruite est installée et la capture 109 provient de cette application. Le contrôle géométrique sur 97 poses passe. Les mesures FPS et la vidéo de 105 restent historiques ; aucune nouvelle mesure n’est attribuée à 109. `git diff --check` passe.


## Passes 110–111 — matière ivoire des ventouses

**110, intermédiaire** : rugosité 0,76 → 0,52, émission RGB 0,50/0,40/0,24 → 0,35/0,28/0,16. Le volume se lit davantage, mais les ombres paraissent trop jaunes.

**111, retenue** : diffuse RGB 0,78/0,73/0,62 et émission 0,35/0,30/0,22, rugosité conservée à 0,52. Le rendu est plus ivoire et moins jaune. Il reste moins détaillé dans les creux et les ombres de contact que la référence. Cette appréciation est visuelle, sans score global de ressemblance. L’identité visuelle n’est pas atteinte.

Seules les constantes du matériau changent : pas de lumière, texture, shader ou sommet supplémentaire. Debug et Release passent. La géométrie conserve les contrôles de 109 ; la mesure de cadence et la vidéo de 105 restent historiques. Des changements parallèles du budget de rendu et de l’accès à l’écran sont présents dans le projet ; cette passe ne les modifie pas et ne leur attribue pas de résultat de performance. `git diff --check` passe.


## Passe 112 — section des bras relevés

Le rayon des bras 1 et 6 reçoit un retrait progressif de 0,020 × sin(πt), nul à la racine et à la pointe et maximal au milieu. La courbe centrale et la rondeur de l’extrémité sont conservées. Les ventouses sont reprojetées sur la surface reconstruite avec leurs paramètres de placement existants.

La capture montre une ouverture plus lisible. Son inclinaison et sa forme restent différentes de la référence ; cette passe ne prétend pas reproduire exactement le contour. La surface et les ombres restent également à rapprocher.

Debug et Release passent. Validation sur 97 poses : peau fermée et connexe, Euler 2, 46 478 sommets / 92 952 triangles, étirement maximal 1,889 et marge minimale des bras relevés à la tête 0,255. Ventouses : 5 800 sommets / 10 560 triangles, étirement maximal 1,015. Le contrôle ne couvre pas toutes les collisions possibles. La vidéo de 105 demeure historique. L’identité visuelle n’est pas atteinte.

Mesure de 112 : 47 fenêtres dans l’aperçu animé Debug du simulateur iPhone 16 iOS 18.5, sans compilation ni capture pendant la mesure. SceneKit minimum/médiane/maximum 59,5/60/60 FPS ; cadence principale 59,6/60/60 (`rig-loop112-performance.json`). Aucun résultat sur appareil physique ou partie complète n’est déduit. `git diff --check` passe.


## Passes 113–114 — modelé sous la bouche et joues

**113** : émission du manteau réduite de moitié (part diffuse 0,16 → 0,08 ; bleu 0,20 → 0,10). La zone sous la bouche est moins éclaircie. Le relief reste plus plat que dans la référence : cette correction locale ne remplace pas le travail sur les volumes et leur éclairage.

**114, retenue** : centre du blush abaissé de y=0,18 à 0,155, largeurs gaussiennes 0,13/0,095 → 0,105/0,070, mélange 0,50 → 0,40. Les joues roses sont plus localisées. Les captures 112, 113 et 114 sont conservées pour comparaison. Les contours des yeux, leur profondeur, les sourcils et les ombres du visage restent différents ; aucune identité visuelle n’est annoncée.

Seules des constantes du shader de peau changent : mêmes géométries, textures et calculs par image. Debug et Release passent. Le contrôle géométrique sur 97 poses reste celui de 112 ; la dernière mesure de cadence est également celle de 112 et ne constitue pas une mesure de 114. Aucun FPS sur appareil physique n’est déduit de cette passe.

Les 106 images du sélecteur se chargent ; `git diff --check` passe.


## Passes 115–118 — sourcils et essai sur les blancs des yeux

**115** : épaisseur relative du bout externe des sourcils 0,75 → 0,92, bout interne conservé à 1,15 ; courbure centrale 0,008 → 0,014. Les extrémités sont moins pincées. Le nombre de sommets et de triangles reste identique.

**116, intermédiaire** : couleur diffuse des sourcils RGB 0,24/0,20/0,64 → 0,29/0,24/0,69 et rugosité 0,72 → 0,56. Le reflet rend le relief plus lisible mais souligne trop le grain.

**117, retenue** : rugosité 0,62 et intensité du grain 0,35. Les sourcils sont plus doux ; leur raccord au front, leur courbe et l’éclairage restent différents de la référence.

**118, écartée** : rugosité des blancs des yeux 0,80 → 0,52. Pas d’amélioration visuelle suffisamment nette ; retour à 0,80. La capture est conservée et étiquetée. Les ombres des blancs et leur raccord au visage restent à améliorer.

Les captures proviennent de builds Debug réussis. La Release de 117 passe. Les modifications ne concernent que le profil statique des sourcils et des constantes de matériaux : aucune géométrie reconstruite pendant l’animation, aucune lumière supplémentaire. Les contrôles des 97 poses de peau, bouche et ventouses restent ceux de 112 et ne valident pas la nouvelle forme des sourcils. Les dernières mesures de cadence restent celles de 112 ; aucune performance matérielle universelle n’est annoncée.

Retour à 117 recompilé et réinstallé. Les 110 images du sélecteur se chargent ; `git diff --check` passe. Le nouveau cycle enregistré dure 36 s (`poulpi-boucle-117-cycle.mp4`). Les poses examinées à 8 et 20 s ne montrent pas de ventouse détachée ni de sourcil désolidarisé ; cette inspection échantillonnée ne valide pas toutes les images et la vidéo réencodée ne sert pas à mesurer les FPS.


## Passes 119–120 — relief supérieur des yeux

**119** : largeur du bourrelet orbital dans le champ de distance 0,24 → 0,15 ; amplitude 0,032 → 0,040. Le relief est moins étalé et plus lisible au-dessus des yeux. Il reste différent de la référence dans son contour et son éclairage. Le nouveau zoom « Yeux et contours » permet de comparer cette zone.

**120, retenue** : mélange du pigment violet localisé 0,45 → 0,70. La zone claire au sommet du contour est atténuée ; le raccord aux paupières reste visible et les ombres du blanc manquent encore de profondeur. La ressemblance exacte reste non atteinte.

La peau reconstruite compte 46 550 sommets / 93 096 triangles (+72 / +144). Elle conserve une seule composante fermée, caractéristique d’Euler 2, sans bord ouvert ni arête non-manifold. Les 97 poses passent : erreur de liaison maximale 5,895e-8, étirement maximal d’arête 1,8964 et distance minimale mesurée bras relevés/tête 0,2553. Les 40 ventouses conservent 5 800 sommets / 10 560 triangles. `rig-validation.json` correspond à cette géométrie.

Les poses à fermeture 0,625 et 1 sont capturées : pas d’iris traversant les paupières sur ces deux vues ; le raccord de matière reste visible. Cette inspection ne couvre pas toutes les images du clignement. Le cycle vidéo de 117 reste historique. Les compilations Debug de 119 et 120 passent.

La première Release a échoué pendant des modifications parallèles du moteur Sudoku (`nextLogicalMove` manquante). La méthode étant apparue dans le fichier de travail, la relance réussit sans modification de ce code par cette passe. Mesure 120 : 35 fenêtres, aperçu animé Debug sur iPhone 16 simulateur iOS 18.5 ; SceneKit minimum/médiane/maximum 59,5/60/60 FPS, cadence principale 59,7/60/60 (`rig-loop120-performance.json`). Aucun résultat sur appareil physique ou partie complète n’en est déduit. Les 112 images du sélecteur se chargent et `git diff --check` passe.


## Passes 121–123 — lumière ivoire sur le dôme des yeux

**121, écartée** : ajout d’une lumière locale RGB 0,10/0,08/0,04, pondérée par la profondeur du dôme à la puissance 4 et par la transition basse existante. L’éclaircissement ne rapproche pas suffisamment les couleurs : erreur moyenne sur 12 zones 3,86 → 3,92 niveaux RGB ; sur les 6 zones du dôme, 3,00 → 3,00.

**122, invalide** : correction séparée du bleu par œil, mais le paramètre du shader est déclaré sans `#pragma arguments`. L’application compile ; le compilateur Metal échoue à l’exécution (`program scope variable must reside in constant address space`), avec un rendu magenta des blancs. Cette capture est explicitement étiquetée comme invalide.

**123, retenue** : déclaration corrigée sous `#pragma arguments`. La lumière locale utilise RGB 0/0,08/+0,08 à gauche et 0/0,08/−0,08 à droite. Le paramètre est fixé une seule fois à la création de chaque matériau. Le rendu des blancs est vérifié ; le journal du processus ne contient plus l’erreur de compilation du shader lors de cette vérification.

`eye-colour-loop123.json` conserve 12 médianes de carrés 5×5 pixels, avec coordonnées et empreintes des captures. Erreur moyenne 120 → 123 : 3,86 → 3,42 niveaux RGB ; sur les 6 zones du dôme, 3,00 → 1,94. La correspondance repose sur le cadrage CSS fixe et reste approximative. Ces mesures locales ne prouvent ni la forme, ni la profondeur, ni une identité globale avec la référence. Les ombres et le raccord au visage restent différents.

Géométrie inchangée : les contrôles de 119–120 restent applicables au maillage ; la mesure de cadence de 120 reste historique. Aucun nouveau FPS sur appareil physique n’est annoncé.

Debug et Release de 123 passent. Les 115 images du sélecteur se chargent ; `git diff --check` passe. L’aperçu animé est relancé sur la version retenue.


## Passe 124 — filtrage du bord des iris

Le disque opaque se terminait par une découpe dure malgré le filtrage linéaire/mipmap de sa texture. Un rayon normalisé interpolé sert désormais à un fondu du seul bord ; sa largeur vaut le maximum de 0,008 et de la dérivée écran `fwidth`. Le matériau déclare cette transparence explicitement dans le shader. Aucune subdivision ni texture supplémentaire n’est ajoutée.

Le gros plan montre une transition plus douce entre iris et ivoire. Deux carrés centraux de 41×41 pixels, centrés en (499,1359) et (678,1360) dans les captures 123/124, présentent une différence RGB maximale de 1 niveau et moyenne de 0,0012/0,0014 : le pigment central n’est pas éclairci de façon significative par le fondu. Cette mesure ne prouve pas la ressemblance globale. Le contour, les ombres et le raccord des yeux restent différents de la référence.

Debug et Release passent. Le shader est vérifié à l’écran et aucune erreur de compilation du shader n’apparaît dans le journal du processus testé. Une capture à fermeture 0,625 montre les iris occultés par les paupières ; c’est une vérification ponctuelle, pas un contrôle exhaustif du clignement ou du tri de transparence à tous les angles. La géométrie conserve les contrôles de 119–120.

Mesure 124 : 33 fenêtres, aperçu animé Debug sur iPhone 16 simulateur iOS 18.5 ; SceneKit minimum/médiane/maximum 59,5/60/60 FPS et cadence principale 60/60/60 (`rig-loop124-performance.json`). Ce contrôle ne mesure ni une partie complète ni un appareil physique. `git diff --check` passe.


## Passes 125–126 — détails des ventouses

Le générateur exporte désormais deux coordonnées locales par sommet de ventouse, centrées en (0,5 ; 0,5) sur chaque coussinet. Elles suivent le skinning et la forme ovale. Le chargeur accepte ces coordonnées optionnelles et conserve les coordonnées existantes de la peau. Le générateur et le validateur vérifient leur nombre, leur finitude et leur domaine [0,1].

**125, intermédiaire** : deux transitions radiales ajoutent un ombrage du creux et de son anneau intérieur. Le centre paraît trop gris.

**126, retenue** : ombrages ramenés à 0,04 pour le creux et l’anneau, avec un léger apport crème RGB 0,035/0,017/0 dans le creux. La rugosité y augmente de 0,08. Le détail est plus doux ; la profondeur et les ombres de contact restent différentes de la référence, ainsi que l’orientation de certaines ventouses. Aucun score global de ressemblance n’est déduit.

Pas de sommet, triangle, objet animé ou texture image supplémentaire. Le JSON passe de 11 256 699 à 11 449 002 octets, avec 11 600 valeurs UV pour les 5 800 sommets des ventouses. Le nombre de canaux UV côté rendu reste identique. Les 97 poses et la topologie passent après reconstruction, avec les mêmes métriques géométriques que 119–120.

Debug et Release passent. Le shader est vérifié à l’écran sans erreur de compilation signalée pour le processus examiné. Le nouveau cycle dure 43,04 s ; les poses à 8 et 20 s montrent le détail sur les ventouses déformées sans détachement visible. Cette inspection est échantillonnée et ne valide pas chaque image. La vidéo réencodée ne mesure pas les FPS.

Mesure 126 : 35 fenêtres, aperçu animé Debug sur iPhone 16 simulateur iOS 18.5 ; SceneKit minimum/médiane/maximum 59,5/60/60 FPS et cadence principale 60/60/60 (`rig-loop126-performance.json`). Ce résultat ne mesure ni une partie complète ni un appareil physique. `git diff --check` passe.


## Passes 127–131 — séparation des bras avant

**127, rejetée** : troisième point des courbes avant x=0,30 → 0,26 (avant compression horizontale ×0,90). La fente centrale se referme visuellement, malgré une topologie valide.

**128, intermédiaire** : x=0,285. L’ouverture revient mais son sommet est trop bas.

**129** : réduction locale du lissage central 0,23 → 0,40. La fente est lisible et moins évasée, mais son sommet remonte trop.

**130, retenue** : réduction locale 0,35, x=0,285. La partie basse des bras est plus proche et l’ouverture moins large que dans 126. Son sommet reste légèrement trop haut et son ombre plus uniforme que sur la référence ; aucune identité de silhouette n’est annoncée.

**131, rejetée avant export** : réduction locale 0,30. Le garde-fou détecte une caractéristique d’Euler 0, correspondant à une liaison supplémentaire. Le processus s’arrête avant d’écrire le JSON ou le fichier Blender. Le paramètre source est rétabli à 0,35 et l’asset exporté de 130 reste en place. Aucune capture 131 n’est ajoutée.

130 conserve une composante fermée, Euler 2, sans bord ouvert ni arête non-manifold : 46 690 sommets / 93 376 triangles. Les 97 poses passent (étirement maximal 1,8970 ; erreur de liaison 5,894e-8 ; distance minimale mesurée bras relevés/tête 0,2553). Les 40 ventouses et leurs UV passent également. Debug et Release de 130 réussissent. La vidéo et les mesures de cadence de 126 restent historiques ; cette série n’en produit pas de nouvelles.
