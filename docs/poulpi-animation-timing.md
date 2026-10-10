# Poulpi — corrections de rythme et de fermeture des yeux

## Causes identifiées le 10 octobre 2026

- Le clignement était inclus dans l'interpolation de 0,22 s entre expressions. Un changement de visage pouvait atténuer la fermeture et conserver le clignement précédent dans la pose de départ.
- Le temps global était remis à zéro toutes les `20π` secondes. Cette période convient aux oscillations en radians du regard, mais pas au clignement de période 4 s ni au battement de nage de période 2 s.
- Les réactions du corps utilisaient leur temps local, tandis que plusieurs gestes des bras utilisaient l'âge de la scène. L'éternuement présentait des impulsions différentes selon les parties du corps.
- Le lissage des bras plafonnait chaque pas à 50 ms. Sa réponse ralentissait donc lorsque la cadence descendait sous 20 images/s.
- « Rigoler » comprimait six rebonds dans 1,8 s, sans battement commun avec la bouche.

## Changements

Le clignement s'applique après le mélange des expressions et ne fait plus partie de la pose capturée pour la transition suivante. Son cycle conserve 0,35 s au total : 0,10 s de fermeture, 0,05 s entièrement fermé, puis 0,20 s de réouverture. Les contrôles mathématiques confirment une fermeture complète échantillonnée à 30 et 60 images/s.

Une horloge continue en Double sépare les périodes du regard, des clignements et de la nage. Le temps local de chaque réaction pilote ses accents ; seule la nage spatiale conserve le rythme de propulsion du trajet. L'éternuement partage une impulsion unique entre corps, bouche et bras. Le rire partage son battement entre visage et corps, avec trois rebonds pour « Rigoler ».

Le lissage exponentiel utilise le temps réellement écoulé. Les acrobaties des tentacules reviennent progressivement au repos. La pause, le ralenti, Réduire les animations et la suspension hors écran restent pilotés par les mécanismes existants.

Le maillage des paupières n'a pas été modifié : les contrôles numériques effectués n'ont pas confirmé de winding inversé ni de pénétration dans le blanc de l'œil. Cela ne constitue pas une validation visuelle du rendu.

## Validation à distinguer

Résultats de cette passe : 86 tests moteur exécutés, zéro échec ; compilation des modules Swift de l'application et vérification des types de toutes les sources AppTests/UITests réussies avec le SDK iOS Simulator 27.1 (cible iOS 17). Traductions et `git diff --check` valides. Les tests App/UI n'ont pas été exécutés.

- `PoulpiAnimationTimingTests` : continuité de l'horloge, raccords de boucle, fermeture à 30/60 images/s, lissage à 15–120 images/s, impulsion unique.
- `PoulpiTimingRegressionTests` : fermeture pendant un changement d'expression, absence de clignement conservé dans une transition, cadence après l'ancienne limite de 63 s. Ces tests utilisent le vrai rig et nécessitent l'exécution iOS.
- Les anciens tests de parcours des expressions transmettent maintenant au rig une horloge modulo 24 s, comme l'action SceneKit réelle ; le temps de capture reste absolu.

À observer sur appareil dans Poulpi : « Rigoler », « Atchoum ! », puis plusieurs changements rapides d'expression autour d'un clignement ; répéter en ralenti, aux deux tailles et avec les yeux vus de biais. Vérifier aussi une nage continue de plus de 64 s. Les outils de cette session ne permettent pas d'exécuter CoreSimulator : aucune observation visuelle après correction n'est revendiquée.
