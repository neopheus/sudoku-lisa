# Battle entre amis et Poulpi

## Parcours

L’accueil ouvre une battle privée de 2 à 4 joueurs via Game Center. Chaque joueur doit être connecté à Game Center. L’organisateur est choisi de manière déterministe parmi les participants (identifiant Game Center trié) : le bouton de départ et le choix de difficulté apparaissent sur son appareil. Ce n’est pas nécessairement la personne qui a envoyé l’invitation.

Chaque participant indique qu’il est prêt. Une grille unique est générée par l’organisateur, distribuée puis révélée au départ commun après un compte à rebours. La progression correspond aux bonnes cases ajoutées, hors chiffres donnés. Les réponses adverses ne sont jamais affichées. Les notes et annulations restent autorisées ; les erreurs s’accumulent sans élimination et les indices sont absents.

L’arrivée est validée contre la solution par l’organisateur. Les temps sont rapportés à une horloge monotone synchronisée ; les arrivées à moins d’une demi-seconde partagent leur rang. L’hôte doit rester jusqu’au podium même après avoir fini sa grille. Le classement est amical, sans protection contre un client modifié ni serveur arbitre.

## Isolation et réseau

`BattleService` possède une `GameSession` distincte : aucune battle ne remplace une sauvegarde solo, ses notes, ses annulations ou son contexte. Game Center assure le transport ; aucune dépendance ou infrastructure serveur supplémentaire n’est nécessaire. La connexion Game Center est indépendante du classement hebdomadaire.

Les échanges identifient le protocole, la partie, la manche et leur séquence. Les messages sont bornés à 32 Kio et la progression à deux envois par seconde. Génération, tâches et caches sont bornés. Les avatars adverses sont des rendus fixes du même modèle, sans scène animée permanente par joueur.

Une interruption ne suspend pas le chrono. La récupération reste soumise aux possibilités de GameKit ; la réinvitation automatique documentée concerne seulement les matchs à deux. Une coupure réseau à 3–4 joueurs peut donc mener à un abandon. Une perte de l’hôte annule la manche ; il n’y a pas de transfert d’hôte. Aucun résultat annulé ne débloque de récompense.

## Personnalisation

Six palettes : Original (sculpt violet/bleu conservé), Corail, Lavande, Bleu lagon, Menthe et Doré. Un accessoire à la fois : aucun, étoile du voyage (5 étapes), bandeau (première battle terminée), couronne (5 victoires).

Les choix s’appliquent au vrai modèle 3D, aux scènes solo et aux avatars. La migration préserve l’ancienne étoile équipée. Les sauvegardes illisibles restent intactes et leur écriture est suspendue. Les récompenses ne sont enregistrées qu’au podium et pour un joueur ayant terminé ; les 256 derniers identifiants de manche empêchent les attributions répétées.

## Validation

Les tests moteur couvrent les règles, messages, classements, apparences et reçus. Les tests iOS vérifient la migration et les contrôles de rendu. `BattleUITests` utilise exclusivement une fixture locale de débogage, activée avec `--uitest-reset --uitest-battle`, pour tester le compte à rebours, les saisies, le podium, les récompenses et la conservation de la partie solo. Cette fixture n’est pas une preuve de connectivité multijoueur.

Avant distribution : essais de 2 puis 4 appareils avec comptes Game Center distincts, invitation app fermée/ouverte, départ mesuré, réseau lent, coupure/récupération, hôte finissant en premier, arrière-plan et revanche. Mesurer les écarts de départ et le délai d’actualisation. Ces essais physiques restent distincts des tests locaux et du simulateur.

### Résultats locaux du 8 octobre 2026

- `swift test --scratch-path /tmp/lisa-battle-core-final` : 68 tests réussis avant le dernier ajustement des interruptions ; les 10 tests Battle ciblés repassent après cet ajustement et le déplacement de l’attribution des récompenses dans la finalisation métier.
- `LisaStoreTests` : 28 tests réussis, dont migration, sauvegarde illisible, progression, équipement et snapshots Metal des six palettes. Les erreurs de shader détectées au premier passage ont été corrigées ; la restauration de l’original compare ses pixels avec une tolérance subpixel et son multiplicateur exact.
- Les trois `BattleUITests` passent : grands caractères ; compte à rebours/saisie/annulation/notes/podium/récompense/conservation solo ; accueil/personnalisation/persistance après relancement.
- `python3 scripts/localization/check.py` : 574 clés partagées complètes dans les cinq langues. `git diff --check` passe.
- Simulateur dédié : `Lisa Gameplay QA`, iOS 18.5, `F60920A4-E595-4FAD-9DD0-C7FC876233A7`. DerivedData : `/tmp/lisa-validation`. Journaux : `/tmp/lisa-battle-work/`.
- La passe finale recompilée termine avec `TEST SUCCEEDED` : 28 tests applicatifs et le parcours UI complet de battle repassent. Rapport final valide : `/tmp/lisa-validation/Logs/Test/Test-SudokuLisa-2026.10.08_12-41-04-+0200.xcresult`. Certains passages précédents avaient bloqué à la clôture sous Xcode 27.1 (`invalidDigitCount(94232)`) ; leurs rapports incomplets ne sont pas retenus.
- Cette validation initiale précédait la livraison TestFlight ; voir `docs/testflight.md` pour son état. Aucun essai réseau multi-compte sur appareils physiques.

- Dernier contrôle visuel : correction sRGB → lumière linéaire pour les palettes ; les quatre tests de rendu repassent avec `TEST SUCCEEDED`. Rapport : `/tmp/lisa-validation/Logs/Test/Test-SudokuLisa-2026.10.08_12-43-46-+0200.xcresult`.

- Validation de livraison : les 69 tests moteur passent en Release. Une référence de revanche au helper UI de débogage a été protégée par `#if DEBUG` ; l’archive Release signée compile ensuite avec succès.
