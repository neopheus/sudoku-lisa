# Invitations Lisa et compagnon Watch

Périmètre approuvé : relations privées CloudKit acceptées explicitement, demandes de disponibilité dans l'app iPhone et sur Watch, puis vraie invitation Game Center pour rejoindre Battle. Aucun rapprochement silencieux d'identités Game Center/iCloud, aucun serveur payant.

## Décisions
- Bibliothèque LisaInvitations commune iPhone/Watch : CloudKit privé/partagé, événements créés séparément et réduction déterministe, comptes vérifiés, mémoire bornée, rafraîchissement sur événement/ouverture.
- Chaque cercle provient d'un partage CloudKit privé accepté. Aucune requête filtrée sur une base publique ne sert de contrôle d'accès.
- La réponse Watch indique la disponibilité ; GameKit reste responsable du salon iPhone. La partie solo doit être sauvegardée avant toute transition.
- Notifications de changement génériques : récupérer les invitations avant toute réponse, jamais répondre à un identifiant inventé dans un push de base partagée.
- Watch : boîte d'invitations, même modèle 3D Poulpi que sur iPhone animé uniquement à l'écran, mini-Sudoku 4x4 local, progression et apparence reçues de l'iPhone.
- Cinq langues, VoiceOver, Réduire les animations et absence de boucle réseau permanente.

## Validation
Tests des états et autorisations des invitations, compilation Swift 6 des deux plateformes et des tests, contrôles du projet et des traductions. L'activation du conteneur iCloud, le schéma de production, les profils signés, les notifications physiques et les échanges entre deux comptes Apple doivent être validés séparément. Aucun gain batterie ni service cloud fonctionnel ne sera annoncé sans preuve.


## Activation Apple à terminer

1. Dans Certificates, Identifiers & Profiles, créer/associer `iCloud.com.xavier.sudokulisa` aux identifiants `com.xavier.sudokulisa` et `com.xavier.sudokulisa.watchkitapp`, activer CloudKit et Push Notifications pour les deux, puis renouveler les profils de signature.
2. Sur deux installations de développement signées utilisant deux comptes iCloud, créer un cercle, partager un accès privé en lecture/écriture, l'accepter sur l'autre iPhone. Le cercle est limité à quatre participants (propriétaire compris). Au moins deux membres doivent avoir accepté avant l'envoi.
3. Les enregistrements privés/partagés sont `LisaFriendRoom` (`title`: String) et `LisaInvitationEvent` (`invitationID`, `kind`, `difficulty`, `senderName`: String ; `expiry`: Date). Les événements sont enfants du record racine `room`, dans une zone `LisaFriends-<UUID>` partagée par CKShare. Aucun index de requête personnalisé n'est nécessaire : récupération par changements de zone. Créer les types en développement par un premier parcours complet, puis déployer le schéma en production depuis CloudKit Console avant TestFlight.
4. Tester proposition, refus, acceptation, annulation, expiration après dix minutes, révocation du partage, changement de compte, hors ligne, ouverture à froid, Watch jumelée et notifications en arrière-plan. Confirmer que la sauvegarde solo est conservée en rejoignant Battle.

Les abonnements CloudKit sont des indications de changement silencieuses. Les alertes locales dépendent du réveil accordé par le système et ne garantissent pas une livraison immédiate, notamment après fermeture forcée. La liste est réconciliée à l'ouverture. Un partage en écriture n'est pas un journal infalsifiable : un membre peut modifier ses propres événements ; les métadonnées servent à rejeter les mutations attribuées à un autre acteur. Le propriétaire contrôle l'accès et peut supprimer tout le cercle.

Contrôle local du 10 octobre 2026 : `cktool get-teams` ne trouve aucun jeton de gestion (`No management token found`). Aucun conteneur, profil ni schéma de production n'a donc été confirmé ou modifié par cette livraison locale.


## Bilan initial (avant la reprise ci-dessous)

- `swift test --disable-sandbox` : 96 tests SudokuCore et 12 tests LisaInvitations réussis. Les 12 tests d'invitations ont été relancés après durcissement.
- Mini-Sudoku Watch : 200 grilles aléatoires contrôlées (solution unique, indices fixes, règles, annulation, victoire et conflits).
- Vérification Swift 6 directe du module iPhone et des sources Watch ; tests AppTests vérifiés par le compilateur uniquement. Les deux nouveaux tests de transition solo/Battle ne sont pas annoncés comme exécutés.
- Traductions Core et Watch, fichiers plist/entitlements et projet Xcode vérifiés. Ajout du target Watch idempotent.
- Le build Xcode complet est bloqué par les permissions d'accès aux caches SwiftPM. CoreSimulator refuse la connexion ; aucune validation visuelle, installation signée, notification physique, TestFlight ou mesure batterie réalisée pour cette fonctionnalité.
- Les alertes iPhone peuvent être relayées à la Watch selon les réglages système. La Watch reçoit aussi les indications CloudKit pour actualiser sa boîte ; les notifications distantes ne transportent pas de réponse de jeu automatique.


## Reprise de validation du 10 octobre 2026

La compilation Xcode complète a révélé une erreur Swift 6 dans le callback Watch. Le délégué utilise désormais la variante asynchrone sur le MainActor, sans transporter un completion handler non Sendable entre acteurs. Le mode `remote-notification` a été ajouté au plist Watch, conformément à la [documentation Apple](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app).

