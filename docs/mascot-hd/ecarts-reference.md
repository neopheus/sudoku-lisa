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
