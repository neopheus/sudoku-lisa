# Vérification des animations — 12 octobre 2026

Deux arrière-plans étaient explicitement figés (`motionEnabled: false`) :
Apprendre et Battle. Ils utilisent désormais la permission d'animation de leur
écran. Battle suspend aussi ses animations pendant la confirmation de sortie.
Les horloges conservent les contrôles de visibilité, de premier plan, du réglage
Décor animé et de Réduire les animations. Les miniatures du carnet restent des
illustrations statiques ; aucune conversion des images de décor n'a été réalisée.

Le simulateur Lisa Assistance QA utilisé pour les captures précédentes contient
`settings.animatedDecor = false`, provenant du scénario `--uitest-static`.
Ce réglage explique les éléments immobiles de cette installation. Sa réactivation
manuelle n'a pas été confirmée : Device Hub affiche le simulateur, mais les commandes
de lancement et les gestes n'ont pas ouvert l'application lors de la vérification.

Validation : `swift test`, 120 tests moteur et 12 invitations réussis.
14 tests iOS ciblés réussis : rendu des décors, des papillons, des humeurs de Poulpi,
et deux nouveaux tests de cycle de vie. L'horloge reprend après couverture,
arrière-plan et changement de réglage ; le rendu Poulpi reprend après retrait de
la fenêtre, pause explicite et désactivation/réactivation.
Résultat : `/tmp/lisa-assistance-validation/Logs/Test/Test-SudokuLisa-2026.10.12_10-07-07-+0200.xcresult`.
Pas de validation sur iPhone physique ni d'affirmation de résolution de tous les
emplacements signalés sans leur identification.
