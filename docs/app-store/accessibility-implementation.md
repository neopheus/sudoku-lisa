## Validation de livraison du build 5

Le 7 octobre : 55 tests moteur réussis (78,419 s) et 23 tests applicatifs réussis, rapports `/tmp/lisa-release-b5-core.log` et `/tmp/lisa-release-b5-app-tests.xcresult`.

Le simulateur iPhone SE (3e génération, iOS 18.5) passe maintenant le test de jeu au texte maximal : 1 test, zéro échec, 27,291 s, rapport complet `/tmp/lisa-se-initial.xcresult`. Grille, outils et neuf touches entièrement dans l'écran ; saisie sans défilement et panneau de détails contrôlés. [Capture SE relue](accessibility-proof/largest-game-se.png). Aucune correction supplémentaire nécessaire.

Aucun appareil iOS physique connecté (`devicectl list devices`). VoiceOver, commandes réellement prononcées, clavier/braille et installation TestFlight physique ne sont donc pas déclarés validés. Aucun nouveau gain de batterie mesuré.

## Correction après retour sur le texte agrandi — 7 octobre

Le précédent critère « commande atteignable après défilement » était insuffisant pour le jeu. La nouvelle disposition garde une barre compacte, une grille et un clavier 3 × 3 ; les chiffres du clavier augmentent jusqu'à 56 pt pour une base de 28 pt. Les informations longues, notes et statistiques sont dans un panneau de détail en Dynamic Type. La miniature décorative de l'accueil conserve sa taille d'illustration.

Compléments : préparation de grille isolée dans l'arbre d'accessibilité avec focus sur le statut et annulation ; repères non colorés supplémentaires pour pairs et chiffres identiques lorsque demandé par iOS ; commandes visibles et actions VoiceOver pour rotation/inclinaison Poulpi. Les surfaces communes renforcent leur contour avec Augmenter le contraste et suppriment leur reflet avec Réduire la transparence. Cela ne constitue pas une prise en charge exhaustive de toutes les transparences de l'app.

Validation du correctif :
- Compilation iOS réussie. Deux tests de thème réussis dans `/tmp/lisa-large-text-repair-3.xcresult` (rapport complet). Ratios de police et contraste identiques aux mesures ci-dessous.
- Trois parcours UI de régression réussis : entrée/victoire/continuation (29,161 s), accueil/réglages/Poulpi (12,434 s), leçon (28,772 s), log `/tmp/lisa-large-text-ui-final.log`.
- Confirmation finale : rapport complet `TEST SUCCEEDED` dans `/tmp/lisa-large-text-confirmed.xcresult`, deux tests UI réussis en 36,559 s dans `/tmp/lisa-large-text-confirmed.log` : thème sombre/indice et jeu au texte maximal avec contrôle des rectangles entièrement visibles, saisie sans défilement et panneau de détail.
- [Capture de la partie agrandie relue](accessibility-proof/largest-game-compact.png). Appareil : simulateur iPhone 16, iOS 18.5. Aucun nouveau résultat iPhone SE.
- 474 clés applicatives et quatre clés stickers validées dans les cinq langues ; `git diff --check` réussi.
- Le premier lancement avait sélectionné un nom de cible erroné ; corrigé. Un lancement ultérieur n'avait exécuté que les deux tests unitaires, aucun UI : non compté comme preuve UI. Le test sombre intermédiaire héritait de la préférence de taille maximale, qui change le sélecteur en liste : taille normale désormais explicitement fournie au lancement, test confirmé.
- Les tests UI émettent encore un avertissement d'inversion QoS ; aucun gain de performances revendiqué. Le moteur n'a pas été modifié dans ce correctif ; ses tests précédents ne sont pas présentés comme réexécutés.

Les neuf catégories demandées sont recensées dans [la revue](accessibility-gap-review.md). Ses observations statiques précèdent ces corrections : les points génération, inclinaison, contraste des surfaces et repères de cellule ont été traités. Le parcours clavier/braille et les parcours réels VoiceOver/Contrôle vocal restent à éprouver. Aucun statut App Store Connect supplémentaire déclaré.

# Corrections d’accessibilité locales — 7 octobre 2026

Ces changements ne sont ni commités ni livrés dans TestFlight. La déclaration ASC existante du build 4 reste séparée : [accessibility.md](accessibility.md).

## Changements

- `LisaTheme` fournit les polices Dynamic Type arrondies et une palette sombre pour les panneaux lavande, menthe et jaune. Deux noms de polices système sont résolus une seule fois ; aucun cache de taille variable ni tâche permanente supplémentaire.
- Boutons multilignes, panneaux défilants et dispositions verticales aux tailles d’accessibilité : accueil, clavier/outils/statut de partie, victoire, choix des réglages et contrôles Poulpi. Le voyage propose une liste d’étapes à ces tailles.
- Les grilles 9 × 9 gardent leur disposition spatiale. La case sélectionnée dispose d’un résumé agrandi dans le jeu ; les leçons affichent les candidats en grand. Les coordonnées, chiffres et notes restent exposés à l’accessibilité.
- Erreurs et doublons : symbole d’exclamation en plus de la couleur. Indices et repères de leçon : bordure pointillée. Sélection de leçon : bord épais ; cible : double bord ; candidats exclus ou supprimés : chiffres barrés. Statuts du voyage : texte et icônes.
- Commandes vocales courtes pour les cases et chiffres ; actions VoiceOver pour verrouiller un chiffre et manipuler Poulpi. Le jeu derrière la pause est masqué au lecteur d’écran. Focus sur l’explication d’indice et sur le retour d’exercice ; annonce de la case après saisie lorsque VoiceOver est actif.
- Nouvelles chaînes traduites en français, anglais, allemand, espagnol et russe. Le contrôle de localisation accepte les commentaires de section `.strings` existants.
- Aucun changement du format de sauvegarde ni des règles de résolution dans ce lot. Les changements de vol et de rendu Poulpi présents simultanément dans l’arbre de travail appartiennent à un autre lot.

