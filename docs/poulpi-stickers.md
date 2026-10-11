# Autocollants Poulpi

Le module local `PoulpiStickers` contient le catalogue commun, les traductions FR/EN/DE/ES/RU et 24 illustrations statiques transparentes. L’app et l’extension Messages embarquent chacune son bundle de ressources. Les PNG servent à Messages et à la galerie ; les WebP servent au transfert WhatsApp.

## Utilisation et vérification sur iPhone

- Dans Lisa, ouvrir **Poulpi → Autocollants Poulpi**. Toucher une image pour l’agrandir et partager son PNG.
- Pour iMessage, ouvrir une conversation dans Messages, puis **+ → Autocollants → Lisa Stickers** (l’emplacement dépend de la version iOS). Le pack est aussi accessible depuis les autocollants du clavier emoji. Vérifier l’apparition des 24 images, puis leur insertion et leur envoi dans une conversation de test autorisée. Si l’extension manque, vérifier qu’elle est activée dans les réglages des apps iMessage. Dans le build 18 et les versions précédentes, chercher plutôt **+ → Plus → Lisa Stickers** : le contexte système Autocollants n’était pas déclaré.
- Pour WhatsApp installé, utiliser **Ajouter à WhatsApp** dans la galerie puis confirmer l’import dans WhatsApp. Vérifier ensuite le pack dans le sélecteur d’autocollants d’une conversation de test.
- Sans WhatsApp, Lisa explique que l’application doit être installée. Une ouverture de WhatsApp ne signifie pas que l’utilisateur a confirmé l’import.

L’import suit le [protocole officiel WhatsApp iOS](https://github.com/WhatsApp/stickers/blob/main/iOS/README.md) : un pack statique de 3 à 30 images WebP 512 × 512, moins de 100 Ko chacune, et une icône PNG 96 × 96 de moins de 50 Ko. Le transfert explicite utilise le presse-papiers local avec expiration après 60 secondes et le schéma `whatsapp://stickerPack`.

## Régénération des images

Après compilation et installation d’un build Debug sur un simulateur dédié :

```sh
python3 scripts/mascot/export_stickers.py --udid <UDID> --launch
```

L’exporteur Debug photographie le même modèle 3D que l’app dans 24 poses ; Pillow réencode les fichiers en PNG et WebP. Aucun rendu 3D ni encodage WebP n’est réalisé pendant l’usage ordinaire de la galerie. Le script contrôle les dimensions, l’alpha, les marges, les doublons et les poids. Recompiler ensuite pour embarquer les nouveaux fichiers.

## Validation automatisée

- `swift test` : moteur et sauvegardes.
- `python3 scripts/localization/check.py` : couverture des cinq langues.
- Tests iOS `LisaStoreTests/PoulpiStickerTests` : création des 24 `MSSticker` et ressources propres à l’extension embarquée.
- Tests iOS `LisaStoreTests/WhatsAppStickerTests` : contrat JSON, limites du protocole et pack construit à partir des vrais assets embarqués.
- Test `LisaUITests/BattleUITests/testPoulpiStickerGalleryAndWhatsAppUnavailable` : galerie, aperçu et absence de WhatsApp sur le simulateur dédié.

Les tests locaux ne prouvent pas l’envoi dans Messages ni l’acceptation du pack par WhatsApp sur un iPhone. Ces deux essais doivent être faits sur l’installation contenant cette version.

### Découverte dans le tiroir Autocollants — 11 octobre 2026

L’archive distribuée du build 18 contient l’extension et ses 24 PNG, mais ne déclare pas `MSSupportedPresentationContexts`. Ajout des contextes `MSMessagesAppPresentationContextMessages` et `MSMessagesAppPresentationContextMedia` à la racine du plist de l’extension, conformément à la [documentation Apple](https://developer.apple.com/documentation/messages/adding-sticker-packs-and-imessage-apps-to-the-system-stickers-app-messages-camera-and-facetime). Apple précise que déclarer les deux contextes place le pack dans le contexte média, notamment le tiroir Autocollants et le clavier emoji, plutôt que dans la liste des apps du bouton +.

Le test d’intégration vérifie cette déclaration dans l’extension réellement embarquée. La mention « Autocollants inclus : Non » d’App Store Connect ne constitue pas une vérification de l’affichage des `MSSticker` créés par le code ; aucune modification de cette mention ni disponibilité du correctif dans le build 18 n’est revendiquée.

Validation locale : 116 tests moteur/invitations et 7 tests d’intégration autocollants réussis, dont la création des 24 `MSSticker` et le contrôle des contextes dans l’extension compilée. La première exécution sans signature échoue au lancement du conteneur CloudKit de l’app hôte ; la relance sur le simulateur dédié avec `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-` réussit (`/tmp/lisa-stickers-context-signed-tests.log`). Présence dans le tiroir et insertion sur iPhone encore à vérifier ; correctif non déployé.

### Contrôles du 8 octobre 2026

Sur le simulateur dédié Lisa Gameplay QA (iOS 18.5) : les 7 tests d’intégration stickers passent ; le parcours galerie/aperçu/WhatsApp absent passe. Les scénarios Battle et Poulpi fixe passent également après adaptation du défilement dans le test de récompense. Les 69 tests `swift test` et la couverture des cinq langues passent.

Les 24 PNG ont des pixels distincts ; ils mesurent au plus 112 276 octets et les WebP au plus 19 498 octets. L’icône de pack mesure 8 342 octets. Les visuels ont un fond transparent et une marge minimale de 30 pixels. Le chargement `MSSticker` est vérifié, mais la panne iMessage signalée n’a pas encore été reproduite sur le téléphone de l’utilisateur ; l’envoi réel et l’import WhatsApp restent à confirmer sur iPhone. Ces modifications sont livrées dans le build TestFlight 9 ; elles ne figurent pas dans le build 8.

Le dernier test isolé de défilement est déclaré réussi dans son journal (30,586 s). La finalisation de son rapport Xcode est restée bloquée après l’erreur d’environnement `invalidDigitCount(94232)` ; le processus a été arrêté après attente. Les rapports des sept tests d’intégration et de la relance galerie/Battle précédente sont finalisés avec `TEST SUCCEEDED`.

La compilation Release pour iPhone réussit (`CODE_SIGNING_ALLOWED=NO`). Le bundle final de l’app et celui de l’extension contiennent chacun les 24 PNG, les 24 WebP et l’icône du pack. Ce contrôle n’est ni une archive signée ni un déploiement TestFlight.
