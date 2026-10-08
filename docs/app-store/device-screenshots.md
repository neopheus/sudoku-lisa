# Captures par appareil — 7 octobre 2026

## Constat distant

Le gestionnaire App Store Connect présente six captures iPhone Dynamic Island moyen. Les grands iPhone réutilisent ces ressources : leur compteur « 0 sur 10 » désigne les captures spécifiques, pas une absence totale de visuels. Les emplacements Duo et iPad 13 pouces étaient vides.

## Capture Duo

Les cinq lots sont chargés et acceptés dans App Store Connect : français, anglais (États-Unis), allemand, espagnol (Espagne), russe. Chaque rubrique Duo affiche **6 sur 10 captures**, dans l’ordre 01 à 06. Preuve française : `duo-upload-fr.png`. Aucune soumission à la vérification ni publication.

Les 30 PNG ont été vérifiés (dimensions, RGB, intégrité) ; leurs empreintes sont dans `iphone-duo-open/manifest.json`. Le journal `/tmp/lisa-localized-store-20261007-163342.log` confirme cinq tests réussis, zéro échec, 410,915 secondes. Xcode est resté bloqué après la fin des tests, avec des diagnostics `invalidDigitCount` du runtime 27.1 et `Resolve Package Graph` ; le processus a été arrêté. Le `.xcresult` associé n’est donc pas présenté comme finalisé. Cela ne valide pas toutes les postures du Duo ni le comportement sur appareil physique.

Simulateur dédié `Lisa Store Duo QA`, UDID `CC536CC1-4631-43BC-8EF8-34FE116E00E9`, iOS 27.1 / Xcode 27.1. Appareil ouvert via Device Hub ; écran 3, résolution native paysage 2853 × 2007, PNG RGB sans redimensionnement. Parcours authentique : partie quotidienne, accueil, indice, leçon, Voyage, Poulpi.

Le parcours XCTest utilise les boutons de navigation sans imposer une barre inférieure, car le Duo présente une barre latérale. Le script accepte `--display` pour sélectionner l’écran actif. La capture par défaut du Duo fermé peut renvoyer son autre écran noir.

```sh
python3 scripts/localization/capture_store.py \
  --udid CC536CC1-4631-43BC-8EF8-34FE116E00E9 \
  --languages fr en de es ru --display 3 \
  --output docs/app-store/iphone-duo-open \
  --derived-data /tmp/lisa-store-duo-validation
```

## iPad et diagnostics

Le projet distribué cible uniquement la famille iPhone (`TARGETED_DEVICE_FAMILY=1`). Le simulateur iPad 13 pouces présente l’app dans une fenêtre iPhone avec de larges bordures noires. Le lot a été interrompu après confirmation visuelle ; ces captures ne sont pas destinées au chargement. Une véritable version iPad nécessite une décision produit, l’activation de la cible et sa validation.

Les essais iPad et Duo fermé sont conservés dans `device-diagnostics/`. La capture de partie Duo fermé montre des touches coupées en bas : le test de présence des éléments seul ne suffit pas à valider ce rendu. Aucun de ces diagnostics n’est une capture marketing approuvée.

Le contrôle du moteur `swift test` passe : 55 tests, zéro échec. Aucun changement de code de l’app, commit, archive ou déploiement n’est inclus dans cette préparation.
