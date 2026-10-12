# Aides pendant une partie

Disponibles en Libre, Voyage et Quotidien. Le bouton Aides partage la rangée des outils. Il ouvre un panneau temporaire
indépendant : la grille et le clavier ne changent ni de taille ni de position.
Fermer le panneau permet de reprendre immédiatement la partie avec les surcouches.

- Candidats : calculés depuis les chiffres visibles et les éliminations validées,
  séparément des notes. Activer les notes manuelles masque cette couche.
- Focus chiffre : sélecteur indépendant du clavier de saisie. Les occurrences et
  notes correspondantes sont soulignées ; un contour fin repère les cases compatibles.
- Piste : contours pointillés des cellules d'une déduction. Aucun placement ni
  candidat à éliminer n'est affiché avant de demander une explication.
- Expliquer : transmet exactement la déduction affichée au parcours d'indice.
- Notes automatiques : action prioritaire en haut du panneau, complète toutes les
  cases vides sans annotations. Les notes existantes et les éliminations validées
  sont conservées. Un seul Annuler restaure l'ensemble, même après sauvegarde.
- Gérer les notes → Nettoyer les notes : retire uniquement les annotations devenues
  impossibles selon les chiffres visibles et les éliminations validées. Aucun
  ajout ni consultation de la solution ; analyse périmée ou contradictoire refusée.
- Gérer les notes → Effacer toutes les notes : réinitialise les annotations des
  cases vides sans toucher aux chiffres ni aux éliminations logiques.
- Nettoyer et Effacer sont atomiques et annulables. Une opération sans changement
  ne crée pas d'entrée d'historique. Les trois actions ferment le panneau et
  désactivent Candidats en direct pour rendre les notes réellement modifiées visibles.
- Masquer les aides : retire les trois surcouches. Fermer la palette les conserve.
  Une nouvelle partie ou une réouverture les désactive.

`AssistanceSnapshot` n'accepte ni solution ni notes personnelles. L'exécuteur série
partagé avec les indices travaille hors du thread principal ; annulation coopérative
et délai de deux secondes protègent les demandes. Les résultats sont vérifiés contre
l'identifiant de partie, les valeurs et les éliminations. Le chronomètre et les notes
ne déclenchent pas de nouvelle analyse. Pause, arrière-plan, présentation d'un indice
ou sortie de l'écran suspendent l'analyse.

`usedLogicalAssistance` devient vrai lorsqu'une piste est affichée et reste vrai
après annulation ou masquage. Les anciennes sauvegardes et anciennes entrées d'historique
valent faux. La soumission Game Center refuse une partie aidée. Candidats, Focus et
Remplir n'incrémentent pas les indices ; Expliquer conserve leur comptage habituel.
Les récompenses solo restent inchangées.

Tests ajoutés : `AssistanceTests`, `LogicalAssistanceTests`, `AssistanceUITests`.
Les tests UI utilisent exclusivement le simulateur dédié « Lisa Assistance QA ».

## Validation du 11 octobre 2026

- `swift test` : 115 tests SudokuCore et 12 tests LisaInvitations réussis.
  Après l'ajout du cas d'élimination et des points d'annulation, les six tests
  `AssistanceTests` ont également été relancés avec succès.
- iOS : 110 tests applicatifs réussis ; dernière passe ciblée de 33 tests réussie,
  incluant l'isolation de l'usage d'aide entre les sauvegardes Libre et Voyage.
- Trois scénarios UI réussis sur iPhone SE / iOS 18.2 : notes et couches combinées,
  texte d'accessibilité, puis focus conservé en paysage et aides réinitialisées
  après retour à l'accueil et réouverture. Les trois scénarios passent dans la
  même exécution après ajustement des gestes de défilement du test.
- Localisation : 734 clés partagées complètes dans les cinq langues ; tous les
  appels littéraux `L10n.text` disposent d'une traduction.
- `git diff --check` sans erreur.

La commande iOS avec `CODE_SIGNING_ALLOWED=NO` compile, mais CloudKit arrête
l'application faute d'entitlements au lancement. Les tests exécutés utilisent
`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-` (signature locale de simulateur),
avec `-collect-test-diagnostics never` pour éviter un blocage de finalisation Xcode.
Le test existant de démarrages rapides attend désormais `flushPendingSaves()` avant
que son nettoyage ne supprime le dossier de sauvegarde : une course de nettoyage
avait fait échouer une passe. Les 33 tests applicatifs concernés ont ensuite
terminé avec `TEST SUCCEEDED`.
DerivedData, journaux et résultats sont dans `/tmp/lisa-assistance-validation`
et `/tmp/lisa-assistance-*.log`. Aucun essai sur iPhone physique ni mesure batterie.

## Reprise de l'intégration du 12 octobre 2026

La palette intégrée au défilement a été remplacée par un panneau temporaire.
Aides occupe la rangée d'outils existante, avec l'état actif en jaune et un contour.
Le panneau utilise la typographie et les couleurs Lisa ; sa fermeture conserve les
couches, et Expliquer ou Remplir ramènent directement au jeu. Les animations du
décor sont suspendues pendant sa présentation.

Le format compact réserve la place du clavier complet. Les quatre tests
`AssistanceUITests` passent sur iPhone SE, dont la vérification exacte des positions
de la grille et du clavier après ouverture/fermeture, et la présence intégrale de
la touche 9 dans l'écran. Texte d'accessibilité, paysage, notes, annulation et
explication restent couverts. `swift test` : 116 tests moteur et 12 invitations
réussis. Localisation (cinq langues) et `git diff --check` valides.
Résultats : `/tmp/lisa-assistance-validation/Logs/Test/Test-SudokuLisa-2026.10.12_09-48-47-+0200.xcresult`.
Captures : `/tmp/lisa-aides-grille-corrigee.png` et `/tmp/lisa-aides-panneau-corrige.png`.

## Outils de notes — 12 octobre 2026

Notes automatiques est désormais la première action du panneau. Nettoyer et
Effacer sont regroupés dans « Gérer les notes » ; Candidats en direct identifie
explicitement la couche actualisée après les coups. Les huit nouveaux libellés
sont disponibles dans les cinq langues (742 clés partagées).

Validation : 120 tests moteur et 12 invitations réussis. Les quatre scénarios UI
existants passent ; le nouveau scénario remplissage → nettoyage → annulation →
effacement → annulation passe aussi après correction d'un identifiant
accessibilité de groupe qui masquait ceux de ses boutons enfants.
Dernier résultat : `/tmp/lisa-assistance-validation/Logs/Test/Test-SudokuLisa-2026.10.12_10-03-00-+0200.xcresult`.
Capture : `/tmp/lisa-notes-automatiques.png`. Tests sur simulateur dédié uniquement.
