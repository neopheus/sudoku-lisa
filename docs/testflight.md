# Distribution TestFlight — Lisa Sudoku

## Configuration

- Équipe Apple : XAVIER VALENTIN — `S2UPJPPKKG`.
- Application : `com.xavier.sudokulisa` ; extension : `com.xavier.sudokulisa.LisaStickers`.
- Version initiale : 1.0 (1). L’export peut ajuster le numéro de build pour éviter un doublon.
- Groupe externe prévu : **Testeurs Lisa**, lien public limité à 100 testeurs.
- La soumission TestFlight ne publie pas l’application sur l’App Store.

## Description bêta

Lisa Sudoku est un jeu de sudoku en français avec un univers coloré, une mascotte expressive et une progression individuelle. Jouez hors ligne, choisissez votre difficulté, utilisez les notes et les indices, relevez le défi quotidien et découvrez le voyage de 25 étapes. Votre partie est sauvegardée automatiquement sur votre iPhone.

## À tester

Merci de tester une partie complète, les notes, les indices, l’annulation, la pause et la reprise après fermeture de l’application. Essayez le défi quotidien, le parcours Voyage et les thèmes Soleil et Nuit. Signalez tout texte coupé, difficulté à toucher une case, ralentissement ou perte de progression via les retours TestFlight, avec le modèle d’iPhone et les étapes pour reproduire le problème.

## Notes pour l’examen Apple

Aucun compte utilisateur ni identifiant de démonstration n’est nécessaire. Le jeu et sa progression fonctionnent localement. Les tournois Game Center ne sont pas activés dans cette bêta : aucun classement de production n’est configuré. L’extension Lisa Stickers fournit quatre stickers pour Messages. Aucun achat intégré ni publicité.

Les coordonnées du contact de bêta doivent être saisies dans App Store Connect par le titulaire ou confirmées avant utilisation ; ne pas inventer d’adresse ou de téléphone.

## Archive et envoi

Exécuter depuis la racine du projet, après reconnexion dans Xcode → Settings → Accounts. Le générateur conserve les réglages de signature. Choisir un chemin d’archive neuf à chaque tentative aboutie.

```sh
python3 scripts/generate_project.py
xcodebuild -project SudokuLisa.xcodeproj -scheme SudokuLisa -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/sudoku-lisa-testflight-derived -archivePath /tmp/sudoku-lisa-testflight-1.xcarchive -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath /tmp/sudoku-lisa-testflight-1.xcarchive -exportOptionsPlist scripts/TestFlightExportOptions.plist -exportPath /tmp/sudoku-lisa-testflight-export -allowProvisioningUpdates
```

La seconde commande Xcode **envoie le build à Apple**. Créer auparavant la fiche App Store Connect correspondant à l’identifiant. Après traitement, vérifier les informations de conformité, renseigner les informations de test, créer le groupe interne requis et le groupe externe, puis soumettre le build à l’examen TestFlight. Activer le lien public après approbation. Tester l’installation sur iPhone physique et relever la taille distribuée avant d’annoncer la bêta disponible.

## Journal de préparation

- Signature automatique configurée dans le générateur et le projet pour l’application, l’extension et les tests.
- Première tentative d’archive : connexion du compte Xcode rejetée par Apple ; profils de provisioning absents. Aucun build envoyé.
- Icônes iMessage ajoutées : 12 variantes opaques, compilation actool réussie. Archive de contrôle non signée réussie (`/tmp/sudoku-lisa-testflight-unsigned.xcarchive`) et 19 tests moteur réussis. Bundle de cette archive : 1 533 649 octets (1,53 Mo décimaux), sous le budget local de 100 Mo. Cette archive non signée ne constitue pas un build distribué et ne prouve pas la taille TestFlight.
- Reconnexion Xcode et App Store Connect effectuée par le titulaire. Blocage confirmé dans les deux interfaces : abonnement Apple Developer expiré (date de renouvellement affichée : 15 août 2026). La création de la fiche Lisa Sudoku est refusée. Aucun build signé ni envoyé, aucun groupe ni lien TestFlight créé. Renouvellement à effectuer par le titulaire sur developer.apple.com/account avant reprise. Aucun secret n’est stocké dans le dépôt.

## Après la commande de renouvellement

- Commande de renouvellement confirmée sur le site Apple le 5 octobre 2026. Les interfaces Developer et App Store Connect affichent encore un abonnement expiré lors de la vérification suivante.
- Archive signée **Apple Development**, équipe S2UPJPPKKG, réussie : `/tmp/sudoku-lisa-testflight-signed-1.xcarchive`. Vérification locale codesign réussie. Cette signature de développement ne suffit pas pour TestFlight.
- Export App Store Connect essayé, refusé : `Team "XAVIER VALENTIN" does not have permission to create "iOS App Store" provisioning profiles.` Journaux : `/tmp/lisa-testflight-local-export.log`.
- Aucun nouvel envoi ni lien TestFlight. À la réactivation effective, créer la fiche et réutiliser cette archive pour l’export de distribution ; ne pas refaire le paiement.

## Envoi du 6 octobre 2026

