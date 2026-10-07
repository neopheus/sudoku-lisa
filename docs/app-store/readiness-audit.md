# Préparation App Store — audit du dépôt

Audit du 7 octobre 2026, en lecture seule des sources, ressources, scripts et documentation. Ce document décrit le dépôt ; il ne certifie ni les réglages App Store Connect, ni le binaire distribué, ni les droits sur les ressources. Aucun contrôle réseau ou navigateur effectué dans cet audit.

## Confidentialité et transmission

| Sujet | Constat | Preuve |
| --- | --- | --- |
| Collecte par le développeur | Aucun backend, client HTTP, analytics, SDK publicitaire ou suivi identifié dans App, Sources et Stickers. Le manifeste déclare absence de tracking et de données collectées. | `App/PrivacyInfo.xcprivacy:4-6` ; recherche des imports et API réseau dans les trois dossiers |
| Progression | Parties, notes, réglages, historique, dates de défis et récompenses sont enregistrés localement. | `App/Models/LisaStore.swift:62-73`, `138-139` ; `Sources/SudokuCore/SnapshotWriter.swift:12-15` |
| Langue | Préférence locale dans UserDefaults. | `Sources/SudokuCore/Localization.swift:7-12` |
| Partage | La feuille de partage iOS reçoit volontairement un texte avec difficulté et durée de la partie. Pas de serveur de partage propre à l’app identifié. | `App/Views/GameView.swift:562-563` |
| Messages | Quatre stickers embarqués ; Messages gère leur envoi. Le code inspecté ne lit pas les conversations. | `Stickers/MessagesViewController.swift:4`, `26-34` |
| Game Center | Code présent, mais les opérations restent désactivées sans LisaLeaderboardID, absent du plist inspecté. Une activation future ajouterait authentification Apple, nom affiché et envoi d’un score associé au joueur. | `App/Models/GameCenterService.swift:16-25`, `28-40`, `70-71` ; `App/Info.plist` |

L’absence de collecte est une conclusion sur les sources et la configuration actuelles. Elle n’a pas été vérifiée par observation réseau du build distribué. Le partage et Messages transmettent le contenu choisi par l’utilisateur aux services qu’il sélectionne ; ils ne doivent pas être décrits comme une collecte automatique par le développeur.

### Point à corriger pour le prochain build

`App/PrivacyInfo.xcprivacy:7` déclare un tableau NSPrivacyAccessedAPITypes vide, alors que l’app emploie UserDefaults (`Sources/SudokuCore/Localization.swift:11` et les vues avec AppStorage). Revoir le manifeste des API à motif requis, déclarer UserDefaults avec le motif correspondant à l’usage réel et vérifier aussi les manifestes des cibles/package concernés avant le prochain envoi. Cet audit n’a pas choisi de code de motif ni modifié le manifeste. Cette déclaration d’API est distincte de la déclaration de collecte de données dans ASC.

## Fonctionnalités à déclarer

| Champ | Constat et preuve |
| --- | --- |
| SDK tiers | Aucun identifié. Imports Apple et SudokuCore uniquement ; `Package.swift:3-8` ne contient aucune dépendance externe. Xcode référence le package local : `SudokuLisa.xcodeproj/project.pbxproj:257-258`. |
| Publicité et achat intégré | Aucun StoreKit, produit d’achat, AdSupport, ATT ou SDK de publicité identifié. L’interface affiche « Aucune publicité, aucun compte » (`App/Views/CollectionViews.swift:338`). Documentation : `docs/testflight.md:21`. Les objets éventuellement configurés dans ASC n’ont pas été inspectés ici. |
| Compte utilisateur | Aucun compte propre au jeu requis. Game Center demeure une intégration facultative actuellement non configurée. |
| Contenu lié à l’âge | Sudoku, apprentissage logique, mascotte animée, sons/musique, récompenses et stickers sourire/cœur/bravo/zen (`Stickers/MessagesViewController.swift:26-30`). Aucun contenu violent, sexuel, drogues/alcool, jeux d’argent, navigation web, messagerie libre, contenu créé par les utilisateurs ou conseil médical identifié. Les récompenses du jeu ne constituent pas des mises d’argent. La catégorie Enfants et la classification d’âge restent des décisions distinctes à vérifier dans ASC. |
| Langues | Français, anglais, russe, allemand et espagnol (`App/Info.plist:5`, `Sources/SudokuCore/Localization.swift:5`), avec ressources correspondantes de l’app, du moteur et des stickers. Validation UI antérieure des cinq langues documentée dans `docs/localization.md:30-32`, non relancée pour cet audit. |
| Plateformes | App iPhone, iOS 17 minimum ; Mac Catalyst désactivé (`SudokuLisa.xcodeproj/project.pbxproj:360`, `401-403`). Extension Messages. Le support macOS du package moteur (`Package.swift:6`) ne signifie pas qu’une app Mac existe. Distribution sur Mac Apple Silicon et Apple Vision : vérifier dans ASC. |
| Chiffrement | Le plist déclare ITSAppUsesNonExemptEncryption à false (`App/Info.plist:20`). Pas de bibliothèque cryptographique propre identifiée. |
| Assistance et confidentialité | Aucune URL publique d’assistance ou de politique de confidentialité identifiée dans le dépôt. Le manifeste xcprivacy n’est pas une page publique. |

## Provenance des ressources et limites de preuve

