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
