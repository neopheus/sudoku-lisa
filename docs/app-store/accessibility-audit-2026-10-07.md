# Audit accessibilité — 7 octobre 2026

Vérification du code local et tests sur simulateurs iOS 18.5 iPhone 16 et iPhone SE dédiés QA. Aucune modification du code applicatif ni des déclarations App Store Connect pendant cet audit. Aucun iPhone physique connecté. Les résultats portent sur le code local, pas une certification du binaire distribué.

## Décision par fonctionnalité

| Fonctionnalité | Résultat de la vérification |
| --- | --- |
| VoiceOver | Libellés, valeurs, actions et annonces présents ; les tests XCUI vérifient quelques éléments. Navigation réelle, ordre de lecture et annonces vocales non validés avec VoiceOver actif. Ne pas déclarer sur cette seule preuve. |
| Contrôle vocal | Libellés de saisie et commandes alternatives présents, notamment Poulpi. Aucun essai réel de commande vocale : reste à valider. |
| Police plus grande | Plusieurs parcours passent à la taille système maximale, y compris saisie sur SE. Des informations visuelles restent à traiter : calendrier en police fixe et compteurs des chiffres masqués aux tailles d’accessibilité. Ne pas déclarer globalement à ce stade. |
| Interface sombre | Parcours accueil, jeu et indice passé en thème Nuit. Preuve locale favorable, avec défauts de contraste distincts ci-dessous. |
| Différencier sans couleur seule | Bordures, tirets, points, soulignements et symboles présents dans les principaux états inspectés. Le réglage système et les parcours en niveaux de gris n’ont pas été exercés ; validation complète restante. |
| Contraste suffisant | Défauts calculés dans plusieurs états, notamment les petits candidats corail en mode sombre. Correction nécessaire avant déclaration. |
| Animations réduites | Réglage système activé et vérifié dans l’application ; victoire réussie sur iPhone 16. Code des principaux effets inspecté. Preuve favorable sur le parcours testé, sans validation exhaustive sur appareil. |
| Sous-titres | Aucun contenu parlé/vidéo identifié ; sons synthétiques de jeu. Pas de fonctionnalité à déclarer pour le contenu actuel. |
| Descriptions audio | Aucun contenu vidéo narratif identifié. Pas de fonctionnalité à déclarer pour le contenu actuel. |

## Défauts et réserves concrets

### Contraste

Calcul sRGB à partir des couleurs et opacités du code, et non mesure d’un écran physique. Reproduction : `python3 docs/app-store/accessibility-proof/audit-20261007/contrast-check.py` ; résultats détaillés dans [contrast-ratios.json](accessibility-proof/audit-20261007/contrast-ratios.json).

| État | Rapport calculé |
| --- | ---: |
| Candidat éliminé dans un indice sombre | 2,40:1 |
| Texte corail sur papier sombre | 2,56:1 |
| Petite note sur case sélectionnée sombre | 4,32:1 |
| Candidat éliminé dans un indice clair | 4,38:1 |
| Chiffre saisi sur case sélectionnée claire | 4,36:1 |
| Chiffre saisi sur case d’indice claire | 4,46:1 |

Les petits textes devraient atteindre 4,5:1 selon les [critères Apple](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria). Les grands chiffres nécessitent une appréciation selon leur taille réelle ; les petites notes et candidats sont les défauts les plus nets. Les tests de palette existants passent (minimum testé 4,53:1), mais ne couvrent pas ces compositions. Sources : `LisaTheme.swift`, `GameView.swift/SudokuCellContent`, `HintCoachView.swift`. Le réglage de contraste accru ne modifie pas ces couleurs de cellule dans le code inspecté.

### Agrandissement du texte

- `CollectionViews.swift` : calendrier avec jours en 14 points et en-têtes en 12 points fixes. La date sélectionnée possède un autre affichage, mais pas l’ensemble du calendrier agrandi.
- `GameView.swift` : compteurs de chiffres restants retirés visuellement quand `dynamicTypeSize.isAccessibilitySize`. Ils restent dans le libellé accessible, ce qui ne fournit pas l’équivalent visuel à une personne utilisant seulement les gros caractères.
- Chiffres et notes de grille liés à la taille des cases. Le détail de la case sélectionnée est une alternative agrandie existante : les polices fixes ne suffisent donc pas, seules, à conclure à un échec global. Les [critères Apple](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria) permettent des vues détaillées équivalentes.

### Petit écran en taille normale

Sur SE, le test de victoire ne trouve pas la touche 9 : la troisième rangée se situe sous la zone visible et le test ne défile pas. La [capture issue de l’enregistrement](accessibility-proof/audit-20261007/se-standard-keypad.png) montre ce débordement. Cela prouve une limite de visibilité immédiate et du test, pas une impossibilité de jouer : le parcours après défilement n’a pas été validé. Le mode à texte maximal utilise une disposition compacte et [affiche bien les neuf touches](accessibility-proof/audit-20261007/se-largest-text.png).

## Preuves des tests et limites

- iPhone 16 : cinq tests UI (sombre, grand texte accueil/réglages/Poulpi, saisie/victoire, leçon, visibilité des neuf chiffres) et deux tests de thème passent dans le journal. Xcode reste ensuite bloqué pendant la finalisation/résolution des packages ; processus interrompu, bundle principal incomplet. Ne pas présenter cette commande entière comme réussie.
- iPhone SE : test de visibilité au texte maximal réussi ; test de victoire échoué pour la touche 9 hors zone visible en taille normale. Bundle complet : `/tmp/lisa-accessibility-audit-se-20261007.xcresult`.
- iPhone 16, exécution indépendante : victoire avec réglage système Réduire les animations activé réussie, commande `TEST EXECUTE SUCCEEDED`. Bundle : `/tmp/lisa-audit-motion-iphone16-20261007.xcresult`. [Preuve du réglage](accessibility-proof/audit-20261007/reduce-motion-setting.txt), [victoire](accessibility-proof/audit-20261007/iphone16-reduce-motion-victory.png).
- [Extraits des journaux conservés](accessibility-proof/audit-20261007/test-results.txt). Les tests utilisent le code local compilé dans `/tmp/lisa-validation`. Les réglages Réduire les animations des simulateurs ont été restaurés ; le simulateur SE initialement éteint a été arrêté.

Les tests automatisés XCUI ne remplacent pas des essais avec VoiceOver et Contrôle vocal réellement actifs. Pas de test exhaustif du contraste accru, de la transparence réduite, de la différenciation sans couleur ou des cinq langues pendant cet audit. Pas de validation physique ni de publication App Store Connect.
