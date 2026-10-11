# Distribution TestFlight — Lisa Sudoku

## Préparation 1.0 (15) — 10 octobre 2026

- Build 15 configuré pour l'application et l'extension, ainsi que dans le générateur du projet.
- Contenu : protection et récupération des sauvegardes, résilience Battle, corrections de cadence et de paupières, suppression de travail graphique redondant, audio hors du thread principal et corrections de concurrence Swift 6.
- Vérification des traductions et `git diff --check` réussis. Les vérifications Swift 6 de l'application et des tests applicatifs ont réussi sans diagnostic avant cette préparation ; les tests iOS n'ont pas pu être exécutés dans cet environnement.
- Tentative d'archive `/tmp/lisa-release-20261010-b15.xcarchive` : échec à la résolution des dépendances, `sandbox-exec: sandbox_apply: Operation not permitted`. Xcode signale également des identifiants de compte indisponibles dans le trousseau. Journal : `/tmp/lisa-release-b15-archive.log`.
- La tentative de tests moteur Release est bloquée à la génération du dSYM (`Operation not permitted`). Ne pas la compter comme une suite de tests réussie.
- Suite moteur Debug exécutée ensuite : **96 tests réussis, zéro échec** (`/tmp/lisa-release-b15-debug-tests.log`).
- Après un premier refus d'écriture Git, nouvelle tentative réussie : sources et préparation du build 15 enregistrées dans le commit `49f893a`. Aucun push Git.
- Nouvelle tentative d'archive après ce commit : même refus `sandbox-exec: sandbox_apply: Operation not permitted`, avant compilation. Journal : `/tmp/lisa-release-b15-retry-archive.log` ; aucune archive produite à `/tmp/lisa-release-20261010-b15-retry.xcarchive`.
- Aucune archive signée du build 15, aucun export ni envoi Apple. Reprendre l'archive depuis un environnement Xcode autorisé, avec les identifiants Apple accessibles, puis vérifier traitement et groupes TestFlight.

### Notes de test proposées pour le build 15

Vérifiez les paupières, les clignements, les transitions et le ralenti de Poulpi. Testez la musique et les sons lors de la pause, du passage en arrière-plan, d'une interruption audio et du débranchement d'écouteurs. Vérifiez la reprise des parties et le mode Battle à plusieurs appareils, y compris une déconnexion. Les optimisations conservent les paramètres de rendu et les animations ; le gain réel d'autonomie reste à mesurer sur iPhone.

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

Le sudoku solo et sa progression fonctionnent localement, sans compte ni identifiant de démonstration. Le mode Battle nécessite une connexion Game Center et deux à quatre joueurs sur des appareils distincts. Depuis l’accueil, ouvrir Battle, inviter des amis, se déclarer prêt puis laisser l’hôte lancer la manche. Chaque joueur reçoit la même grille avec un départ commun et voit la progression des autres. Aucun indice en Battle. La personnalisation de Poulpi est accessible depuis son écran ; les couleurs sont gratuites et certains accessoires se débloquent en jouant. L’extension Lisa Stickers fournit 24 autocollants pour Messages. La galerie Poulpi permet aussi de partager les images et de transférer le pack vers WhatsApp installé. Aucun achat intégré ni publicité.

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
- Dernière vérification distante à 14 h 48 : build 5 toujours **En cours de traitement**, sans erreur affichée. [Preuve](screenshots/testflight-build-5-processing.png). Les groupes ne peuvent pas encore être associés ; aucune disponibilité aux testeurs ni approbation externe revendiquée.

### Notes de bêta à enregistrer après traitement

Cette version améliore la lisibilité et les commandes d'accessibilité. Merci de tester une partie avec la taille de texte iOS maximale : sélection d'une case, saisie, notes, annulation, indice et tutoriel. Le bouton Info affiche les détails de la partie en grand texte. Essayez également le thème Nuit, Réduire les animations, Différencier sans couleur et les commandes de rotation/zoom de Poulpi. Les retours sur VoiceOver, Contrôle vocal, clavier et braille sont particulièrement utiles ; indiquez le modèle d'iPhone, la version iOS et l'étape rencontrée. Vérifiez enfin la sauvegarde/reprise et la continuation après victoire.