Le premier test UI a aussi détecté que la barre d'invitations placée autour du TabView recouvrait Réglages. La cloche est maintenant intégrée à la barre de navigation de l'onglet actif et de Battle. En partie solo, elle est intégrée à l’en-tête existant : elle ne recouvre plus les commandes et ne retire plus une ligne au contenu, y compris en paysage et avec les plus grands caractères.

Avec CloudKit, `CODE_SIGNING_ALLOWED=NO` permet la compilation mais provoque l'arrêt au lancement sur simulateur : l'entitlement `com.apple.developer.icloud-services` manque. Les tests exécutables utilisent donc la signature locale ad hoc du simulateur, sans profil Apple ni signature de distribution :

```sh
xcodebuild -project SudokuLisa.xcodeproj -scheme SudokuLisa \
  -destination 'platform=iOS Simulator,id=F60920A4-E595-4FAD-9DD0-C7FC876233A7' \
  -derivedDataPath /tmp/lisa-validation CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -collect-test-diagnostics never test

xcodebuild -project SudokuLisa.xcodeproj -scheme LisaWatch \
  -destination 'platform=watchOS Simulator,id=DA0E3A32-A329-4DBC-B2F8-9AB0B116DCF2' \
  -derivedDataPath /tmp/lisa-watch-validation CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
```

La signature locale ne confirme pas les droits de production ni la disponibilité du conteneur iCloud. L'activation Apple et les essais entre appareils physiques restent les étapes externes décrites ci-dessus.


### Poulpi identique sur Watch

La demande complémentaire remplace le dessin SwiftUI simplifié par la scène 3D de l'iPhone. Les deux cibles compilent les mêmes `PoulpiRig`, `OctopusModel`, `LisaMascotMood` et ordonnanceur d'expressions. Le JSON de sculpture et la texture des yeux sont identiques octet pour octet dans les deux applications compilées. Les pigments sont mutualisés dans SudokuCore.

La Watch reçoit la couleur et l'accessoire dans le contexte WatchConnectivity existant, y compris lorsque seule l'apparence change. Les anciens contextes de version 1 restent lisibles. Les tests couvrent les 24 combinaisons de couleurs/accessoires, les anciens messages et les données invalides. La réception ignore les contextes obsolètes, même au retour d'activation.

Le rendu watchOS utilise SceneView avec les mêmes matériaux, éclairages et expressions. Il suspend les actions et la tâche d'expressions hors écran, en arrière-plan, lors de l'assombrissement de l'écran et avec Réduire les animations. Aucun gain énergétique n'est déduit de ces contrôles.

Contrôle visuel : lancement sur Apple Watch Series 11 46 mm simulée, écran compagnon en français ; deux captures de la zone Poulpi diffèrent sur 40 146 pixels, ce qui confirme un rendu animé sur ce simulateur. La capture est `/tmp/lisa-watch-poulpi-final-fr.png`. Cela ne valide ni les performances sur montre physique ni le transport WatchConnectivity entre deux appareils réels.

Les tests UI qui relancent l’application sans effacer la sauvegarde transmettent désormais `LISA_UI_TESTING=1`. Cela évite la connexion Game Center automatique et le rafraîchissement social sur les installations de test, tout en préservant les contrôles de persistance. Le comportement des installations normales est inchangé.

### Bilan local final

- `swift test --disable-sandbox` : 100 tests SudokuCore et 12 tests LisaInvitations réussis, dont les quatre nouveaux tests de contexte Watch.
- AppTests : 84 tests réussis, dont conservation du solo/notes/annulation avant Battle et refus d’écraser une sauvegarde illisible.
- Compilations iPhone et Watch réussies ; lancement et animation du vrai Poulpi vérifiés sur simulateur Watch. Les ressources de sculpture et des yeux des deux bundles ont été comparées.
- Les tests UI couvrent notamment l’ouverture/fermeture des invitations sans changement de grille, les grands caractères, les rotations, Battle local, les cinq langues et la récupération des sauvegardes. Les helpers de défilement attendent que le centre du bouton soit dans la zone visible ; les classes concernées réinitialisent l’orientation au début de chaque test pour éviter de propager un échec en paysage.
- Un crash SceneKit des paupières est survenu pendant le premier passage du mode d’inspection. Le même test a réussi lors de sa relance isolée, sans modification du modèle. Cela reste une observation de simulateur, pas une garantie de stabilité physique.
- Vérification des traductions et `git diff --check` réussies. Aucun commit, push, profil de distribution ni publication TestFlight effectué.

Résultat UI consolidé après corrections et relances ciblées : **46 tests réussis**, **1 ignoré** (le test de viewport élargi nécessite un écran plus grand que les iPhone de validation). Le test des 18 animations du compagnon réussit en 92,702 s ; la borne d’attente du retour au repos est passée de 10 à 20 s après observation d’un réveil différé du simulateur lors des captures, sans modifier les durées des animations.

Preuves locales principales : `/tmp/lisa-swift-completion.log`, `/tmp/lisa-invitations-final.log`, `/tmp/lisa-final-inbox-layout.log`, `/tmp/lisa-completion-a.log`, `/tmp/lisa-completion-b.log`, `/tmp/lisa-inspection-recheck.log`, `/tmp/lisa-poulpi-controls-recheck.log`, `/tmp/lisa-portrait-recheck.log`, `/tmp/lisa-last-two-debug.log`, `/tmp/lisa-companion-final.log`. Les premiers journaux contiennent les échecs ensuite corrigés ; les réussites de relance remplacent ces résultats dans le décompte, sans présenter un passage unique de toute la suite comme réussi. Les traces temporaires ajoutées pour le diagnostic ont été retirées avant le dernier build/test.
