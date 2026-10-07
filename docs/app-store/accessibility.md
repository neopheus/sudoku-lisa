# Mise à jour du brouillon — build 5

Le 7 octobre 2026, le brouillon iPhone enregistre **Interface sombre** et **Animations réduites**. Le thème Nuit dispose désormais des surfaces et encres adaptatives ; le parcours réglages → partie → indice est testé. [Preuve du brouillon](accessibility-proof/asc-build5-draft.png).

La publication reste bloquée par Apple tant qu'une version n'est pas disponible dans l'App Store. Les autres capacités ne sont pas cochées par anticipation. Le texte maximal est désormais testé sur iPhone 16 et SE simulés ; cela ne suffit pas à certifier tous les contenus à 200 %, notamment les chiffres géométriques internes à la grille. Les essais vocaux, VoiceOver et clavier/braille réels restent à effectuer sur iPhone.

## Contrôle physique restant

Sur le build 5 installé depuis TestFlight :
1. Activer VoiceOver dans Réglages iOS → Accessibilité. Reprendre une partie, trouver une case par ligne/colonne, saisir une valeur, des notes puis effacer/annuler. Vérifier les annonces et le retour du focus.
2. Ouvrir un indice, parcourir ses étapes, ouvrir le tutoriel associé et revenir au jeu. Tester pause/reprise, annulation d'une génération, victoire et grille suivante.
3. Activer Contrôle vocal. Utiliser les noms des cases/chiffres et les numéros superposés pour jouer, ouvrir/fermer les panneaux et incliner/zoomer Poulpi sans glissement tactile.
4. Avec un clavier et l'Accès complet au clavier, vérifier Tab/Maj-Tab, activation des boutons et absence de piège de focus. Avec une plage braille, vérifier coordonnées, valeurs, notes et erreurs.
5. Refaire les étapes utiles au texte maximal, en Nuit, avec Différencier sans couleur et Réduire les animations. Consigner modèle, iOS, langue, étape et résultat avant de compléter les déclarations ASC.

Aucun appareil physique connecté n'était disponible durant la livraison. Les tests XCUI tactiles ne sont pas présentés comme ces essais physiques.

---

# Accessibilité — déclaration App Store

Déclaration contrôlée le 7 octobre 2026 pour la version 1.0 (build 4). Les corrections locales ultérieures sont détaillées dans [accessibility-implementation.md](accessibility-implementation.md) et ne sont pas encore dans ce build TestFlight. La déclaration concerne l’iPhone. Elle ne constitue pas une certification de toutes les fonctions d’accessibilité.

État ASC vérifié : **Brouillons (1), Prise en charge sur iPhone : Animations réduites**. Le bouton Publier est désactivé : Apple exige une version disponible dans l’App Store pour cet appareil. Aucun contournement ni soumission de l’app n’a été effectué. L’URL d’accessibilité facultative reste vide, faute d’URL publique confirmée. Preuve : `accessibility-asc-draft.jpg`.

## Fonction retenue

**Animations réduites** : le réglage iOS arrête l’horloge du décor et les déplacements périphériques (`LisaMotion.swift:36-38`), désactive les animations SceneKit de la mascotte (`LisaMascot.swift:27`) et celles de la scène Poulpi (`PoulpiView.swift:66`). Les transitions de jeu, les indices et la victoire consultent également ce réglage. Le réglage interne Décor animé permet aussi d’arrêter les animations décoratives.

L’audit du code n’a identifié aucun déclencheur majeur de rotation, de mise à l’échelle ou de mouvement périphérique qui échappe à ces contrôles. Les contrôles historiques sur simulateur sont décrits dans `docs/ambiance.md` ; ils restent distincts des tests du jour.

Validation du jour : `LisaUITests/LisaUITests/testZenModeStillAllowsVictory` réussi en 20,0 secondes sur le simulateur QA iPhone 16 iOS 18.5, avec le réglage système Réduire les animations activé. Rapport `/tmp/lisa-accessibility-reduce-motion-20261007.xcresult`, log `/tmp/lisa-accessibility-reduce-motion-20261007.log`. Ce scénario vérifie la saisie et la victoire en mode zen ; il ne certifie pas VoiceOver, le contraste ou chaque écran de l’app. Aucun code applicatif n’avait été modifié au moment de cette déclaration ; un lot local de corrections a ensuite été autorisé.

## Fonctions non déclarées pour le build 4

| Fonction | Motif |
| --- | --- |
| VoiceOver | Libellés, valeurs et actions présents ; parcours complet au lecteur d’écran non validé. |
| Contrôle vocal | Aucun parcours intégral avec commandes vocales validé. |
| Police plus grande | Nombreuses polices de taille fixe ; agrandissement 200 % non établi. |
| Interface sombre | Palette Nuit adaptative, mais grandes surfaces colorées fixes à vérifier sur tous les parcours. |
| Différencier sans couleur seule | Certains états de grille dépendent encore de couleurs ; audit visuel complet nécessaire. |
| Contraste suffisant | Ratios et tous les états de l’interface non mesurés. |
| Sous-titres / descriptions audio | Pas de contenu vidéo narratif correspondant ; aucune capacité supplémentaire revendiquée. |

Ne pas cocher une fonctionnalité sur la seule présence d’une API. Les tâches courantes incluent la navigation, les réglages, le jeu, les aides et la reprise.

Critères Apple consultés :

- https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
- https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria
- https://developer.apple.com/help/app-store-connect/manage-app-accessibility/dark-interface-evaluation-criteria
