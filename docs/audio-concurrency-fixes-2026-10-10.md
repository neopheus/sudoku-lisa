# Audio et concurrence — 10 octobre 2026

## Corrections

- `LisaAudio` possède une file série pour la session et tous ses lecteurs. Configuration, activation, désactivation, préparation et lecture ne s'exécutent plus sur le thread principal. Les commandes de l'interface et notifications sont ordonnées sur cette file ; une activation n'est pas relancée si la session est déjà active. La solution reste compatible iOS 17.
- Deux tests injectent une session factice : activation bloquée suivie d'un arrêt sans blocage de l'interface ; échec d'activation, nouvelle tentative et absence d'activations redondantes.
- Les callbacks réseau GameKit transmettent des valeurs au MainActor. Les objets match/invitation nécessaires à l'interface utilisent un transfert unique protégé, vidé lors de sa consommation. Aucune conformité Sendable globale n'est ajoutée à GameKit.
- L'action SceneKit retrouve l'éclairage dans sa propre hiérarchie, au lieu de capturer un SCNNode externe. Le contenu du keyframe SwiftUI capture la valeur locale de l'autorisation d'animation.
- Le compteur KVO du test des poses utilise un verrou, afin d'éviter une mutation concurrente non protégée.
- `COPY_PHASE_STRIP = NO` évite de tenter de supprimer les symboles de l'extension déjà signée lors de la copie. Le réglage de suppression des symboles du produit lié reste inchangé.

## Limites de validation

Le module de l'application a été compilé avec le SDK iOS, cible iOS 17 et Swift 6. Après les derniers ajustements, la vérification de types de toutes les sources App et AppTests passe sans erreur ni avertissement. `git diff --check` et la validation syntaxique du projet passent aussi. Ces contrôles ne remplacent pas une construction Xcode complète, la signature ou des tests en fonctionnement.

Référence pour la distinction entre suppression des symboles à la copie et sur le produit lié : [réglages de compilation Apple](https://help.apple.com/xcode/mac/current/en.lproj/itcaec37c2a6.html).

Le sandbox empêche l'exécution du manifeste SwiftPM par Xcode et l'accès à CoreSimulator. Les nouveaux tests applicatifs ne peuvent donc pas être exécutés ici. Vérifier sur iPhone le lancement avec musique, les réglages sonores, le passage arrière-plan/premier plan, les interruptions et le débranchement d'écouteurs avec le Thread Performance Checker actif.

Le détail de « Update to recommended settings » n'est pas disponible : l'accès automatisé à l'interface Xcode a été refusé. Le marqueur `LastUpgradeCheck` n'a pas été modifié pour masquer cette alerte. La disparition de l'avertissement de copie doit également être confirmée lors du prochain build Xcode complet.

Aucun commit, push ou déploiement.
