# Bundle optimization — 2026-10-11

**Final local Release bundle: 87.89 MB**, including Watch and iMessage.
Phase 2 below adds user-approved visually checked JPEG scenery compression.
The unchanged-image statements and 114.15 MB result in Phase 1 describe the
earlier lossless-only pass.

## Phase 1 — audio and lossless rig packaging

The images, asset catalogs, eye texture, mesh values, shaders and animations are
unchanged. The validated sculpt is compressed losslessly with Foundation LZFSE.
The JSON remains the authoring source, excluded from the iPhone target; both
phone and Watch package `poulpi-rig.lzfse`. Decompression happens once in the
existing shared-resource initialization. A SHA-256 regression test checks the
exact decompressed bytes.

The five world tracks use Apple's AAC encoder at 48 kHz stereo, constrained VBR
256 kb/s, quality 127. This is lossy audio compression, not a claim of bit-perfect
sound. Track selection, music, playback gains and duration are retained. The two
existing fixed tracks are unchanged. Native decoding and duration tests cover
all five files; headphone/speaker listening on a physical device remains separate.

## Regeneration

- Rig: `swift scripts/mascot/compress_rig.swift App/Resources/Mascot/poulpi-rig.json App/Resources/Mascot/poulpi-rig.lzfse`.
  The Blender exporter invokes this automatically. The compressor verifies a
  byte-for-byte round trip before writing the result. If the sculpt intentionally
  changes, validate it visually before updating the SHA-256 test reference.
- Audio: `python3 scripts/encode_world_music.py /path/to/alac-masters`.
  Use the original ALAC masters from Git history; the script refuses bundled AAC
  files as input to prevent successive lossy encodes. See `audio-music-credits.md`
  and `escales/music-manifest.json` for the unchanged sources and credits.

## Measurement

Comparison uses unsigned Release builds for generic iOS, including embedded
Watch and iMessage products, built with the same Xcode and settings. Sizes sum
file lengths, not filesystem allocation. These are local installed bundles,
not App Store download or device-thinned sizes.

| Resource | Before | After |
|---|---:|---:|
| Complete bundle | 188.43 MB | 114.15 MB |
| Five world music tracks | 71.53 MB | 11.85 MB |
| Rig, per application (phone + Watch) | 11.48 MB | 4.18 MB |

Reduction: **74.28 MB (39.4%)**. All three compiled
`Assets.car` catalogs are byte-identical, as are both copies of the eye texture.
Neither application ships the original JSON alongside the compressed rig.

The existing `< 100 MB` local budget in `scripts/check_size.sh` still fails at
114.15 MB; it has not been relaxed. Further reduction of the large visual assets
was not attempted through resizing or lossy encoding. App Store download size
requires a signed archive and thinning report; no release was uploaded.

## Validation results

- `swift test`: 104 SudokuCore tests and 12 invitation tests passed.
- iOS simulator: all 103 hosted app tests plus the Poulpi rotation/zoom/autoplay
  UI test passed on dedicated iPhone 16 / iOS 18.5 `Lisa Bundle QA`.
- This includes full AAC decoding, original durations within 1 ms, exact geometry
  hash, absence of the raw JSON in the app, rendering, playback and persistence.
- The documented unsigned simulator test command crashes on the pre-existing
  CloudKit initialization (missing signed entitlements). Validation was rerun
  successfully with `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`; no application
  behavior was changed to bypass CloudKit.
- Unsigned generic-device Release build succeeded for phone, Watch and iMessage.
- Localization validation passed for all five languages; `git diff --check` passed.

Logs and test results from this run are under `/tmp/lisa-bundle-*`; generated
build products and `.xcresult` remain outside the repository.

## Phase 2 — high-quality scenery images

User approved visually checked lossy compression on 2026-10-11. The 25 opaque
backgrounds now use JPEG quality 98 with 4:4:4 chroma and unchanged 1024×1536
resolution. Color profiles are not stripped. The original PNGs were moved without
changing a byte into `docs/escales/png-masters/`, outside all application targets.
Regenerate directly from those masters with `python3 scripts/encode_scenery.py`.

| Local Release measurement | Before scenery optimization | After |
|---|---:|---:|
| All 25 scenery renditions in Assets.car | 56.13 MB | 29.87 MB |
| Main Assets.car | 57.22 MB | 30.96 MB |
| Complete app including Watch and iMessage | 114.15 MB | 87.89 MB |

Additional saving: **26.26 MB (23.0%)**. Total saving from the initial 188.43 MB
bundle: **100.54 MB (53.4%)**. The unchanged 100 MB local guardrail now passes.
This remains an unsigned local build measurement, not an App Store download size.

Validation: Release build passed; both existing SceneryRenderingTests passed on
the dedicated iOS 18.5 simulator, covering all 25 images and their living
foreground, and light/dark galleries. Reviewed all 25 original/JPEG pairs with
full-scene previews and 1:1 center crops, then both simulator-rendered galleries.
No visible degradation was noticed in those comparisons; this is not a claim of
pixel identity or a physical-device evaluation. Raw RGB SSIM minimum 0.987221,
PSNR minimum 45.1581 dB; per-image measurements in
`escales/compression-metrics.json`. Metrics supplement visual review rather than
proving perceptual equivalence.

`assetutil --info` confirms 25 JPEG renditions, all 1024×1536, and no duplicate
PNG scenery renditions. Other images, icons, transparent stickers, textures and
animations are untouched by this phase. Existing full test results above remain
from Phase 1; only the two directly relevant scenery tests were rerun here.

The native catalog compression options were evaluated following Apple's
[Image Set format reference](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/ImageSetType.html).
Explicit high-quality JPEG inputs were chosen over automatic lossy conversion
so the encoding quality and full color sampling are controlled and reviewable.
