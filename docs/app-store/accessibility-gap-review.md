# Accessibilité : revue des écarts locaux

Revue statique du code local du 7 octobre 2026. Aucun changement applicatif ni lancement de compilation dans cette revue. Le dépôt évolue en parallèle : les points ci-dessous décrivent le code lu, et doivent être rapprochés du résultat final de validation. La présence d’API ne valide pas un parcours VoiceOver, Contrôle vocal ou clavier. Les résultats antérieurs restent dans `accessibility.md` et ne constituent pas des essais réalisés pendant cette revue.

## Matrice des capacités

| Capacité | Implémentation observée | Preuve encore nécessaire |
| --- | --- | --- |
| VoiceOver | Cases Button avec ligne/colonne, valeur, notes, erreurs, doublons et indice. Annonce après saisie. Focus de l’explication d’indice et du feedback de leçon. Labels des réglages et de navigation. | Jouer une grille, ouvrir/fermer indice et tutoriel, sauvegarder/reprendre, générer/annuler, pause/victoire avec VoiceOver réellement actif ; vérifier retour du focus. |
| Contrôle vocal | `accessibilityInputLabels` pour cases, chiffres, outils, difficultés et leçons ; contrôles textuels natifs. | Tester les commandes prononcées FR et au moins une autre langue, les états Notes oui / Recherche…, le verrouillage d’un chiffre et la fermeture de chaque présentation. |
| Clavier / Accès complet au clavier | Les Button natifs sont présents. Pas de `onKeyPress`, `keyboardShortcut` ni `FocusState` de navigation de grille trouvés dans App. | Parcours Tab/Maj-Tab avec Accès complet au clavier, navigation entre 81 cases, saisie/notes/effacement, sortie de toutes les présentations. Ne pas conclure que les Button sont inaccessibles au clavier à partir de cette seule recherche. |
| Police plus grande | Helpers de police et branches de disposition selon `dynamicTypeSize`, réglages accessibles en liste, détail de case et candidats. Les chiffres de la grille utilisent encore une taille liée à la case. | Vérification visuelle et fonctionnelle à 200 % puis taille maximale : accueil, reprise, calendrier, voyage, progrès, jeu, indice, leçons, Poulpi et réglages. Le retour utilisateur signale une dégradation ; la capacité reste non acquise tant que ces parcours ne sont pas corrigés et relus. |
| Interface sombre | Palette adaptative et choix Nuit ; Soleil/Nuit/Papier appliqués via `preferredColorScheme`. | Vérifier toutes les surfaces et états, y compris grille/indices/tutoriels/calendrier/Poulpi, sur le résultat final. Le choix automatique suivant l’iPhone n’est pas proposé. |
| Différencier sans couleur seule | Sélection avec contour, indice avec pointillés, erreur/doublon avec symbole, chiffres verrouillés sélectionnés, états du voyage avec icônes et texte. | États même chiffre et pairs restent principalement des remplissages colorés. Tester en niveaux de gris, et avec Différencier sans couleur activé. |
| Contraste suffisant | Palette et tests unitaires de certains couples de couleurs ; symboles d’erreur et doublon. | Mesurer les couleurs réellement compositées de tous les états, notes et marquages. Les ratios de palette ne couvrent pas toutes les transparences, fonds, dégradés et états désactivés. |
| Animations réduites | `accessibilityReduceMotion` consulté par l’horloge décorative, les mascottes, Poulpi, le jeu et les transitions principales ; tâches liées à activité/écran et réglage Décor animé. | Rejouer navigation, pause, indices, tutoriels et victoire avec le réglage système activé. Le réglage n’est pas une preuve d’arrêt de chaque transition implicite. |
| Sous-titres | Pas de vidéo dialoguée ou de narration trouvée ; sons courts et musique ambiante optionnelle. Le gameplay dispose de retours visuels/textuels. | Vérifier qu’aucune information utile n’est transmise exclusivement par audio ; ne pas déclarer une fonction de sous-titrage inexistante. |
| Descriptions audio | Pas de contenu vidéo narratif correspondant trouvé ; décors non essentiels masqués à l’accessibilité, scène Poulpi avec label et valeur. | Aucun lecteur avec piste de description audio observé. Ne pas assimiler labels VoiceOver et descriptions audio. |

