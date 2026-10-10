# Réduction du travail redondant — 10 octobre 2026

## Modifications

- **Reflets** : le calendrier produit les images du passage visible de 1,6 s à la cadence existante, une image pour le masquer, puis attend le prochain cycle de 5,5 s. Le dessin, la phase absolue, le filtrage et les règles de visibilité ne changent pas. La programmation est vérifiée aux dates absolues réelles, aux limites flottantes et sur 100 000 étapes.
- **Paupières** : mêmes seize cibles et mêmes poids de déformation, mais seuls les poids modifiés sont transmis à SceneKit. Une mise à jour change au plus quatre poids par œil ; les poses répétées n'en écrivent aucun. La comparaison avec l'ancienne formule couvre 2 010 fermetures, réouvertures et interruptions.
- **Célébrations** : les cellules triées, positions, délais, rectangles et contours fixes sont conservés dans un cache d'une seule entrée par vue, invalidé lors d'un changement de taille ou d'événement. Les courbes d'animation et tous les dessins animés restent évalués à leur cadence habituelle.
- **Battle** : le temps exact continue d'avancer au rythme du réseau ; seul le libellé du chronomètre observe les secondes affichées. Les publications de décompte inchangées sont évitées. Les ticks de contrôle et les paquets réseau gardent leurs fréquences.
- **Sauvegardes** : l'app possède l'unique sauvegarde de sortie d'activité ; inactif puis arrière-plan ne déclenchent plus deux transactions. Une capture identique au fichier valide évite les deux remplacements atomiques et conserve la copie de secours précédente. Le fichier source est toujours relu et validé pour détecter une corruption.

Résolution, anticrénelage, maillage, matériaux, nombre de particules et politique de cadence ne sont pas abaissés par cette passe.

## Persistance conservée

Le point de sauvegarde toutes les cinq secondes reste en place. Quand seul le temps change, le fichier complet est encore enregistré. Un fichier de chronomètre séparé demanderait une association fiable avec la version de la sauvegarde et des règles de migration, restauration et export ; ce nouveau format n'a pas été introduit dans cette passe.

## Validation et limites

- Suite moteur complète : 95 tests, zéro échec. Après le dernier durcissement des dates négatives et de la précision du calendrier, les cinq tests ciblés d'effets passent également.
- Vérification exacte de la géométrie des célébrations sur trois tailles et les 81 origines possibles ; tests de poids de paupières et de conservation des fichiers pour les captures identiques.
- Modules Swift de l'application compilés avec le SDK iOS Simulator 27.1, cible iOS 17 ; toutes les sources AppTests et UITests passent la vérification de types. Tests applicatifs ajoutés pour l'isolation du chronomètre, les transitions de scène, les contours mis en cache et la pause des reflets.
- Contrôle des traductions dans les cinq langues et `git diff --check` réussis.

CoreSimulator reste inaccessible dans ce sandbox. Les tests App/UI n'ont pas été exécutés et les images animées n'ont pas été comparées sur appareil pendant cette passe. Les invariants numériques et les paramètres conservés ne suffisent pas à certifier la fidélité visuelle en fonctionnement.

Aucun gain d'autonomie, de chauffe ou de GPU n'est mesuré. Pour le mesurer : comparer les deux builds Release sur le même iPhone, avec la même luminosité, température initiale, musique, grille et paramètres, pendant des parcours de durée identique ; relever CPU/GPU et énergie avec Instruments. Conserver les animations actives et comparer aussi les transitions et les captures aux mêmes instants. Aucun commit ni déploiement effectué.
