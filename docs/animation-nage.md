# Nage et gestes du poulpe — 6 octobre 2026

Le déplacement et les tentacules partagent une cadence de deux secondes : poussée, glisse et récupération. La vitesse reste positive et la trajectoire se referme après 32 secondes. Les 24 articulations propagent la courbure de la base vers les pointes ; les bras s'ouvrent pendant le freinage et se replient différemment dans les virages. Une légère contraction du corps accompagne la poussée.

Les réactions ont des poses propres : salut d'un bras, curiosité, timidité, danse, jonglage, marche arrière, éternuement, pirouette, équilibre, étirement et nage énergique. Les rotations sont interpolées pour adoucir les changements de pose. Il s'agit d'une animation stylisée, sans simulation physique de l'eau ou de contacts au sol.

Le compagnon reste derrière le contenu de jeu dans `GameView`. Les étoiles permanentes autour de la grille restent supprimées. Les réglages d'animation et de réduction des mouvements continuent de désactiver les actions.

## Vérification locale

- Compilation Debug simulateur réussie.
- 32 tests du moteur réussis, dont continuité de la nage et concordance entre vitesse calculée et déplacement réel.
- Test UI `LisaUITests/testSpatialCompanionDoesNotBlockBoard` réussi sur iPhone SE : saisie avant et après un cycle complet, puis pause.
- Aperçu des six poses inspecté sur simulateur iPhone 16 : [vidéo](screenshots/poulpi-nage-et-gestes.mp4).
- Aperçu Debug reproductible : `--octopus-preview --octopus-motion-preview`. Six poses se succèdent toutes les cinq secondes dans un cadre agrandi. Le mode fixe existant reste disponible avec `--octopus-preview --octopus-still`.

Cette validation ne constitue pas un déploiement TestFlight ni un essai sur iPhone physique.
