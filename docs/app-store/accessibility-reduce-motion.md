# Réduire les animations — validation locale

Validation du 7 octobre 2026 sur Lisa Gameplay QA, iPhone 16, iOS 18.5, UUID `F60920A4-E595-4FAD-9DD0-C7FC876233A7`.

- L’option iOS « Reduce Motion » a été activée dans Réglages > Accessibilité > Motion sur ce simulateur QA uniquement. Elle était désactivée auparavant et reste activée après la validation.
- `LisaUITests/LisaUITests/testZenModeStillAllowsVictory` : succès, 1 test, 0 échec, 20,032 secondes. Le test reprend une grille en mode zen, place les trois valeurs restantes, vérifie l’absence des annonces de combo pendant la saisie, puis la victoire et la récompense de voyage « 5 / 25 étoiles ».
- Attachement du test : `System Reduce Motion: true`. Le lancement inclut donc `--uitest-reduce-motion` et l’application confirme la vraie option système.
- Capture de victoire inspectée : récompense et bouton de continuation visibles. Le décor reste présent, sous forme statique.
- Deux captures au repos du même écran, espacées de 22,32 secondes, ont exactement les mêmes pixels RGB : `difference_bbox=None`, dimensions 1179 × 2556. Cette comparaison porte uniquement sur cet écran et ces deux instants.

## Preuves

- [Option système activée](accessibility-reduce-motion-setting.png)
- [Victoire avec Réduire les animations](accessibility-reduce-motion-victory.png)
- Résultat XCTest : `/tmp/lisa-accessibility-reduce-motion-20261007.xcresult`
- Log : `/tmp/lisa-accessibility-reduce-motion-20261007.log`
- Attachement système : `/tmp/lisa-accessibility-reduce-motion-text/495303FC-D363-43F5-99E1-2078977E6910.txt`
- Comparaison temporelle : `/tmp/lisa-accessibility-idle-a.png` et `/tmp/lisa-accessibility-idle-b.png`

Ces preuves sont locales au simulateur. Elles ne valident ni VoiceOver, ni la conformité complète d’un mode sombre, ni l’ensemble des parcours sur iPhone physique. Aucune mesure batterie/GPU n’a été réalisée. Aucun code applicatif n’a été modifié pour cette validation.
