"""Original, deterministic Lisa sounds. Standard library only; PCM mono 22.05 kHz."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / "App/Resources/Audio"
RATE = 22050


def write(name, samples):
    ROOT.mkdir(parents=True, exist_ok=True)
    assert max(abs(s) for s in samples) < 0.98, name
    with wave.open(str(ROOT / f"lisa-{name}.wav"), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(b"".join(struct.pack("<h", round(s * 32767)) for s in samples))


def bells(name, notes, spacing=0.12, decay=0.25, gain=0.16):
    duration = (len(notes) - 1) * spacing + decay * 7
    samples = [0.0] * int(duration * RATE)
    for n, pitch in enumerate(notes):
        frequency = 440 * 2 ** ((pitch - 69) / 12)
        start = int(n * spacing * RATE)
        for i in range(len(samples) - start):
            t = i / RATE
            envelope = min(1, t / 0.006) * math.exp(-t / decay)
            fade = min(1, (len(samples) - start - i) / (RATE * 0.03))
            tone = math.sin(2 * math.pi * frequency * t) + 0.18 * math.sin(2 * math.pi * frequency * 2 * t)
            samples[start + i] += gain * envelope * tone * fade
    write(name, samples)


def main():
    bells("select", [79], decay=0.025, gain=0.10)
    bells("place", [76], decay=0.075, gain=0.18)
    bells("erase", [72, 67], spacing=0.04, decay=0.035, gain=0.09)
    bells("hint", [72, 79], spacing=0.12, decay=0.17)
    bells("milestone", [76, 79, 84], spacing=0.09, decay=0.19)
    bells("hello", [79, 84, 81], spacing=0.10, decay=0.12)
    bells("victory", [72, 76, 79, 84, 83, 84], spacing=0.18, decay=0.32, gain=0.14)
    rng = random.Random(42)
    write("note", [rng.uniform(-0.07, 0.07) * math.sin(math.pi * i / 2646) ** 2 for i in range(2646)])
    # A sparse pentatonic lullaby; tails wrap into the start for a seamless loop.
    length = 24 * RATE
    samples = [0.0] * length
    for n, pitch in enumerate([60, 67, 72, 76, 69, 64, 67, 74]):
        f = 440 * 2 ** ((pitch - 69) / 12)
        for i in range(6 * RATE):
            t = i / RATE
            envelope = math.sin(math.pi * t / 6) ** 2
            samples[(n * 3 * RATE + i) % length] += 0.07 * envelope * (math.sin(2 * math.pi * f * t) + 0.15 * math.sin(4 * math.pi * f * t))
    write("ambience", samples)


if __name__ == "__main__":
    main()
