# Lisa Sudoku

Application iPhone native en français, SwiftUI et Swift, iOS 17 minimum. Interface adaptative en portrait et paysage, mascotte poulpe 3D procédurale animée en temps réel avec SceneKit et progression locale. Aucun SDK tiers ni serveur requis pour jouer.

L’interface utilise une ou deux colonnes selon la largeur disponible et conserve la partie au redimensionnement. La validation spécifique aux écrans et aux postures de l’iPhone Duo nécessite Xcode 27.1 et son runtime iOS 27.1 : voir [l’adaptation et les contrôles Duo](docs/iphone-duo.md).

## Développement

Ouvrir `SudokuLisa.xcodeproj` avec Xcode 16 ou ultérieur (développement réalisé avec Xcode 27 / Swift 6). Le moteur est un package Swift local nommé `SudokuCore`. Le projet synchronise automatiquement le dossier `App`, y compris ses nouveaux fichiers Swift et son catalogue de ressources.

```sh
python3 scripts/generate_project.py
swift test
xcodebuild -project SudokuLisa.xcodeproj -scheme SudokuLisa -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/sudoku-lisa-derived CODE_SIGNING_ALLOWED=NO build
```

Le générateur du projet ne nécessite ni XcodeGen ni dépendance Python. Il réécrit `project.pbxproj` : conserver les réglages pérennes dans `scripts/generate_project.py`.

Le schéma partagé `SudokuLisa` inclut les tests d’interface `LisaUITests`. Après avoir sélectionné un simulateur iPhone installé dans Xcode, utiliser **Product → Test**, ou remplacer `<SIMULATOR_UDID>` ci-dessous :

```sh
xcodebuild -project SudokuLisa.xcodeproj -scheme SudokuLisa -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' -derivedDataPath /tmp/sudoku-lisa-derived -resultBundlePath /tmp/LisaUITests.xcresult CODE_SIGNING_ALLOWED=NO test
```

Conserver DerivedData et les rapports `.xcresult` hors du dépôt : le package Swift local à la racine peut sinon surveiller ses propres fichiers de compilation et relancer la résolution en boucle. Choisir un nouveau chemin `.xcresult` à chaque exécution. Les tests couvrent saisie, notes, annulation, pause, reprise après redémarrage du processus, défi quotidien et réglage nuit. Leurs captures sont jointes au résultat Xcode. Ils lancent l’app avec `--uitest-reset` pour repartir d’une sauvegarde vierge ; ne pas les exécuter sur une installation contenant une progression à conserver.

Pour un véritable iPhone, choisir une équipe Apple dans **Signing & Capabilities** et remplacer si nécessaire l’identifiant provisoire `com.xavier.sudokulisa`. Aucune équipe de signature ni identité de distribution n’est incluse. La création du projet ne publie rien sur l’App Store.

## Fonctionnalités présentes

- Grilles classiques 9 × 9 générées sur l’appareil, avec unicité vérifiée ; six choix : Express, Facile, Moyen, Difficile, Expert et Maître.
- Saisie tactile, notes et retrait automatique des candidats après un chiffre correct, gomme, annulation illimitée avec historique compact.
- Indices : explication des candidats uniques et des chiffres uniques cachés, correction d’une erreur ou proposition d’une valeur vérifiée pour une étape avancée.
- Surlignage ligne/colonne/bloc et doublons, coloration facultative des erreurs, pause facultative après trois erreurs, chronomètre masquable, pause et reprise.
- Sauvegarde locale automatique d’une partie en cours, de ses notes, du chronomètre, des réglages et des résultats ; confirmation avant remplacement d’une partie.
- Défi quotidien déterministe et archives du calendrier, série calculée à partir des dates de défis résolus.
- Voyage individuel de 25 étapes réparties en cinq escales, événements locaux de 10 grilles par mois avec médailles, collection de badges, statistiques filtrables par difficulté et historique récent.
- Trois exercices d’apprentissage interactifs, partage textuel du résultat, sons et retours haptiques désactivables, thèmes Soleil/Nuit/Papier, mascotte et animations de victoire.
- Extension iMessage `LisaStickers` intégrée au projet, avec quatre stickers originaux. Ouvrir Messages sur un appareil de test pour vérifier la sélection et l’envoi ; la compilation de l’extension ne prouve pas cet échange.
- Libellés VoiceOver et prise en compte de Réduire les animations dans les animations personnalisées. Une validation sur appareil reste nécessaire.

Les données sont stockées dans le conteneur de l’application : supprimer l’application supprime sa progression. Une seule partie active est conservée. Il n’y a pas de synchronisation entre appareils.

## Ambiance et petites victoires

Sons originaux, musique douce facultative, décors animés, coucou interactif de Lisa, réussites intermédiaires et récompenses mises en scène : voir [les comportements et contrôles](docs/ambiance.md). La musique est désactivée par défaut ; les nouveaux réglages sont accessibles dans « À votre goût ».

## Écarts et limites

Les niveaux combinent densité initiale et sélection bornée parmi quatre grilles selon les techniques détectées (candidats uniques, positions uniques, candidats verrouillés, paires nues ou techniques avancées). Cela améliore la séparation des difficultés sans garantir six catégories strictement disjointes. Les indices avancés donnent une valeur vérifiée sans enseigner la technique complète. L’historique d’annulation enregistre uniquement les cases modifiées et migre les anciennes sauvegardes.

