> Révision visuelle et musicale après retour utilisateur : voir [direction artistique v2](art-direction-v2.md). Les descriptions ci-dessous des anciens décors vectoriels et boucles synthétiques sont historiques.

# Escales — implementation and validation

Scope: 25 scenery stops for Voyage and Libre only; existing puzzles, difficulty profiles, rewards and controls retained.

Decisions:
- Work in the existing dirty checkout and preserve prior edits; no commit requested.
- Bundle five original, reproducible synthesized compositions without external samples. Source and provenance accompany the audio; listening on a physical device remains necessary.
- Persist a stop ID per game plus a bounded shuffled free-play route. Consume a stop only after successful generation. Migration uses puzzle seed in Libre and stage in Voyage.
- Introductions are transient (never restored), skippable, bounded to 1.8 seconds. Reduced motion, paper mode and disabled decor bypass them. Lifecycle departure ends the introduction.

Résultats et limites documentés ci-dessous.

## Livraison

- Catalogue `SceneryWorld` / `SceneryStop` partagé, 25 identifiants stables et décors vectoriels composés en trois plans. Les éléments mobiles restent sur les marges ; la grille et la barre d'état sont opaques.
- Rotation Libre par sac mélangé de cinq univers et cinq compteurs bornés. Le prochain décor n'est consommé qu'après génération réussie ; l'aperçu est celui de la prochaine partie effective.
- Migration des parties anciennes depuis l'étape Voyage ou la graine Libre. Sauvegarde de l'escale, de la rotation, des notes et annulations ; les données invalides déclenchent la protection existante.
- Introduction de 1,8 seconde, bouton immédiat fixé dans la zone sûre, chronomètre bloqué jusqu'à sa fin. Reprise et arrière-plan ne rejouent pas l'introduction. Une fixture DEBUG peut suspendre uniquement sa fermeture automatique pour tester le bouton en paysage/grands caractères ; cette option exige `--uitest-reset`.
- Résultats immédiatement disponibles avec une brève réaction de Poulpi propre à l'univers, aperçu suivant et bouton Continuer fixé en bas. Aucune récompense n'est attribuée par la présentation.
- Cinq compositions synthétisées originales de 24 secondes, embarquées en PCM, sources et provenance dans `scripts/generate_world_music.py` et `docs/audio-music-credits.md`. Nouveaux réglages : musique désactivée, choix automatique ; anciens choix conservés. Fondu de 650 ms, deux lecteurs au maximum, même lecteur conservé dans un univers.
- FR, EN, DE, ES, RU : 28 nouveaux textes, catalogue complet.

## Ajustements constatés pendant la validation

- Le rendu générique `celebrating: true` écrasait l'humeur propre à l'univers : supprimé sur la fiche de résultats.
- Le bouton d'introduction a été placé dans `safeAreaInset` et le contenu est défilable pour les petits écrans et grandes tailles de texte.
- Des arrêts intermittents ont été observés dans `C3DMeshSourceGetCount` / `SCNMTLMorphDeformer` sous iOS 18.2. Les sources de géométrie des déformeurs sont désormais propres à chaque scène, avec les mêmes données de sommets, normales et indices. Test de non-partage observé rouge puis vert ; tests de rendu des yeux conservés. Le test vérifie aussi que les données du sculpt sont identiques. Le catalogue de géométries reste borné. La contrainte de topologie des morph targets est décrite dans la [documentation Apple](https://developer.apple.com/documentation/scenekit/scnmorpher/targets).
- La commande iOS non signée compile mais ne peut pas lancer l'app actuelle : l'initialisation CloudKit exige les entitlements. Les exécutions validantes utilisent `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-` (signature locale de simulateur, aucun envoi).
- Un commit externe `353c3e7` est apparu pendant ce travail et contient déjà certaines fondations d'escales. Aucun commit, push ou déploiement n'a été lancé par cette session.

## Limites

Aucun iPhone physique n'est connecté (`devicectl list devices` : simulateurs uniquement).
Les raccords musicaux à l'écoute, la fluidité et le comportement thermique sur iPhone
restent à vérifier. Les contrôles numériques (durée, niveaux sans écrêtage, lecture AVAudioPlayer)
ne constituent pas une validation musicale à l'écoute, ni une mesure d'autonomie.

## Vérification — 11 octobre 2026

- `swift test` : **116 tests réussis** (104 SudokuCore et 12 LisaInvitations), `/tmp/lisa-escales-engine-full.log`.
- Suite iOS hébergée : **100 tests réussis**, `TEST SUCCEEDED`, `/tmp/lisa-escales-unit-green.log`, résultat `/tmp/lisa-validation/Logs/Test/Test-SudokuLisa-2026.10.11_10-37-06-+0200.xcresult`.
- Scénarios UI avec animations actives : cinq univers en clair/sombre, portrait/paysage ; reprise ; décor statique/papier ; bouton de passage en paysage avec taille de texte maximale ; arrière-plan ; résultats, aperçu puis partie suivante. Les corrections de fixtures et du sélecteur d'accessibilité ont été vérifiées par la passe ciblée **3 tests UI + 1 test de planches réussis**, `TEST SUCCEEDED`, `/tmp/lisa-escales-final-focus.log`, résultat `/tmp/lisa-validation/Logs/Test/Test-SudokuLisa-2026.10.11_10-40-21-+0200.xcresult`. Les 20 captures des cinq univers de la passe animée sont dans `/tmp/lisa-escales-ui-proof`.
- Les 25 images sont distinctes en clair et en sombre (50 rendus contrôlés), puis les deux planches ont été inspectées : [clair](25-escales-light.png), [sombre](25-escales-dark.png).
- Les tests audio vérifient la conservation de l'identité du lecteur dans un univers, les changements rapides, le nombre de lecteurs sortants, l'interruption et l'arrière-plan pendant le fondu. Chaque boucle embarquée est décodable par AVAudioPlayer et dure 24 secondes. Niveau crête PCM 18000/32767, sans écrêtage.
- `python3 scripts/localization/check.py` : **674 clés complètes dans les cinq langues**, aucun appel littéral non traduit ; `git diff --check` réussi.
- Passe finale avec le véritable réglage système Réduire les animations activé : **4 tests UI réussis, 1 test ignoré volontairement** (inspection de l'introduction, qui est absente dans ce mode et a déjà réussi avec les animations actives), `TEST SUCCEEDED`, `/tmp/lisa-escales-reduced-final.log`. Résultat : `/tmp/lisa-validation/Logs/Test/Test-SudokuLisa-2026.10.11_10-41-44-+0200.xcresult`. Les 20 captures complètes de l'écran sont dans `/tmp/lisa-escales-final-screens` ; les captures paysage ont été relues, avec grille et clavier testés comme accessibles. Le réglage du simulateur dédié a été remis à son état initial (Réduire les animations activé).

Les résultats moteur, iOS unitaire, UI et matériels sont des preuves distinctes.
Aucune mesure de gain batterie/GPU n'est annoncée.
