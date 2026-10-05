# Mascotte poulpe

La mascotte est un modèle 3D procédural rendu avec SceneKit, un framework Apple. Les mouvements sont interpolés en temps réel : aucune planche de sprites, vidéo ou succession de PNG n’est utilisée dans le jeu. Le même modèle sert à produire les icônes et les quatre stickers statiques iMessage.

Les expressions couvrent l’accueil, la réflexion, les encouragements, la pause et la victoire. Pendant la partie, les réactions suivent les saisies et les indices réels ; en mode zen sans vérification, elles ne dévoilent pas la solution. Réduire les animations fige les mouvements. Les vues transmettent un état de visibilité pour suspendre le rendu animé sous les feuilles, alertes et autres onglets.

## Régénérer les ressources

Installer une compilation **Debug à jour** sur un simulateur QA déjà démarré. Utiliser son UDID explicite, jamais l’installation contenant la progression personnelle. Depuis la racine :

```sh
python3 scripts/export_octopus_assets.py <QA_SIMULATOR_UDID>
```

Le script relance cette installation avec `--export-octopus-assets`. L’exporteur Debug écrit dans `Documents/OctopusAssets` du conteneur. Le script attend un export neuf et complet, contrôle les dimensions et canaux alpha, puis copie les PNG sans conversion vers les catalogues existants. Il ne compile et n’installe rien ; une nouvelle compilation est nécessaire après la copie.

- Icône principale : 1 024 × 1 024, opaque.
- Icônes iMessage : dimensions des noms de fichiers du catalogue, opaques.
- Stickers : 408 × 408, transparents.

Contrôler visuellement l’icône, les quatre expressions et les plus petits formats iMessage avant distribution. Le script vérifie le format, pas la qualité visuelle. Les mesures de fluidité et d’énergie doivent être effectuées sur iPhone physique ; une cible de fréquence ne constitue pas une mesure.

`generate_artwork.swift` et `generate_message_icons.swift` sont des générateurs **historiques de l’ancienne mascotte**. Ils ne doivent plus être exécutés sur les ressources actuelles ; un verrou explicite empêche leur lancement accidentel.

## Validation locale du 5 octobre 2026

- Rendu vivant vérifié dans l’accueil, thèmes Soleil et Nuit ; correction des surfaces SceneKit de dimensions fractionnaires par arrondi en points entiers.
- Bundle Release arm64 avec extension : **4 397 095 octets (4,40 Mo)**. Taille de distribution App Store à confirmer après signature.
- Les deux tests UI passent sur iPhone SE iOS 18.2 et iPhone 16 iOS 18.5 : 4 exécutions sans échec. Les processus Xcode sont restés bloqués à la clôture des rapports après les messages `All tests passed` ; arrêtés ensuite. Les journaux font foi, pas un `.xcresult` finalisé.
- Journaux : `/tmp/lisa-octopus-se-retry.log`, `/tmp/lisa-octopus-16-retry.log`. Vidéo réelle : `/tmp/lisa-octopus-animation.mp4`.
- Réduction des animations et suspension relues dans le code ; mesure de performance et d’énergie sur appareil physique encore à faire.
- Ancienne archive TestFlight antérieure à cette mascotte : reconstruire avant tout envoi. Aucune nouvelle version publiée.
