# Sauvegardes, Battle et inspection Poulpi — 10 octobre 2026

## Comportement livré

- Chaque écriture de progression valide le nouveau contenu et l'ancien fichier avant remplacement. Une seule copie `.backup` conserve la version précédente lisible. Une corruption détectée ferme l'enregistrement et ouvre la récupération.
- Le panneau de récupération permet de relire, d'exporter les octets originaux ou de restaurer une copie de secours lisible. La restauration exige une action explicite et conserve d'abord l'original dans un fichier séparé. Sans copie lisible, aucune réinitialisation automatique. Les copies d'originaux conservées après restauration ne sont pas supprimées automatiquement.
- Battle utilise le même chemin de réception en production et dans les tests, avec transport et horloge injectables. Le retour d'arrière-plan au salon rétablit le statut connecté ; le joueur doit se déclarer prêt à nouveau.
- Le lancement Debug `--poulpi-inspection-sequence` présente toutes les expressions sous trois angles, aux tailles 280 et 72 points. Pause, ralenti, précédent/suivant et replay utilisent le rendu réel. La séquence s'arrête en arrière-plan et respecte Réduire les animations. Les commandes du laboratoire dans la rubrique Poulpi restent disponibles.

## Vérification reproductible

Moteur et traductions :

```sh
swift test
python3 scripts/localization/check.py
```

Dans un environnement qui interdit les caches utilisateur et le sandbox imbriqué de SwiftPM :

```sh
CLANG_MODULE_CACHE_PATH=/tmp/lisa-quality-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/lisa-quality-module-cache \
swift test --disable-sandbox --scratch-path /tmp/lisa-quality-core
```

Tests iOS, sur un simulateur **dédié** : les scénarios UI utilisent `--uitest-reset` et effacent sa progression de test.

```sh
xcodebuild -project SudokuLisa.xcodeproj -scheme SudokuLisa \
  -destination 'platform=iOS Simulator,id=<UDID-DE-TEST>' \
  -derivedDataPath /tmp/lisa-validation CODE_SIGNING_ALLOWED=NO test
```

Après installation de la version Debug, lancement de l'inspection sans effacement des sauvegardes :

```sh
xcrun simctl launch <UDID-DE-TEST> com.xavier.sudokulisa --poulpi-inspection-sequence
xcrun simctl io <UDID-DE-TEST> recordVideo /tmp/lisa-poulpi-inspection.mov
```

Arrêter l'enregistrement avec Ctrl-C à la fin. Inspecter le clignement entier, les pupilles aux extrêmes du regard, la fermeture des paupières sans traversée, les changements d'expression et les deux tailles. Répéter sur iPhone : une capture fixe et un test de couverture des poses ne prouvent pas la qualité des transitions.

Pour Battle, compléter les tests déterministes par un duel Game Center sur deux appareils : salon → arrière-plan → retour → prêt, interruption pendant le décompte, coupure brève puis longue en partie, fin simultanée et revanche. Vérifier séparément que la partie solo, les notes et les annulations sont conservées.

## Limites de validation

Résultats du 10 octobre : 80 tests moteur réussis, zéro échec ; contrôle des traductions réussi dans les cinq langues. Les modules SudokuCore, PoulpiStickers et SudokuLisa sont compilés en modules Swift avec le SDK iOS Simulator 27.1 et une cible iOS 17. Toutes les sources AppTests et UITests passent également la vérification de types avec ce SDK et XCTest. Cette vérification directe ne construit pas un bundle installable et n'exécute pas les tests iOS. Le compilateur signale encore des avertissements de concurrence dans les intégrations SceneKit/GameKit et l'animation du lobby.

L'exécution des tests App/UI, l'enregistrement animé et le duel Game Center nécessitent des services Apple accessibles. Dans le sandbox de cette session, CoreSimulator/CoreDevice et le lancement Xcode des manifests SwiftPM sont bloqués. Aucune validation visuelle sur iPhone ni mesure de batterie/GPU n'est revendiquée. Les originaux conservés après restauration restent sur disque après redémarrage ; leur bouton d'export est disponible pendant la session de récupération, sans catalogue des anciennes copies après relancement.