- **Sons et musique** : neuf WAV générés par `scripts/generate_audio.py`. Le script synthétise les formes d’onde par calcul, sans charger de samples ou de fichier musical externe (`scripts/generate_audio.py:20-32`, `35-54`). `docs/ambiance.md:19` les décrit comme originaux, sans banque de sons ni dépendance tierce. Le code permet de constater une synthèse locale ; il ne constitue pas à lui seul un document de titularité ou une licence.
- **Mascotte, icônes et stickers** : maillage construit localement et rendu avec SceneKit. Le workflow d’export dérive l’icône et les quatre stickers du modèle de l’app (`docs/octopus-mascot.md:3`, `36-38` ; `scripts/export_octopus_assets.py:57-64`, `69-82`). Cette traçabilité technique ne prouve pas les droits sur toutes les sources visuelles.
- **Références visuelles** : `docs/mascot-hd/README.md:9` décrit une référence HD générée à partir de quatre poses fournies. Le modèle est inspiré de cette référence (`docs/mascot-hd/README.md:22`). Aucun justificatif d’origine, licence, cession ou autorisation des poses fournies n’a été identifié dans le dépôt inspecté.
- **Image réellement embarquée** : `App/Resources/Mascot/poulpi-eye-reference.png` est chargée par `App/Design/PoulpiRig.swift:84-88` et utilisée pour le pigment des iris et de la bouche (`329`, `390`). Le fait que la mascotte soit 3D ne signifie donc pas que toutes les images de référence sont absentes du build.
- **Captures App Store** : `docs/app-store/fr-FR/01-partie.png` à `06-poulpi.png` sont des captures natives de l’application actuelle sur simulateur QA iPhone 16, 1179 × 2556, sans reconstruction d’interface ni rééchantillonnage. Validation du parcours : `/tmp/lisa-store-20261007-capture5.xcresult`, un test passé, zéro échec. Elles documentent l’interface ; elles ne prouvent pas les droits sur les éléments affichés.

**Conclusion sur le contenu tiers** : aucun SDK tiers ni banque de sons externe identifié ; provenance locale de nombreux éléments documentée. On ne peut pas affirmer juridiquement « aucun contenu tiers » ou « tous les droits sont acquis » à partir de ces seules preuves. Confirmer les droits sur les poses/références fournies et les conditions applicables aux ressources générées avant de certifier les droits dans ASC. Aucun droit n’est déduit du seul fait qu’un fichier a été généré.

## État App Store Connect — vérification du 7 octobre 2026

Complément par l’orchestrateur après inspection de l’interface App Store Connect, distinct de l’audit local ci-dessus.

| Élément | État ASC vérifié / preuve |
| --- | --- |
| Version, build sélectionné et disponibilité TestFlight | 1.0 (4) sélectionné ; TestFlight en cours de test, voir docs/testflight.md |
| Texte FR, mots-clés, sous-titre, catégorie | Enregistrés ; copie fr-FR.json ; Jeux / Casse-tête |
| Six captures FR chargées et traitées dans l’ordre voulu | 6/10, iPhone Dynamic Island écran moyen, ordre 01 à 06 confirmé |
| En-tête / visuel recherche | 1/1 chacun, chargés et contrôlés dans les aperçus Apple ; header-preview-fr.jpg et search-preview-fr.jpg |
| URL publique d’assistance | Vide ; demandée au titulaire ; page locale préparée |
| URL publique de politique de confidentialité | Vide ; demandée au titulaire ; page locale préparée |
| Questionnaire confidentialité / collecte | Aucune donnée collectée, enregistré en brouillon ; engagement juridique de publication en attente de confirmation |
| Questionnaire classification d’âge | Enregistré ; 4+ dans 172 pays/régions, équivalents régionaux affichés ; pas de catégorie Enfants |
| Déclaration des droits sur le contenu | À compléter après confirmation de provenance/droits |
| Coordonnées pour l’examen Apple | À compléter avec coordonnées confirmées |
| Prix, disponibilité et pays | Aucun tarif ni pays configuré ; choix demandé au titulaire |
| Disponibilité Mac Apple Silicon / Apple Vision | Options cochées dans ASC ; compatibilité réelle non testée, aucune certification ajoutée |
| Conformité chiffrement du build choisi | Déclaration plist false ; aucun document propriétaire à ajouter d’après le code inspecté |
| Accessibilité | Brouillon iPhone enregistré : Animations réduites. Publier désactivé tant qu’une version n’est pas disponible dans l’App Store. Voir accessibility.md et accessibility-asc-draft.jpg ; autres fonctions non déclarées faute de validation complète. |
| Localisations marketing | Français uniquement ; l’app prend en charge cinq langues, ce qui ne traduit pas automatiquement la fiche |
| Vidéo d’aperçu | Aucune ; facultative, à produire uniquement avec du gameplay réel |
| Captures iMessage | 09-imessage.png, capture réelle native 1179 × 2556 ; 1/10 chargé et traité dans App iMessage, quatre stickers visibles sans message envoyé |
| Game Center | Activé pour la version 1.0 conformément à la demande du titulaire ; case cochée et persistance vérifiée après rechargement le 7 octobre 2026. L’activation ASC reste distincte de la configuration des classements dans le build. |
| Soumission à l’examen / publication | Aucune soumission App Store ni publication de version effectuée ; statut À finaliser avant soumission |
