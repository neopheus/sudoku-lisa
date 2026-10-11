#!/usr/bin/env python3
"""Five original Lisa loops. No samples, soundfonts, recordings or external melodies.
PCM synthesis and note sequences authored for this repository. See docs/audio-music-credits.md.
Run with Python 3; deterministic, standard library only. Tails wrap across the loop seam.
"""
import array
import math
from pathlib import Path
import wave

RATE = 32000
BEAT = .75
LENGTH = 32 * BEAT
N = int(RATE * LENGTH)
OUTPUT = Path(__file__).resolve().parents[1] / 'App/Resources/Audio/Music'
# Independent eight-bar motifs, with rests and a varied second phrase.
SCORES = {
    'garden': ([72, 76, 79, 74, 76, 81, 79, 76, 74, 79, 83, 81, 76, 74, 72, 79], [48, 53, 57, 55], 'wood'),
    'candyForest': ([74, 81, 77, 76, 69, 74, 77, 81, 79, 76, 74, 69, 72, 76, 77, 74], [50, 46, 53, 48], 'pluck'),
    'lagoon': ([76, 83, 81, 78, 74, 78, 81, 85, 83, 78, 76, 73, 74, 78, 71, 76], [52, 57, 50, 47], 'water'),
    'frost': ([79, 74, 78, 81, 83, 78, 74, 71, 76, 79, 83, 86, 81, 78, 74, 79], [55, 52, 48, 50], 'piano'),
    'stars': ([81, 88, 83, 85, 80, 83, 87, 90, 88, 85, 83, 78, 80, 85, 83, 81], [57, 54, 50, 52], 'air'),
}

def render(name, melody, roots, voice):
    samples = array.array('d', [0]) * N
    def note(midi, beat, duration, gain, timbre):
        frequency = 440 * 2 ** ((midi - 69) / 12)
        count = int(duration * RATE)
        start = int(beat * BEAT * RATE)
        for i in range(count):
            t = i / RATE
            phase = 2 * math.pi * frequency * t
            attack = min(1, t / (.35 if timbre == 'pad' else .012))
            release = min(1, (duration - t) / .12)
            decay = math.exp(-t * (1.5 if timbre in ('water', 'piano') else 3.5))
            if timbre == 'pad':
                tone = math.sin(phase) + .16 * math.sin(phase * 2)
                envelope = math.sin(math.pi * t / duration) ** 2
            elif timbre == 'wood':
                tone = math.sin(phase) + .3 * math.sin(phase * 4) * math.exp(-t * 12)
                envelope = decay
            elif timbre == 'pluck':
                tone = math.sin(phase) + .25 * math.sin(phase * 2) + .1 * math.sin(phase * 3)
                envelope = decay
            else:
                tone = math.sin(phase) + .18 * math.sin(phase * 2) * math.exp(-t * 3)
                envelope = math.exp(-t * (.8 if timbre == 'air' else 1.5))
            samples[(start + i) % N] += gain * tone * attack * release * envelope
    for bar in range(8):
        root = roots[bar % 4]
        for interval in (0, 7, 16 if name in ('lagoon', 'stars') else 12):
            note(root + interval, bar * 4, 4.5, .08, 'pad')
        note(root + 12, bar * 4 + 1, 1.2, .07, voice)
        note(root + 19, bar * 4 + 3, 1.2, .045, voice)
    for i, pitch in enumerate(melody):
        note(pitch, i * 2 + (.5 if i % 4 == 3 else 0), 2.8, .14, voice)
        if i in (2, 6, 11, 14):
            note(pitch + 12, i * 2 + 1, 1.8, .035, 'water')
    # Circular quiet echo preserves the exact periodic waveform.
    delay = int(.28125 * RATE)
    samples = [v + .17 * samples[(i - delay) % N] for i, v in enumerate(samples)]
    peak = max(abs(v) for v in samples)
    pcm = array.array('h', (round(v / peak * 18000) for v in samples))
    path = OUTPUT / f'lisa-world-{name}.wav'
    with wave.open(str(path), 'wb') as output:
        output.setnchannels(1); output.setsampwidth(2); output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    print(f'{path.name}: {LENGTH}s, peak {max(abs(v) for v in pcm)}, seam {abs(pcm[-1]-pcm[0])}')

if __name__ == '__main__':
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, (melody, roots, voice) in SCORES.items():
        render(name, melody, roots, voice)
