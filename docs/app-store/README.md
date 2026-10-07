# Fiche App Store — Lisa Sudoku

Mise à jour le 7 octobre 2026 dans App Store Connect, version iOS 1.0.

- Textes français enregistrés : sous-titre, texte promotionnel, description, mots-clés, copyright et notes de vérification. Copie dans `fr-FR.json`.
- Catégorie : Jeux, sous-catégorie Casse-tête.
- Build associé : 1.0 (4), traité par Apple et distribué via TestFlight. Icônes issues du build.
- Aucun envoi à la vérification App Store ni publication de la fiche.
- Classification d’âge enregistrée : 4+ (avec classifications régionales calculées par Apple).
- Déclaration « aucune donnée collectée » enregistrée en brouillon. Publication suspendue à la confirmation du titulaire de l’engagement juridique demandé par Apple.
- URL d’assistance, URL publique de confidentialité, coordonnées de vérification, prix et pays de lancement demandés au titulaire. Droits de contenu restant à confirmer.

Les captures sont issues de l’application réelle sur un simulateur QA dédié, avec données locales réinitialisées. Aucun écran de fonctionnalité fictive n’est utilisé.

## Captures françaises

Six PNG RGB natifs de 1179 × 2556 : grille, accueil, indice expliqué, leçon, Voyage, Poulpi. Ordre des fichiers dans `fr-FR/`. Capture native sans redimensionnement ; les pièces jointes XCTest arrondissent ici la largeur à 1178 pixels et ne sont pas utilisées pour le chargement.

Parcours de capture : `UITests/AppStoreScreenshotTests.swift`, exécuté sur le simulateur QA dédié ; résultat final `/tmp/lisa-store-20261007-capture5.xcresult` : 1 test passé, zéro échec. `TEST_RUNNER_LISA_NATIVE_CAPTURE=1` active uniquement les pauses destinées à la capture native.

Chargement vérifié dans App Store Connect : **6 sur 10 captures**, noms et ordre confirmés, images acceptées et affichées. Textes déjà enregistrés. Preuve : [fiche française](app-store-connect-fr.jpg). Le chargement natif Chrome a été utilisé sans modifier les permissions de l’extension.

## En-tête et résultats de recherche

Deux illustrations promotionnelles créées avec imagegen à partir de l’identité et des captures du jeu, distinctes des six captures natives :

- `fr-FR/07-entete.png` : 5244 × 2950, Poulpi et chiffres ; 1/1 ressource enregistrée.
- `fr-FR/08-recherche.png` : 1920 × 1280, Poulpi, titre et représentation de la grille ; 1/1 ressource enregistrée.

Les sorties de génération ont été adaptées techniquement aux dimensions exigées par Apple (rééchantillonnage, sans revendication de détail natif supplémentaire). Comparaison visuelle de la grille avec la capture source ; aperçu iPhone de recherche et de page produit inspecté. Preuves : [recherche](search-preview-fr.jpg), [en-tête](header-preview-fr.jpg). L’aperçu Apple reste indicatif, pas une publication effective ni une mesure de conversion.

## Compléments et publication

`fr-FR/09-imessage.png` : capture native 1179 × 2556 de Lisa Stickers dans Messages sur le simulateur QA, quatre stickers visibles, conversation fictive vide fournie par le simulateur. Aucun message envoyé. Chargement traité et vérifié dans la section App iMessage : 1/10 capture. Apple indique que ce format sera adapté aux autres tailles iPhone.

Voir [l’audit de préparation](readiness-audit.md) pour les champs manquants et les preuves techniques. Les pages locales `public/support.html` et `public/privacy.html` sont des brouillons à héberger après ajout du contact approprié ; aucune URL n’est inventée. Les rubriques facultatives (vidéo, autres langues, campagnes/pages personnalisées) ne sont pas toutes nécessaires à un premier lancement. Les déclarations d’accessibilité nécessitent une validation complète des critères Apple.