## Préparation 1.0 (8) — 8 octobre 2026

- Battle entre deux à quatre amis via Game Center : même grille, départ synchronisé, statistiques en direct, podium et revanche. Personnalisation de Poulpi avec six couleurs et accessoires gagnés en jouant.
- Validation locale : 68 tests moteur, 28 tests applicatifs, trois scénarios UI Battle/personnalisation/accessibilité réussis ; contrôles ciblés supplémentaires après les dernières corrections. Traductions vérifiées dans cinq langues (574 clés).
- Les échanges Game Center entre appareils physiques restent à valider. Les scénarios UI utilisent des participants simulés.

### Parcours de test Battle

1. Installer cette même build TestFlight sur deux iPhone, avec deux comptes Game Center distincts, amis entre eux.
2. Ouvrir Battle sur le premier appareil et inviter le second. Accepter l’invitation, choisir la difficulté et mettre chaque joueur prêt. L’hôte indiqué dans le salon lance la manche.
3. Vérifier la même grille et le départ commun, puis saisir quelques chiffres : les statistiques adverses doivent évoluer. Tester notes, effacement et annulation ; les indices sont désactivés.
4. Terminer la manche, comparer le podium et lancer une revanche. Tester aussi un abandon et une interruption réseau, puis refaire une partie à quatre.
5. Dans Poulpi, changer de couleur, relancer l’app et vérifier sa conservation. Terminer une battle pour débloquer le bandeau ; cinq victoires débloquent la couronne. Vérifier que la sauvegarde solo est conservée.

Signaler le modèle d’iPhone, iOS, numéro de build, comptes distincts, étape et capture via TestFlight.

### Livraison vérifiée