## Vérification

Les commandes utilisent des simulateurs QA dédiés ; `--uitest-reset` ne vise pas une installation personnelle.

- Compilation finale après le dernier ajustement de traduction : **BUILD SUCCEEDED**, journal `/tmp/lisa-a11y-final-build.log`. `git diff --check` réussi.
- `swift test` : 55 tests, zéro échec, 124,687 s. Journal `/tmp/lisa-a11y-core.log`.
- Première validation iOS : 22 tests applicatifs et 4 tests UI réussis. Rapport `/tmp/lisa-a11y-tests-2.xcresult` : contraste/polices, sauvegardes, indices, états Poulpi, jeu/notes/annulation/pause/reprise, calendrier/thème, accueil/réglages/Poulpi et leçon au texte maximal.
- Confirmation après corrections : partie au texte maximal → victoire → continuation, 57,245 s, plus deux tests de thème réussis. Journal `/tmp/lisa-a11y-confirmation.log`, cas de test tous réussis dans le journal. Xcode a bloqué la finalisation du `.xcresult` de cette exécution ; ce conteneur ne doit pas être utilisé comme un rapport complet.
- Mesures UIHostingController : corps 16 points, hauteur 19,33 → 54 points (**×2,79**) ; titre 24 points, hauteur 28,67 → 68,33 points (**×2,38**), de `.large` à `.accessibility5`. Le seuil de 200 % est évalué au maximum iOS ; les courbes titre/corps diffèrent aux niveaux intermédiaires.
- Contraste minimal des couples du thème testés : **4,531:1**, supérieur au seuil 4,5:1. Les tests incluent encres principale, secondaire et action, surfaces papier/lavande/menthe/jaune, thèmes clair/sombre, avec et sans surbrillance.
- Essai iPhone SE dédié `8D333E1A-A2D6-4A0B-A90B-F234F22BBE8A` : compilation réussie, mais le banc Xcode est resté bloqué avant le lancement des tests. Essai annulé, simulateur éteint ; **aucun résultat SE revendiqué**. Les tests validés utilisent iPhone 16 iOS 18.5.
- `python3 scripts/localization/check.py` : 469 clés applicatives et 4 clés stickers présentes dans les cinq langues ; paramètres `%@` et appels littéraux vérifiés.
- Relecture ciblée séparée : aucune régression majeure confirmée. Ajustement du paysage Poulpi au texte agrandi après cette revue.

Les captures initiales ont révélé des libellés coupés dans les sélecteurs de réglages au texte maximal. Les sélecteurs sont désormais en liste à ces tailles. Le premier test de continuation de victoire a échoué car il utilisait un ancien titre ; il a été corrigé pour utiliser `victoryContinue` et vérifier la grille suivante.

Le lot intermédiaire `/tmp/lisa-a11y-tests-final.log` contient deux échecs de test corrigés ensuite : ancien titre de continuation et seuil 200 % évalué prématurément à `.accessibility3`. Xcode a également bloqué la finalisation de ce rapport ; le processus a été arrêté après la fin des tests. La confirmation ci-dessus couvre les corrections.

Dernière vérification visuelle : `/tmp/lisa-a11y-visual-check.xcresult`, **TEST EXECUTE SUCCEEDED**, 2 tests UI, zéro échec, 37,623 s. Captures examinées : [partie Nuit](accessibility-proof/night-game.png), [indice Nuit](accessibility-proof/night-hint.png), [réglages au texte maximal](accessibility-proof/largest-settings.png). Le libellé de repérage d’indice a ensuite été précisé dans les cinq traductions (« cases en pointillés ») ; ce dernier changement de texte est contrôlé par le validateur de localisation.

Un avertissement runtime Xcode d’inversion de priorité (`dispatch_semaphore_wait`, thread interactif attendant un thread Default) apparaît pendant la fermeture de l’indice. Il n’a pas fait échouer le parcours ; l’origine n’est pas établie et aucune amélioration de performances n’en est déduite.

## Portée des résultats

Les ratios de contraste du thème couvrent les encres communes sur les surfaces opaques et leur surbrillance maximale. Ils ne constituent pas un audit exhaustif des images, décors, transparences et états de toutes les vues. Les chiffres et candidats à l’intérieur d’une grille restent de taille spatiale fixe ; le résumé agrandi est leur alternative.

Les tests XCUI vérifient les éléments d’accessibilité et les actions tactiles ; ils ne remplacent pas une partie jouée intégralement avec VoiceOver ou la reconnaissance du Contrôle vocal sur iPhone. Ces deux parcours restent à valider manuellement avant de revendiquer leur prise en charge complète. Les étiquettes ASC supplémentaires ne sont pas cochées par anticipation.

Pas de mesure batterie, CPU ou GPU réalisée pour ce lot. Aucun gain de consommation annoncé. Pas de contenu vidéo narratif nécessitant l’ajout de sous-titres ou d’audiodescriptions.

Implémentation et revue déléguées à deux agents `gpt-6.1-sol`. Aucun agent Astra utilisé ; le modèle de l’orchestrateur n’a pas été changé.

Critères Apple consultés : [texte agrandi](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria), [VoiceOver](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria), [Contrôle vocal](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voice-control-evaluation-criteria), [contraste](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria).
