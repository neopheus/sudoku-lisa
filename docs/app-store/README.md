# Fiche App Store — Lisa Sudoku

Mise à jour le 7 octobre 2026 dans App Store Connect, version iOS 1.0.

- Textes français enregistrés : sous-titre, texte promotionnel, description, mots-clés, copyright et notes de vérification. Copie dans `fr-FR.json`.
- Catégorie : Jeux, sous-catégorie Casse-tête.
- Build associé : 1.0 (4), traité par Apple et distribué via TestFlight. Icônes issues du build.
- Aucun envoi à la vérification App Store ni publication de la fiche.
- URL d’assistance et URL publique de confidentialité demandées au titulaire, absentes du projet. Coordonnées de vérification, classification d’âge, déclaration de confidentialité et droits de contenu restent à compléter avant une soumission App Store.

Les captures sont issues de l’application réelle sur un simulateur QA dédié, avec données locales réinitialisées. Aucun écran de fonctionnalité fictive n’est utilisé.

## Captures françaises

Six PNG RGB natifs de 1179 × 2556 : grille, accueil, indice expliqué, leçon, Voyage, Poulpi. Ordre des fichiers dans `fr-FR/`. Capture native sans redimensionnement ; les pièces jointes XCTest arrondissent ici la largeur à 1178 pixels et ne sont pas utilisées pour le chargement.

Parcours de capture : `UITests/AppStoreScreenshotTests.swift`, exécuté sur le simulateur QA dédié ; résultat final `/tmp/lisa-store-20261007-capture5.xcresult` : 1 test passé, zéro échec. `TEST_RUNNER_LISA_NATIVE_CAPTURE=1` active uniquement les pauses destinées à la capture native.

Chargement vérifié dans App Store Connect : **6 sur 10 captures**, noms et ordre confirmés, images acceptées et affichées. Textes déjà enregistrés. Preuve : [fiche française](app-store-connect-fr.jpg). Le chargement natif Chrome a été utilisé sans modifier les permissions de l’extension.