Le parcours « Voyage » est une progression individuelle locale permanente. Les événements saisonniers suivent le mois du calendrier local ; leur contenu déterministe fonctionne hors ligne. Ce ne sont pas des événements pilotés par serveur. Un trophée mensuel récompense la résolution de tous les défis quotidiens du mois, y compris via les archives. Aucun achat intégré n’est provisionné. L’identité, les illustrations et le code sont propres à Lisa Sudoku ; une parité intégrale avec Sudoku.com n’est pas revendiquée.

## Tournois et Game Center

Le code d’intégration Game Center est présent : connexion volontaire, affichage du classement natif et envoi d’un score. **Aucun classement de production n’est provisionné.** Sans clé `LisaLeaderboardID` dans `App/Info.plist`, les actions réseau du tournoi restent indisponibles ; aucun faux joueur ni classement simulé n’est affiché.

Pour activer l’intégration réelle, sélectionner l’équipe Apple et activer Game Center pour l’identifiant de l’app. L’entitlement figure dans `App/SudokuLisa.entitlements`. Configurer dans App Store Connect un classement récurrent hebdomadaire débutant le lundi à 00 h UTC, avec durée de sept jours, classement ascendant du temps en secondes et conservation du meilleur score. Inscrire son identifiant réel dans la clé `LisaLeaderboardID`, puis tester avec des comptes Game Center et soumettre les composants requis à Apple. La grille commune est déterministe pour la semaine UTC ; chaque erreur ajoute 60 secondes et la consultation d’un indice exclut la partie du classement.

Le service ne constitue pas un système serveur de validation anti-triche. Les comptes, droits Apple, authentification, publication des scores et frontière hebdomadaire doivent être validés sur appareil avant d’annoncer les tournois disponibles.

Références fonctionnelles : [fiche iPhone Sudoku.com](https://apps.apple.com/us/app/sudoku-com-number-games/id1193508329) et [présentation officielle Easybrain](https://easybrain.com/sudoku). La validation du moteur et les mesures locales ne remplacent pas les essais ergonomiques sur un vrai iPhone.

## Budget inférieur à 100 Mo

La limite du projet est **100 000 000 octets**. SwiftUI, la géométrie procédurale de la mascotte et l’absence de dépendances tierces limitent le poids. Le contrôle local accepte le chemin d’un bundle construit :

```sh
sh scripts/check_size.sh /tmp/sudoku-lisa-derived/Build/Products/Debug-iphonesimulator/SudokuLisa.app
```

Ce contrôle constitue uniquement un garde-fou sur le bundle local. **Une app simulateur, les sources, une archive Xcode ou une IPA d’envoi ne prouvent pas le poids App Store.** Pour confirmer l’objectif commercial, créer une archive Release signée, l’exporter avec l’amincissement pour toutes les variantes compatibles et vérifier le fichier `App Thinning Size Report.txt`. Contrôler séparément taille compressée de téléchargement et taille décompressée d’installation, puis confirmer dans App Store Connect. Le seuil doit être respecté pour chaque variante iPhone. [Méthode officielle Apple](https://developer.apple.com/documentation/Xcode/reducing-your-app-s-size).

## Distribution TestFlight

La mascotte utilise des mouvements 3D interpolés, sans animation image par image. Pour exporter les icônes et stickers à partir du même modèle, utiliser `python3 scripts/export_octopus_assets.py <QA_SIMULATOR_UDID>` après installation d’un Debug à jour. Voir [la mascotte et son workflow de ressources](docs/octopus-mascot.md). Les anciens générateurs de dessin sont verrouillés pour éviter d’écraser le poulpe.

La signature est configurée pour l’équipe `S2UPJPPKKG`. Les icônes iMessage nécessaires à la distribution sont incluses. Voir [la procédure et les textes de bêta](docs/testflight.md). L’export utilise `scripts/TestFlightExportOptions.plist` et envoie le build à App Store Connect ; la connexion Xcode et la fiche Apple doivent être prêtes.

## Avant distribution

- Exécuter les tests du moteur et une compilation Release iPhone.
- Tester reprise après fermeture, mode avion, indices, notes, victoire, calendrier et progression.
- Vérifier petits et grands écrans, VoiceOver, mode sombre et Réduire les animations sur appareil.
- Compléter signature, identité définitive, captures, fiche App Store et déclarations de confidentialité ; valider le rapport de taille signé.
- Pour de vrais classements, configurer les services Game Center dans App Store Connect et tester les comptes et scores réels avant de les annoncer. [Configuration Apple](https://developer.apple.com/help/app-store-connect/configure-game-center/manage-leaderboards/).

## Résultat vérifié

Référence historique du 5 octobre 2026, avant la mascotte 3D : **19 tests moteur et 4 exécutions de tests UI réussis**, sur simulateurs iPhone SE et iPhone 16. Le bundle initial de **2,53 Mo** n’est pas une mesure de la version actuelle. [Rapport et captures historiques](docs/validation.md). Refaire les contrôles de taille et d’interface après toute régénération des ressources.

Avec une équipe personnelle Apple non payante, il peut être nécessaire de retirer la capacité Game Center pour tester le jeu hors ligne sur son iPhone ; les tournois restent alors indisponibles. La configuration et la signature concernent aussi la cible LisaStickers.