- 28 tests Swift réussis, archive Release signée et vérification codesign réussies.
- Fiche Lisa Sudoku créée dans App Store Connect : identifiant Apple `6819455460`, bundle `com.xavier.sudokulisa`.
- Correction de la cible LisaStickers en `com.apple.product-type.app-extension.messages` dans le générateur et le projet : les icônes iMessage requises sont maintenant exportées dans le bundle.
- Archive envoyée : `/tmp/sudoku-lisa-testflight-20261006-fixed.xcarchive`.
- Envoi accepté à 00 h 43 (Europe/Paris) : `Upload succeeded` et `EXPORT SUCCEEDED`. Journal local : `/tmp/sudoku-lisa-20261006-fixed-upload.log`. Le traitement Apple a commencé ; cet accusé ne prouve pas encore la disponibilité pour les testeurs.
- Groupe interne « Lisa — Interne » créé sans distribution automatique ni testeur invité.

## Livraison 1.0 (3) — 6 octobre 2026, après-midi

- Sources livrées : commit `edd382f` (159 fichiers), comprenant Poulpi interactif, les animations, les nouveaux visuels et les cinq langues. Aucun push Git effectué.
- 35 tests Swift réussis ; couverture des 335 clés et des 4 descriptions iMessage validée dans les cinq langues. Générateur Xcode aligné sur les langues et le build 3.
- Archive Release signée : `/tmp/lisa-release-20261006-b3.xcarchive`, vérification `codesign --verify --deep --strict` réussie. Application et extension en 1.0 (3), catalogues d’icônes, quatre stickers et traductions présents. Bundle local : 19 612 122 octets ; ce chiffre n’est pas la taille téléchargée depuis TestFlight.
- Envoi accepté le 6 octobre à 16 h 52 (Europe/Paris), avec `Upload succeeded` et `EXPORT SUCCEEDED` dans `/tmp/lisa-release-20261006-b3-upload.log`.
- Traitement Apple terminé et build ajouté au groupe **Lisa — Interne**, qui compte deux testeurs. Notes de test enregistrées. L’installation du build 3 sur un appareil physique n’a pas été vérifiée.
- [Fiche du build](https://appstoreconnect.apple.com/teams/70a667fb-878b-43af-a968-b2aabf6f1436/apps/6819455460/testflight/ios/b535580f-7326-424f-b588-8fbe1048196c) · [preuve](screenshots/testflight-build-3.jpg).
- Des retouches du modèle et de ses fichiers de sculpture sont apparues en parallèle après le commit de livraison. Elles sont conservées dans le dossier de travail et ne font pas partie du build 3.

## Livraison 1.0 (4) — 7 octobre 2026

- Sources : commit `7724ba5`, difficultés fiabilisées, moteur partagé, indices progressifs, cinq tutoriels, sauvegardes par mode, continuation et récompense Poulpi. Aucun push Git.
- Validation préalable : 53 tests moteur, 18 tests applicatifs, parcours UI sur iPhone 16 et SE simulés ; compilation Release finale réussie.
- Archive Release signée : `/tmp/lisa-release-20261007-b4.xcarchive`. Vérification `codesign --verify --deep --strict` réussie ; application et extension en 1.0 (4). Bundle local : 20 115 892 octets, distinct de la taille TestFlight.
- Envoi accepté le 7 octobre à 09 h 16 (Europe/Paris) : `Upload succeeded` et `EXPORT SUCCEEDED`. Journal : `/tmp/lisa-release-20261007-b4-upload.log`.
- Traitement Apple terminé ; notes de test enregistrées. Build associé aux groupes **Lisa — Interne**, **Lisa — Externe** et **Liens à partager**, puis soumis à la vérification TestFlight. État final observé : **En cours de test** pour le build 4, trois groupes associés. Installation physique de ce build non vérifiée.
- [Fiche du build 4](https://appstoreconnect.apple.com/teams/70a667fb-878b-43af-a968-b2aabf6f1436/apps/6819455460/testflight/ios/7533ad90-5ebb-4858-9bae-914d815d0dcd) · [preuve](screenshots/testflight-build-4.jpg).

## Livraison 1.0 (5) — 7 octobre 2026

- Sources : commit `ff3b794`. Accessibilité, disposition compacte au texte maximal, détail agrandi de case, focus de préparation, repères sans couleur, commandes accessibles de Poulpi et adaptations des surfaces. Inclut les ajustements de calcul et de rendu documentés dans `docs/performance-energy-2026-10-07.md`. Aucun push Git.
- Validation : 55 tests moteur (78,419 s), 23 tests applicatifs ; parcours de jeu au texte maximal réussi sur simulateur iPhone SE (27,291 s), en complément de l'iPhone 16. Les rapports et limites figurent dans `docs/app-store/accessibility-implementation.md`.
- Archive Release signée : `/tmp/lisa-release-20261007-b5.xcarchive`, `codesign --verify --deep --strict` réussi ; app et extension en 1.0 (5). Bundle local : 20 266 759 octets, distinct de la taille TestFlight.
- Manifeste technique complété pour UserDefaults (`CA92.1`), utilisé par les préférences locales de langue ; fichier validé et présent dans l'archive. Référence : [Apple TN3183](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest).
- Envoi accepté à 14 h 39 (Europe/Paris) : `Upload succeeded` et `EXPORT SUCCEEDED`, log `/tmp/lisa-release-20261007-b5-upload.log`. App Store Connect affiche ensuite le build 5 en cours de traitement.
- Brouillon accessibilité : **Interface sombre** et **Animations réduites**, sauvegardés. Publication de ces étiquettes indisponible tant que l'app n'est pas publique. Aucun appareil physique connecté ; parcours réels VoiceOver/vocal/clavier/braille et installation physique non validés.
