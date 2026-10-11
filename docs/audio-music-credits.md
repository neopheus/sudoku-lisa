# Game music credits

The iOS app includes two selectable looping tracks:

- “Marimba Game Music Playful Tropical Jungle Puzzle” by Denis-Pavlov-Music, downloaded from [Pixabay](https://pixabay.com/music/video-games-marimba-game-music-playful-tropical-jungle-puzzle-399759/). Pixabay Content License: https://pixabay.com/service/license-summary/
- “Fishbowl Acrobatics” by Eric Matyas, downloaded from [OpenGameArt](https://opengameart.org/content/fishbowl-acrobatics-looping). Licensed CC BY 3.0: https://creativecommons.org/licenses/by/3.0/. The supplied OGG file was converted to MP3 for iOS playback.

The Settings screen credits both sources. Eric Matyas requests the in-game credit “Fishbowl Acrobatics” by Eric Matyas, www.soundimage.org.

## Automatic world music — replacement 2026-10-11

The five prototype oscillator loops were replaced after user feedback. All five
replacement compositions are by **Eric Matyas, www.soundimage.org**.

| World | Composition | Duration | Source |
|---|---|---:|---|
| garden | The Meadow We Call Home | 66.78s | [Source](https://soundimage.org/fantasy-13/) |
| candyForest | Light Puzzles 13 | 69.68s | [Source](https://soundimage.org/puzzle-music-8/) |
| lagoon | Hidden Riddles | 80.00s | [Source](https://soundimage.org/puzzle-music-8/) |
| frost | Icicle Wonderland | 43.68s | [Source](https://soundimage.org/fantasy-10/) |
| stars | Puzzles in Faraway Lands | 64.00s | [Source](https://soundimage.org/fantasy-13/) |

License: [Soundimage International Public License](https://soundimage.org/sample-page/),
including its disclaimer of warranties. [Attribution requirements](https://soundimage.org/attribution-info/).
The author, individual titles, website, license link and conversion notice appear
inside Settings in the app. Sources and exact durations are in `escales/music-manifest.json`.
These are tracks explicitly described as looping on the composer's pages.
Downloads were initially encoded as Apple Lossless; the bundled files now use
high-quality AAC (48 kHz stereo, constrained VBR at 256 kb/s, Apple encoder quality 127)
in `.m4a` for native offline
AVAudioPlayer playback. No musical arrangement or duration changes were made.
The two fixed choices above are unchanged. The old synthesis script is historical;
it must not be used to regenerate the replacement soundtrack.

Technical playback validation is separate from subjective listening and physical
iPhone speaker/headphone loop-seam assessment, which remain to be done.

Playback gains compensate measured RMS differences (garden −19.0, forest −19.5, lagoon −20.2, frost −15.4, stars −22.0 dBFS). Attenuation only, before the 0.38 master level; playback gains are unchanged by the bundle optimization. This is a level check, not a listening assessment.