- Sources : `ab1d93a`, puis correction Release `7ea3604`. Aucun push Git. Les modifications préexistantes des médias App Store restent séparées.
- Archive signée : `/tmp/lisa-release-20261008-b8.xcarchive`, signature vérifiée ; application et extension en 1.0 (8), entitlement Game Center présent.
- Les 69 tests moteur passent également en Release (`/tmp/lisa-battle-work/release-core.log`).
- Envoi accepté le 8 octobre à 12 h 59 (Europe/Paris) : `Upload succeeded`, `EXPORT SUCCEEDED` ; journal `/tmp/lisa-release-20261008-b8-upload.log`.
- Traitement Apple terminé, consignes et notes de vérification enregistrées. Build associé aux groupes **Lisa — Interne** (3 testeurs), **Lisa — Externe** (1) et **Liens à partager** (1), puis soumis à la vérification. État final observé : **En cours de test**. Les effectifs de groupes peuvent inclure les mêmes personnes. Installation physique non vérifiée.
- [Build 8](https://appstoreconnect.apple.com/teams/70a667fb-878b-43af-a968-b2aabf6f1436/apps/6819455460/testflight/ios/b7283013-3eb3-40d5-b39c-87392d4027ba) · [Lien public TestFlight](https://testflight.apple.com/join/tWFCgtQF) · [Preuve](screenshots/testflight-build-8.png).

## Préparation 1.0 (9) — 8 octobre 2026

- Animations Battle, aperçu Poulpi fixe en portrait et paysage, galerie de 24 autocollants transparents, catalogue commun avec iMessage et import de pack WhatsApp.
- Ressources et traductions intégrées dans cinq langues. Le manifeste de confidentialité de l’extension déclare les préférences locales UserDefaults désormais utilisées par le catalogue.
- Parcours UI et contrôles des ressources effectués sur simulateur ; envoi réel iMessage et import dans WhatsApp à confirmer sur iPhone.
- Vérification avant livraison : 69 tests moteur et 35 tests applicatifs réussis ; couverture des langues et `git diff --check` validées. Les tests UI de galerie, Battle et Poulpi fixe ont été validés pendant l’implémentation.
- Sources : commit `ec0535c`, aucun push Git. Archive signée `/tmp/lisa-release-20261008-b9.xcarchive`, signature vérifiée ; app et extension 1.0 (9), ressources et manifestes présents.
- Envoi accepté le 8 octobre à 15 h 30 (Europe/Paris) : `Upload succeeded` et `EXPORT SUCCEEDED` dans `/tmp/lisa-release-20261008-b9-upload.log`. Traitement Apple terminé.
- Build associé aux trois groupes existants : **Lisa — Interne** (3 testeurs), **Lisa — Externe** (1) et **Liens à partager** (1), puis soumis à vérification. État final confirmé dans App Store Connect : **En cours de test**. Notes de test et consignes de vérification enregistrées ; installation physique non vérifiée.
- [Build 9](https://appstoreconnect.apple.com/teams/70a667fb-878b-43af-a968-b2aabf6f1436/apps/6819455460/testflight/ios/2ac4977f-d0c3-4066-a425-755d53493c97) · [Lien public TestFlight](https://testflight.apple.com/join/tWFCgtQF) · [Preuve](screenshots/testflight-build-9.png).

## Livraison du 9 octobre 2026 — build 10

- Sources : commit `f8caf94`, sans push Git. Pastilles Battle circulaires avec pourcentage/erreurs, bandeau visible pendant la saisie, animations adverses et commandes de grille enrichies.
- Validation : 69 tests moteur réussis lors de la livraison ; traductions et `git diff --check` valides. Tests applicatifs et UI de cette même implémentation documentés dans `docs/battle-poulpi.md`.
- Archive Release signée : `/tmp/lisa-release-20261009-b10.xcarchive` ; signature profonde vérifiée, app et extension en 1.0 (10), entitlement Game Center présent.
- Envoi accepté le 9 octobre à 07 h 06 (Europe/Paris) : `Upload succeeded` et `EXPORT SUCCEEDED` dans `/tmp/lisa-release-20261009-b10-upload.log`. Apple indique que le paquet est en traitement.
- La session navigateur App Store Connect a expiré : reconnexion demandée au titulaire. Fin du traitement, association aux groupes internes/externes et disponibilité du build 10 non vérifiées à ce stade. Aucun essai physique revendiqué.
- À reprendre après reconnexion : ouvrir le build 10, renseigner les notes ci-dessous, associer Lisa — Interne, Lisa — Externe et Liens à partager, soumettre si nécessaire et vérifier l’état En cours de test.

### Notes de test du build 10

Battle : nouvelles pastilles rondes avec pourcentage de progression et erreurs. Testez à 2–4 joueurs, avec des noms longs et de grands caractères. Vérifiez les animations quand un adversaire progresse, les compteurs sous les chiffres 1–9, le verrouillage par appui long, les notes, l’effacement, l’annulation et les surbrillances. Vérifiez également que votre partie solo est conservée.


### Correction des commandes Battle — build 11 en préparation

Les boutons 1–9 restent fixés en bas de l’écran pendant la course. La grille est réduite sur écran court pour afficher le plateau et garder les commandes à portée de doigt. En très grands caractères, le clavier reste dans le défilement afin de conserver des commandes lisibles. La compilation simulateur et l’archive Release signée ont réussi. L’archive finale `/tmp/lisa-release-20261009-b11-final.xcarchive` a été acceptée par Apple le 9 octobre à 09 h 45 (`Upload succeeded`, `EXPORT SUCCEEDED`, `/tmp/lisa-release-20261009-b11-final-upload.log`).

- Correctifs clavier de cette passe : commits `fd0e47b` et `b7a820d`. Archive et IPA de build 11 reconstruits depuis ces commits avant envoi.


### Mise en page corrigée des statistiques Battle — build 12

L’aperçu iPhone SE du build 11 a révélé un chevauchement du pourcentage et du nombre d’erreurs sous les pastilles. Ces deux informations sont de nouveau présentées sur deux lignes distinctes sous chaque avatar. La capture de référence iPhone SE est conservée dans `docs/screenshots/battle-clavier-fixe-iphone-se.png`. La correction passe sur le parcours UI simulé. Archive Release signée `/tmp/lisa-release-20261009-b12.xcarchive`. Envoi accepté par Apple le 9 octobre à 09 h 59 (`Upload succeeded`, `EXPORT SUCCEEDED`, `/tmp/lisa-release-20261009-b12-upload.log`). Le traitement et l’assignation aux groupes sont encore à vérifier dans App Store Connect.

- Correction des statistiques et capture : commit `c9ae2e2`. Le test UI ciblé iPhone SE passe le 9 octobre (parcours quatre joueurs, clavier et progression adverse), rapport `/tmp/lisa-validation/Logs/Test/Test-SudokuLisa-2026.10.09_09-55-51-+0200.xcresult`.

### Statistiques Battle interactives — build 13

- Les statistiques de progression et d’erreurs ne sont plus affichées en permanence sous les avatars. Touchez un joueur pour les afficher à côté de lui ; la pastille temporaire de gain reste au-dessus de l’avatar concerné.
- Vérifications locales : 69 tests moteur réussis ; tests UI iPhone SE pour l’ouverture des statistiques et les très grands caractères réussis ; 575 clés de localisation et cinq langues vérifiées ; `git diff --check` réussi.
- Source : commit `c05d101`. Archive Release signée `/tmp/lisa-release-20261009-b13.xcarchive`, signature vérifiée, application et extension en 1.0 (13). Envoi accepté par Apple le 9 octobre 2026 (`Upload succeeded`, `EXPORT SUCCEEDED`, `/tmp/lisa-release-20261009-b13-upload.log`).
- Traitement Apple terminé. Build associé aux trois groupes existants **Lisa — Interne**, **Lisa — Externe** et **Liens à partager** ; App Store Connect affiche **En cours de test**. Notes de test enregistrées. Installation sur iPhone physique non vérifiée.
- [Build 13](https://appstoreconnect.apple.com/teams/70a667fb-878b-43af-a968-b2aabf6f1436/apps/6819455460/testflight/ios/e2814278-9dde-40bc-998f-bc3ce5ce72ce) · [Lien public TestFlight](https://testflight.apple.com/join/tWFCgtQF).

## Poulpi animé et paupières corrigées — build 14

- Expressions enrichies et animations partagées dans l’application ; rubrique Poulpi avec rejeu, boucle, pause, ralenti et aperçu compact.
- Iris adaptés à la surface courbe des yeux ; paupières supérieure et inférieure aux coins fixes, fermeture courbe et clin d’œil complet, sans faux pli indépendant.
- Validation locale : 69 tests moteur, 49 tests applicatifs sur simulateur ; parcours des commandes Poulpi en portrait/paysage réussi. Gros plans des yeux aux fermetures 0/25/50/75/100 %, contrôles de courbure, coins fixes et pic du clin d’œil. Traductions vérifiées dans cinq langues.
- Sources : commit `93ad76f`, sans push Git. Archive Release signée `/tmp/lisa-release-20261009-b14.xcarchive`, signature profonde et versions app/extension vérifiées en 1.0 (14).
- Envoi accepté par Apple le 9 octobre à 15 h 56 : `Upload succeeded` et `EXPORT SUCCEEDED` dans `/tmp/lisa-release-20261009-b14-upload.log`. Traitement Apple terminé ; build associé à **Lisa — Interne**, **Lisa — Externe** et **Liens à partager**, notes enregistrées et soumission TestFlight effectuée. État final constaté : **En cours de test**, trois groupes associés. Aucun essai sur iPhone physique revendiqué.
- [Build 14](https://appstoreconnect.apple.com/teams/70a667fb-878b-43af-a968-b2aabf6f1436/apps/6819455460/testflight/ios/6799c71f-d133-4a43-952c-0232fab6053e) · [Preuve](screenshots/testflight-build-14.jpg) · [Lien public TestFlight](https://testflight.apple.com/join/tWFCgtQF).

### Notes de test du build 14

Poulpi est plus expressif : yeux, regard, paupières, bouche, tête et tentacules animés. Dans la rubrique Poulpi, essayez les émotions et acrobaties, le rejeu, la boucle, la pause, le ralenti et l’aperçu compact. Vérifiez particulièrement les clignements, le clin d’œil, les transitions entre expressions et le rendu de profil. Signalez tout débordement, saccade ou problème de paupière avec le modèle d’iPhone. Vérifiez aussi les animations pendant une partie et l’option Réduire les animations.


## iPhone et Apple Watch — build 16, 10 octobre 2026

- Reprise autorisée de la distribution après la validation locale : 112 tests moteur/invitations, 84 tests applicatifs et 46 tests UI réussis après corrections/relances ciblées ; un test de grand écran ignoré sur les iPhone de validation.
- Contenu : application Watch avec le même Poulpi 3D que l’iPhone, expressions partagées, contexte de progression/couleur/accessoire, mini-Sudoku Watch et invitations privées CloudKit. Corrections d’intégration de la cloche et préservation de la partie solo.
- Archive signée réussie : `/tmp/lisa-testflight-20261010-watch-b15.xcarchive`. L’archive contient l’app iPhone, l’app Watch et l’extension iMessage. `codesign --verify --deep --strict` réussi ; ressources JSON/yeux Poulpi identiques entre iPhone et Watch. Les profils générés contiennent les droits du conteneur `iCloud.com.xavier.sudokulisa` et les notifications.
- L’archive source était en 1.0 (15). Apple signalait déjà un build 15 : l’export automatique a relevé le numéro à **1.0 (16)** pour l’envoi. Projet et générateur alignés ensuite sur 16, sans changement du code applicatif.
- **Envoi accepté le 10 octobre 2026 à 18 h 44, heure de Paris** : `Upload succeeded`, `Uploaded package is processing`, `EXPORT SUCCEEDED` dans `/tmp/lisa-testflight-20261010-upload.log`. Le journal ContentDelivery confirme `cfBundleVersion: 16` pour l’application `6819455460`.
- App Store Connect dans Chrome est déconnecté ; reconnexion demandée au titulaire. Fin du traitement, conformité et association aux groupes TestFlight non confirmées. Aucun essai sur appareils physiques, ni déploiement du schéma CloudKit de production confirmé.
- Aucun commit ni push demandé ou réalisé. Les sources locales validées sont incluses dans l’archive ; empreintes avant export dans `/tmp/lisa-testflight-20261010-source-manifest.json`.


## Synchronisation des couleurs Poulpi sur Watch — build 17, 11 octobre 2026

- Ajout du canal immédiat WatchConnectivity en complément du contexte de fond ; requête de dernière apparence à l’ouverture/réactivation/reconnexion de la Watch ; nouvelle tentative même si la couleur n’a pas changé après un envoi échoué. Initialisation du délégué iPhone dès le lancement pour les réveils Watch en arrière-plan.
- Conservation du dernier contexte valide sur la montre et rejet des contextes plus anciens. Le choix de couleur/accessoire reste effectué sur l’iPhone.
- Validation : 113 tests moteur/invitations réussis, quatre nouveaux tests applicatifs de transport réussis. Archive Release iPhone/Watch/stickers et vérification profonde de signature réussies en 1.0 (17). Rendu doré + étoile contrôlé sur simulateur depuis un contexte enregistré, capture `/tmp/lisa-watch-sync-gold.png` ; transfert entre appareils physiques non validé ici.
- Archive : `/tmp/lisa-testflight-20261011-watch-sync-b17.xcarchive`. Envoi Apple accepté le 11 octobre à 00 h 14 (Paris), `Upload succeeded` et `EXPORT SUCCEEDED` dans `/tmp/lisa-testflight-watch-sync-b17-upload.log`.
- Aucun commit ni push.

- Traitement terminé et build **approuvé** dans App Store Connect. Notes françaises enregistrées ; trois groupes associés : Lisa — Interne (3 testeurs), Lisa — Externe et Liens à partager. Le bouton « Notifier les testeurs » reste disponible : les notifications externes automatiques n’ont pas été envoyées. Ne pas confondre l’approbation externe avec l’état « En cours de test ».
- [Build 17](https://appstoreconnect.apple.com/teams/70a667fb-878b-43af-a968-b2aabf6f1436/apps/6819455460/testflight/ios/3ffd2782-b252-4d9b-aeb2-d045ad475220). Preuve locale : `/tmp/lisa-testflight-build-17.png`.
