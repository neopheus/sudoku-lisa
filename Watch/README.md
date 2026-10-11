# Lisa Watch

Native watchOS 10 companion: CloudKit invitation inbox, the same live SceneKit Poulpi sculpt and animation rig as iPhone, iPhone progress snapshot, and a local 4 × 4 Sudoku. Accepting an invitation records availability; Game Center joining stays on iPhone. Notification permission is requested only from the explicit inbox button. Notification taps open the inbox; CloudKit updates trigger refresh.

Progress uses `WCSession.updateApplicationContext` with `lisaProgressVersion: 1`, `completedGames: Int`, `currentStreak: Int`, `updatedAt: Double` (Unix epoch), `poulpiColor: String`, and `poulpiAccessory: String`. Older version-1 snapshots without appearance fields retain their progress and use the default appearance. Appearance changes are sent even when progress is unchanged. Missing snapshots display a synchronization message. Mini games do not add to iPhone statistics.

Run engine checks without the Watch SDK:

```
swiftc -module-cache-path /tmp/lisa-mini-cache Watch/MiniSudoku.swift Watch/Validation/MiniSudokuChecks.swift -o /tmp/lisa-mini-test
/tmp/lisa-mini-test
```

Add the target using `python3 scripts/add_watch_target.py`. It preserves existing project settings and is idempotent. Watch bundle ID: `com.xavier.sudokulisa.watchkitapp`, companion: `com.xavier.sudokulisa`, CloudKit container: `iCloud.com.xavier.sudokulisa`. The Apple provisioning profiles must enable CloudKit and APNs for both app IDs. A simulator build cannot validate push delivery or shared iCloud data on paired devices.


The Watch target compiles the actual iPhone sources `App/Design/LisaMascotMood.swift`, `OctopusModel.swift`, and `PoulpiRig.swift` and bundles the same losslessly compressed rig (LZFSE) and eye texture. The shared color pigments and snapshot decoder live in SudokuCore. There is no separate Watch drawing or copied 3D model. `SceneView` renders the common scene; motion pauses when offscreen, inactive, dimmed, or Reduce Motion is enabled. Device power use has not been measured.

Debug preview: launch the Watch simulator app with `--watch-poulpi-preview` to open its companion screen. Simulator builds that execute CloudKit require local ad hoc signing (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`); unsigned builds cannot launch CloudKit.


### Synchronisation d’apparence — correctif du 11 octobre 2026

Le contexte WatchConnectivity reste le canal de fond. Un message direct applique aussi la dernière apparence quand la Watch est joignable. À l’ouverture, à la réactivation ou au retour de connexion, la Watch demande un état à l’iPhone ; les valeurs inchangées sont réenvoyées après un échec. Le délégué iPhone est installé dès le lancement pour les réveils en arrière-plan. Le dernier contexte valide est conservé localement sur Watch et les contextes plus anciens sont ignorés.

Tests ciblés : couleur seule, reconnexion avec uniquement la dernière couleur, reprise d’envoi après échec, indépendance du canal immédiat, sérialisation de la couleur/accessoire et de la date. Capture simulateur du rendu doré + étoile : `/tmp/lisa-watch-sync-gold.png`, obtenue avec un contexte de test enregistré localement. Ce contrôle ne simule pas un transfert physique WatchConnectivity.

Le choix reste effectué sur l’iPhone ; ce correctif n’ajoute pas de sélecteur de couleurs sur la montre.
