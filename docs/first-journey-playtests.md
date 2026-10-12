# Première partie, Voyage et essais joueurs

## Périmètre

- L’accueil propose le Voyage directement, avec une première étape Express. Le choix libre des six niveaux reste accessible. Une partie en cours garde la priorité.
- L’accueil tente une reconnexion silencieuse à Game Center ; la feuille de connexion est réservée à une action sociale explicite. La réception effective des invitations reste à vérifier sur appareils réels.
- La reprise du Voyage conserve la grille, les notes, les annulations, le temps et le décor. Les anciennes premières étapes Facile déjà commencées restent inchangées.
- Chaque étape terminée ajoute son illustration au carnet. Les 25 illustrations existantes sont réutilisées, sans nouvelle ressource raster. Les anciennes sauvegardes obtiennent leurs souvenirs rétroactivement, à partir du nombre d’étapes terminées ; aucun nouveau droit n’est écrit dans la sauvegarde.
- L’étoile à la cinquième étape reste la récompense à équiper. Le parcours et le prochain objectif passent avant l’événement mensuel.
- Le carnet est consultable depuis Voyage et depuis une victoire. Les animations derrière le carnet sont suspendues.

## Mesure locale

Dans **Réglages → Bilan des essais**, le joueur peut consulter les compteurs, désactiver l’enregistrement, effacer le bilan ou préparer un fichier à partager volontairement. Aucun SDK, serveur ni envoi automatique n’est ajouté.

Le bilan est indépendant de la sauvegarde de jeu. Un fichier illisible est conservé et bloque uniquement les nouvelles mesures. Son effacement explicite ne modifie pas la progression.

Le fichier partagé contient : version du format, version/build de l’app au moment de l’export, durée d’observation, cohorte nouveau/joueur existant, état de l’enregistrement et compteurs par jour relatif. Il ne contient ni nom, identifiant d’appareil, identifiant de partie, grille, date absolue, compte, ni texte libre. Fenêtre bornée à 90 jours UTC. Une désactivation est signalée, même après réactivation, pour exclure les périodes incomplètes des calculs de retour.

Événements : activation de l’app, choix du premier Voyage, grille créée avec succès, reprise, première saisie manuelle observée sur une grille encore vierge, victoire, consultation/explication/application d’un indice, ouverture d’un souvenir. Une reprise après annulation de toutes les valeurs peut recompter une première saisie ; ce compteur ne sert pas à calculer un taux exact par grille. Les activations ne sont pas des sessions au sens marketing ; une reprise après interruption peut en ajouter une. Une ouverture du carnet sans ouverture d’une carte n’est pas comptée comme lecture d’un souvenir.

Limites : les compteurs ne permettent pas de reconstruire la première session, les abandons d’une grille précise, un parcours individuel ou la rétention de toute la population. Les retours J1/J7/J30 concernent des jours UTC depuis le début de l’observation, pas nécessairement depuis l’installation. Les joueurs existants sont séparés. Les exports volontaires créent un biais de sélection. La version exportée n’attribue pas chaque événement à une build en cas de mise à jour.

## Protocole conseillé

1. Observer 15–20 personnes extérieures au projet : leur demander de lancer une partie sans aide, puis observer choix, compréhension des commandes et recours aux indices. Recueillir séparément leur niveau habituel au Sudoku.
2. Leur laisser le choix d’activer/conserver le bilan local et de le partager ultérieurement. Demander ce qu’elles ont préféré, ce qui les a interrompues et ce qu’elles attendent du lendemain.
3. Après plus de 7 jours complets, réunir un dernier export par testeur. Ne pas stocker les rapports dans Git ; les conserver dans un dossier local dédié.
4. Exécuter : `python3 scripts/playtests/summarize.py /chemin/vers/rapports/*.json`.
5. Le script sépare les cohortes et indique numérateurs et dénominateurs. Il ignore un même chemin fourni deux fois et exclut les observations interrompues de la rétention. Deux fichiers distincts de contenu identique restent deux participants possibles. Sans identifiant de testeur, il ne peut pas reconnaître deux exports différents du même appareil : conserver uniquement le dernier fichier de chaque participant.
6. Comparer les observations qualitatives aux taux. Un faible effectif ne prouve pas une amélioration de fidélisation. Le recrutement, les essais réels et les résultats restent à réaliser.

## Validation

Les tests couvrent progression 0–25 et limites, ancienne sauvegarde, reprise exacte, récompenses idempotentes, génération échouée, fenêtre des compteurs, désactivation, export sans identité et indépendance vis-à-vis des sauvegardes. Les scénarios UI couvrent l’entrée en un geste, la reprise, le carnet et la préparation du partage. Les écrans d’accueil sont adaptés au paysage et aux très grands caractères.

Bundle Release iOS local non signé mesuré : **88 477 364 octets (88,48 Mo)**, extensions Watch et Messages incluses. Le garde-fou de 100 Mo passe. Cette valeur ne mesure pas le téléchargement App Store.

Commandes de contrôle :

```sh
swift test
python3 scripts/localization/check.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/playtests -p "test_*.py"
```

Les tests exécutables sur simulateur utilisent la signature locale ad hoc (`CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES`) pour conserver les entitlements CloudKit. Le simulateur dédié est Lisa Gameplay QA (`F60920A4-E595-4FAD-9DD0-C7FC876233A7`). DerivedData, journaux et résultats restent sous `/tmp`.

Cette livraison ne publie pas de nouvelle build TestFlight et n’envoie aucun message aux testeurs.

## Résultats du 11 octobre 2026

- 122 tests partagés réussis : 110 SudokuCore et 12 LisaInvitations.
- 107 tests iOS hébergés réussis, dont les nouveaux scénarios de première partie et de bilan.
- 8 scénarios UI distincts réussis : première partie et reprise, carnet, grands caractères, export local, paysage, victoire et étape suivante, cinq langues, changement de langue à chaud avec conservation de la partie. Un passage de 7 scénarios a été suivi de 4 relances ciblées après les dernières retouches (3 reprises et 1 scénario supplémentaire).
- 4 tests du script de synthèse réussis ; contrôle de localisation réussi pour les cinq langues.
- Build Release et contrôle du budget de taille réussis. Aucune validation sur appareil physique ni mesure de fidélisation n’est incluse.

Captures du simulateur dédié : [accueil](screenshots/first-journey-home.png), [carnet](screenshots/first-journey-album.png).

Journaux : `/tmp/lisa-journey-core-tests.log`, `/tmp/lisa-journey-final.log`, `/tmp/lisa-journey-polish.log`, `/tmp/lisa-journey-release-final.log`. Les premiers passages UI ont révélé des sélecteurs obsolètes et des problèmes de défilement ; les scénarios concernés ont été corrigés puis relancés avec succès.
