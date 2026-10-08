# Fiche App Store multilingue — préparation du 7 octobre 2026

## État exact

L'app et la fiche App Store Connect disposent désormais des cinq langues : français, anglais (États-Unis), allemand, espagnol (Espagne) et russe. Le 7 octobre 2026, les quatre nouvelles fiches ont été enregistrées dans la session Chrome connectée : noms, sous-titres, textes promotionnels, descriptions et mots-clés. Les six captures natives de chaque langue ont été chargées dans l'ordre 01 à 06 (6/10 dans chaque fiche), ainsi qu'un visuel de recherche commun sans texte français (1/1 dans chaque fiche). Aucune soumission à l'examen ni publication effectuée.

| Langue ASC | Copie | Dossier des images | Mots-clés UTF-8 |
| --- | --- | --- | --- |
| Français | fr-FR.json | fr-FR/ | 93 / 100 octets |
| Anglais (États-Unis) | en-US.json | en-US/ | 66 / 100 octets |
| Allemand | de-DE.json | de-DE/ | 84 / 100 octets |
| Espagnol (Espagne) | es-ES.json | es-ES/ | 80 / 100 octets |
| Russe | ru.json | ru/ | 91 / 100 octets |

Le nom français reste **Lisa Sudoku**. Apple ayant refusé ce nom comme déjà utilisé dans les quatre nouvelles langues, le titulaire a délégué le choix d'une variante : **Lisa Sudoku – Poulpi**, acceptée et enregistrée dans les quatre fiches étrangères. Les sous-titres, textes promotionnels, descriptions et mots-clés sont adaptés à chaque langue. Anglais US choisi pour la localisation marketing anglaise ; cela ne change pas les langues du binaire.

## Emplacement des champs dans Apple

- **Informations sur l'app** : nom et sous-titre localisés. La catégorie est commune à l'app ; sa traduction dans les fichiers est documentaire.
- **Version iOS 1.0** : texte promotionnel, description, mots-clés et captures propres à chaque langue.
- **Copyright et notes d'examen** : champs communs, ne pas les écraser successivement avec les quatre traductions. Les notes traduites sont une copie de référence, pas quatre champs indépendants.
- **Assistance et confidentialité** : URLs publiques encore à fournir ; ne pas saisir des chemins locaux.
- Ajouter une langue dans la version ne suffit pas : Apple reprend certains éléments de la langue principale. Vérifier le sous-titre et remplacer les captures françaises héritées.

## Images

Ordre par langue : `01-partie.png`, `02-accueil.png`, `03-indice.png`, `04-tutoriel.png`, `05-voyage.png`, `06-poulpi.png`. Les nouvelles images sont capturées dans la véritable interface localisée, au format natif 1179 × 2556, RGB sans alpha. Aucun agrandissement des captures de gameplay.

L'en-tête `07-entete.png` reprend l'illustration existante de Poulpi et des chiffres, sans mots français. La nouvelle recherche `08-recherche.png` est une illustration promotionnelle commune avec uniquement le titre « Lisa Sudoku », Poulpi et trois tuiles numériques : aucune fausse capture d'écran. Imagegen l'a produite à 1536 × 1024 ; adaptation technique à 1920 × 1280, sans revendication de détail natif supplémentaire. Source conservée dans `shared/08-recherche-source.png`. La recherche française existante n'a pas été écrasée.

Dans App Store Connect, les quatre langues héritent de l'en-tête français sans mots français et de la capture iMessage existante (`Utilisation des ressources existantes`). Les copies locales Messages ne sont pas présentées comme de nouveaux parcours dans chaque langue. Les stickers et le libellé iMessage sont identiques. Les quatre fichiers de recherche locaux sont identiques ; le même PNG a été chargé dans chacune des quatre fiches.

## Validation

```sh
python3 scripts/localization/check_store.py
python3 scripts/localization/check_store.py --images
```

Le validateur utilise Python et Pillow. Les fichiers français historiques sont RGBA avec un canal alpha entièrement opaque ; les nouvelles captures sont RGB. Le contrôle porte sur les limites de texte, les **100 octets** de mots-clés, les six captures natives opaques par langue et leurs dimensions. Il ne prouve pas l'enregistrement distant. La relecture linguistique humaine par des locuteurs natifs reste utile avant lancement.

Validation exécutée le 7 octobre 2026 : **4 tests UI réussis, 0 échec, 244,178 secondes** sur iPhone 16 / iOS 18.5. Les 24 nouvelles captures ont été produites en résolution native. Résultat : `/tmp/lisa-localized-store-20261007.xcresult`. Le validateur complet `--images` passe pour les cinq langues. Ces durées sont celles des tests et pauses de capture ; elles ne mesurent pas les performances du jeu.

Le [manifeste des captures](localized-capture-manifest.json) conserve dimensions, provenance et empreintes SHA-256. Reproduction sur un simulateur QA dédié (les tests réinitialisent les données de l’app sur ce simulateur) :

```sh
python3 scripts/localization/capture_store.py --udid <SIMULATEUR_QA>
```

## Autres champs à terminer

Vérification distante du 7 octobre 2026 après import : URL d'assistance et coordonnées d'examen vides ; URL de confidentialité absente et déclaration « aucune donnée collectée » toujours à publier ; aucun tarif ni pays configuré. Le build associé à la version reste 1.0 (4). La déclaration des droits et la sélection du build final restent aussi à terminer. Les choix de prix/pays et coordonnées ont été demandés au titulaire ; aucune réponse n'est présumée.

La vidéo d'aperçu, les événements et les pages produit personnalisées sont facultatifs. Les classements ne font pas partie du périmètre convenu. Les capacités d'accessibilité non éprouvées ne sont pas déclarées sur la seule présence de traductions.

Sources Apple : [localisation des informations](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information/), [champs de version et limites](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/), [captures et aperçus](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots).
