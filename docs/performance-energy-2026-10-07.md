# Travail par image, sans réduction des animations

## Périmètre

Signalement : chauffe sur TestFlight, même sans interaction. Le modèle d’iPhone et le numéro du build installé ne sont pas connus. La référence locale est `0ad7bfa` ; le dernier build TestFlight documenté dans le dépôt est le build 4 (`7724ba5`). Aucun appareil physique n’est accessible pendant cette intervention.

Les cadences, la politique thermique, les durées, les trajectoires, les réactions, le maillage, les matériaux, la résolution native et l’anticrénelage sont conservés. Aucun réglage ni format de sauvegarde ajouté.

## Changements

- **Trajectoire** : précalcul des huit segments cubiques immuables et évaluation polynomiale de Horner. Le calcul du virage ne demande plus deux poses 3D complètes : seules les tangentes du plan sont évaluées. Les sinus/cosinus partagés du cycle de nage sont calculés une fois.
- **Poulpi** : les positions et échelles inchangées du visage et du corps ne sont plus réaffectées. Chaque pupille reçoit une position complète plutôt que deux modifications successives. Les caches sont invalidés lors du passage à une pose statique. Les articulations continuent à avancer à chaque image ; le chemin neutre évite les calculs de gestes inutilisés.
- **Décors SwiftUI** : le halo applique une rotation au groupe des douze rayons fixes. Les ailes des papillons et les rayures des bonbons sont des sous-vues équatables, indépendantes du temps. Aucune rasterisation supplémentaire ni réduction de détail.
- **Cycle de vie** : revue des conditions de visibilité, des feuilles, des onglets et de l’arrière-plan. Les gardes déjà présentes sont conservées ; aucune nouvelle fuite d’activité n’est établie par cette revue.

## Preuves ciblées

- Le test de notifications SceneKit échoue avant correction avec **2 880 notifications** pour 120 évaluations d’une pose inchangée, puis passe avec **zéro**. Cela démontre la suppression de réécritures ; ce n’est pas une mesure de consommation de l’app.
- Comparaison temporaire avec une copie de l’ancien rig : toutes les expressions, 49 instants par expression, transformations de tous les nœuds, opacités et poids des paupières. Écart toléré : `1e-6`. Test réussi. Cette copie de référence et son test sont exclusivement dans `/tmp/lisa-energy-isolated/AppTests`.
- Tests de trajectoire : comparaison avec une interpolation de Hermite indépendante à 120 échantillons/s, sur trois tours comprenant des temps négatifs ; tolérance `1e-11`. Vérification séparée du virage et du cycle de nage.
- Microbenchmark Release macOS, deux millions d’évaluations de nage par passage, huit passages avant/après alternés. Médiane du temps CPU du processus : **0,17885 s → 0,15465 s**, soit **−13,5 % pour ce seul calcul**. Sommes de contrôle identiques. Ce calcul représente seulement une petite partie du travail de l’app.
- Le microbenchmark du rig hébergé dans les tests Debug ne montre pas de gain CPU global fiable : médianes pratiquement identiques. Aucun pourcentage de gain du rig n’en est déduit.

## Coût global de l’accueil

Quatre lancements Release sur le même iPhone 16/iOS 18.5 simulé, dans l’ordre avant/après/après/avant. Sauvegarde de test identique sans partie, thème clair, animations actives, musique désactivée ; 20 secondes de stabilisation puis 30 secondes de mesure par différence du temps CPU du processus. L’unité est le pourcentage d’un cœur CPU du Mac.

| Passage | Version | CPU moyen |
| --- | --- | ---: |
| 1 | Avant | 22,92 % |
| 2 | Après | 22,99 % |
| 3 | Après | 22,26 % |
| 4 | Avant | 23,42 % |

Moyennes : **23,17 % → 22,63 %**, soit **−2,36 % observés**. Les journaux consultés conservent une cible de 60 images/s et un détail de niveau 0 ; les fenêtres archivées vont de 53,5 à 60 images/s sous la charge de l’hôte. La politique de cadence et de qualité n’a pas été réduite. Le gain est faible, avec une variabilité entre passages : **ce n’est pas une résolution démontrée de la chauffe**. D’autres simulateurs et travaux étaient actifs sur le Mac. Aucun gain de mémoire n’est établi par les RSS de fin de passage.

Un essai supplémentaire a regroupé les particules dans un Canvas. Il a donné 22,76 % de CPU sur un passage, sans bénéfice supplémentaire net, et dépassé le seuil de fidélité visuelle dans 14 comparaisons sur 30. Les captures montrent une rasterisation différente des symboles. **Cet essai a été retiré** ; le rendu original des particules est conservé. Le second simulateur créé pour les mesures a rencontré un blocage au lancement et a été arrêté ; les quatre mesures retenues viennent du simulateur dédié déjà opérationnel.

## Validation et limites

- **55 tests moteur réussis** avec `swift test --scratch-path /tmp/lisa-energy-core`.
- **23 tests applicatifs réussis** dans le dossier partagé : sauvegardes, migrations, notes/annulations, indices, apparence et animation. Les 40 comparaisons de décors couvrent cinq phases, les thèmes clair/sombre et les deux intensités du halo, à échelle 3 ; erreur moyenne admise inférieure à 0,15 sur 255.
- **Six parcours UI réussis sur plusieurs exécutions** : saisie/notes/annulation/reprise, chronomètre/pause/arrière-plan, rotation/zoom/lecture automatique, saisie avant/après le vol, effets/pause et victoire/prochaine grille/récompense.
- Compilations Release simulateur et iPhone réussies, sans signature ni envoi.
- Adaptation des tests UI aux types d’accessibilité et au défilement de l’écran Poulpi introduits en parallèle. Le test du chronomètre observe le temps avant pause/après reprise, car la grille couverte est maintenant masquée de l’arbre d’accessibilité. Le test de victoire utilisait un ancien libellé et un ancien retour à l’accueil ; il vérifie maintenant `victoryContinue`, la nouvelle grille puis la récompense conservée.
- Les premières exécutions ont révélé ces attentes périmées, un échec transitoire du message de combo et un échec du test de taille de police ajouté en parallèle. Les cas concernés passent lors des dernières exécutions. Certains processus Xcode sont restés en finalisation après la fin des cas ; les résultats individuels et les sommes XCTest sont distingués de la finalisation des bundles.

Les builds, traces et `.xcresult` restent dans `/tmp/lisa-energy-*`. Les valeurs du microbenchmark sont archivées dans [les données brutes](performance-energy-2026-10-07.json).

Des modifications d’accessibilité sont intervenues en parallèle dans le dépôt. Elles sont préservées. La comparaison de performances utilise une copie de `0ad7bfa` dans `/tmp/lisa-energy-isolated`, à laquelle seuls les trois fichiers de production de cette intervention ont été appliqués. Les tests d’intégration sont également exécutés sur le dossier de travail partagé.

La baisse de chauffe et le gain d’autonomie ne sont pas établis. Il faut comparer les versions Release sur le même iPhone, hors charge, à luminosité, état thermique initial et scénario identiques : accueil immobile, grille immobile, partie jouée et arrière-plan. Relever CPU, GPU, cadence réelle, consommation et état thermique pendant des sessions de 15 minutes. Ne pas interpréter le GPU ou la température du Mac comme ceux de l’iPhone.