## Préférences système réellement consultées

| Préférence | Code observé |
| --- | --- |
| Taille du texte | Environnement SwiftUI `dynamicTypeSize` utilisé dans plusieurs écrans. Helpers scalables ; éléments géométriques de grille et décor encore fixes. |
| Réduire les animations | Oui, plusieurs vues et moteur d’animation. |
| Interface sombre système | Remplacée par le choix interne Soleil/Nuit/Papier ; `preferredColorScheme` retourne toujours clair ou sombre. |
| Augmenter le contraste | Aucune lecture `accessibilityContrast` trouvée. Certaines couleurs UIKit natives peuvent s’adapter automatiquement ; la palette personnalisée consultée ne distingue que clair/sombre. |
| Différencier sans couleur | Aucune lecture `accessibilityDifferentiateWithoutColor` trouvée. Des symboles sont présents indépendamment du réglage. |
| Réduire la transparence | Aucune lecture `accessibilityReduceTransparency` trouvée ; de nombreux fonds utilisent une opacité. |
| Texte en gras | Pas de branche explicite trouvée ; les polices système sémantiques peuvent suivre le système. Vérifier les faces personnalisées/arrondies à l’affichage avant d’affirmer la prise en charge. |

Les interrupteurs Sons, Musique douce, Retours haptiques et Décor animé sont des préférences internes. Ils ne remplacent pas un essai de l’application avec les préférences d’accessibilité iOS.

## Cinq actions concrètes à prioriser

1. **Rétablir la lisibilité des grandes tailles.** Corriger les compositions qui gonflent ou se chevauchent, puis relire les parcours complets à 200 % et au maximum. Garder une distinction explicite entre texte de lecture agrandissable et grille géométrique, dont les notes doivent avoir un équivalent lisible dans le détail de case. Fichiers : `LisaTheme.swift`, `GameView.swift`, `LessonBoardView.swift`, vues de collection et accueil.
2. **Définir un parcours clavier de grille.** Ajouter une sélection/focalisation explicite avec déplacement directionnel, chiffres, notes et effacement, puis vérifier Tab/Maj-Tab et les présentations. Les 81 Button ne suffisent pas à démontrer un parcours efficace. Fichier : `GameView.swift`.
3. **Isoler la préparation de grille pour VoiceOver.** `GenerationOverlay` recouvre les vues mais ne les masque pas à l’accessibilité et ne demande pas de focus sur la préparation/Annuler. Cacher les interactions sous-jacentes pendant génération et rétablir le focus après annulation/fin. Ne pas cacher automatiquement la grille pendant l’indice : ses descriptions et repères sont utiles pour comprendre la déduction. Fichiers : `GenerationOverlay.swift`, `RootView.swift`, `GameView.swift`.
4. **Traiter les préférences de visibilité.** Examiner Augmenter le contraste, Réduire la transparence et Différencier sans couleur sur les fonds réellement composités. Ajouter un repère non coloré pour même chiffre/pairs lorsque pertinent, et une option Système au thème si le suivi automatique est souhaité. Absence d’écoute explicite n’implique pas que chaque élément natif échoue, mais la palette personnalisée ne gère pas ces états. Fichiers : thème, cellules et réglages.
5. **Compléter les alternatives de rotation Poulpi.** Le glissement vertical modifie `pitch`, mais les actions d’accessibilité ne proposent que rotation horizontale (`yaw`), zoom et rire. Ajouter inclinaison haut/bas et vérifier leur accès vocal/clavier ; conserver Recentrer. Fichier : `PoulpiView.swift`.

Aucun nouveau statut App Store Connect ne découle de cette revue. Les capacités restent à confirmer dans le build effectivement distribué, avec les technologies d’assistance actives sur iPhone.
