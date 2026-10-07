# Validation locale avant commit — 7 octobre 2026

- `swift test` : 55 tests réussis, zéro échec (105,701 s).
- Contrôle de localisation : 474 clés applicatives et quatre clés stickers dans les cinq langues. `git diff --check` réussi.
- Compilation iOS et 23 tests applicatifs réussis sur iPhone 16 / iOS 18.5, simulateur QA `F60920A4-E595-4FAD-9DD0-C7FC876233A7`. Une première erreur de suppression de dossier temporaire ne se reproduit pas lors de la relance des 23 tests.
- 27 parcours UI réussis sur les exécutions cumulées. Un test réservé à un écran large est ignoré sur cette destination.
- **Échec restant** : `AdaptiveLayoutUITests/testHomeAndPoulpiRemainUsableAfterRotation`, commande `poulpiAnimation-happy` non atteignable en paysage malgré le défilement. Cause exacte non établie ; la suite UI complète ne peut pas être déclarée verte.

Les tests ont été adaptés aux libellés accessibles des commandes, au nouveau type accessible de Poulpi, au défilement de ses commandes et aux descriptions enrichies des cases d’indice. Les parcours ordinaires imposent une taille de texte standard pour éviter de reprendre la préférence maximale laissée par les tests Dynamic Type.

Le simulateur avait Réduire les animations activé : désactivé pour confirmer le parcours animation/rotation/zoom/lecture automatique, qui passe ensuite. Une réinstallation du runner a été nécessaire car une relance utilisait encore les anciens sélecteurs malgré la recompilation. Aucun changement de production dans ce complément.

Journaux hors dépôt : `/tmp/lisa-commit-swift-test.log`, `/tmp/lisa-commit-ios-confirm.log`, `/tmp/lisa-commit-ios-fresh.log`, `/tmp/lisa-commit-poulpi-motion.log`. Les résultats sont locaux au simulateur et ne prouvent ni le fonctionnement physique ni un gain de consommation. La finalisation du rapport Xcode de la relance `fresh` a été interrompue après la fin des cas ; les résultats individuels de cette exécution proviennent du journal.
