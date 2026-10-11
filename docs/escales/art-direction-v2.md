# Escales — illustrated revision

User feedback: prototype vectors felt flat and lifeless; synthetic music was unsatisfying.

Twenty-five original 1024×1536 background illustrations generated using the built-in
imagegen tool, stored in `App/Assets.xcassets/SceneryStop{World}{Index}.imageset`.
They replace the flat vector backgrounds. Each stop has its own artwork: scenes
are individually composed, rather than recoloured or cropped copies. The five first
master images serve the floating garden, confection cottage, shipwreck, aurora and
planetary rings; twenty additional images complete the catalogue.
No external game art was copied. `illustration-prompts.json` records the prompt set.

Prompt set: premium whimsical iOS puzzle background, sculpted 3D storybook treatment,
rounded tactile materials, soft global illumination, atmospheric depth, detailed
outer framing and a calm central clearing, no text/UI/characters/logos.
World additions: marshmallow flowers, floating gardens and a rose river; lollipop
woodland, candy cottage and bridge; turquoise underwater lagoon, coral, shells and
shipwreck; snowy lavender mountains, frozen lake and aurora; pearlescent planets,
peach rings, nebulae and crystal moon rocks. Each prompt requested portrait 1024×1536.

A separate 30 fps Canvas has 28 bounded world-specific foreground elements plus
three larger inhabitants/effects: fluttering petals and butterflies; floating sweets;
bubbles and fish; rotating snow crystals and moving aurora ribbons; pulsing stars
and shooting-star trails. No per-frame raster decoding or unbounded particle creation.
It uses the existing visibility/background/reduced-motion rendering gates. The
artwork remains still while only its foreground layer redraws. The entire background
sits behind the opaque board. Header, introduction and result text receive opaque
reading surfaces to work against more detailed artwork.

Music: five composed tracks replace the prototype loops; provenance, license and
in-app attribution are documented in `../audio-music-credits.md`.

Physical iPhone thermal/fluidity and musical listening approval are not claimed.

## Verification — 2026-10-11

- `swift test`: 116 engine/package tests passed (104 SudokuCore + 12 LisaInvitations).
- Final dedicated iPhone SE simulator run: 14 hosted tests and five scenery UI
  scenarios passed. Covers all 25 packaged illustrations, moving vs frozen frames,
  50 light/dark renders, audio resources/crossfades/interruption, migration, resume,
  stale introduction completion, timer and rewards, skip/background, large text,
  paper/static modes and 20 in-game portrait/landscape/light/dark captures.
- Final result: `/tmp/lisa-validation/Logs/Test/Test-SudokuLisa-2026.10.11_11-03-32-+0200.xcresult`.
- Five-language localization checker: 676 core keys complete; `git diff --check` clean.
- Simulator ad-hoc signing used because the existing CloudKit entitlement path
  requires a signed app to launch. No distribution build, commit or release.
- `preview.html` contains the 25 illustrations, music players and a 10-second
  simulator recording. `in-game-light.png` and `in-game-dark.png` are captures of
  actual game screens. These demonstrate rendering, not physical-device performance.
- Additional final UI run with system Reduce Motion enabled passed; the simulator setting was restored to its initial enabled state.
