#!/usr/bin/env python3
"""Encode the five world masters for shipping; never re-encode the bundled AACs.
Usage: python3 scripts/encode_world_music.py /path/to/alac-masters
Requires macOS afconvert/afinfo. Authoring masters are retained in Git history.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
WORLDS = ('garden', 'candyForest', 'lagoon', 'frost', 'stars')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('masters', type=Path)
    args = parser.parse_args()
    output = ROOT / 'App/Resources/Audio/Music'
    sources = [args.masters / f'lisa-world-{world}.m4a' for world in WORLDS]
    for source in sources:
        if source.resolve() == (output / source.name).resolve():
            parser.error('Use the original ALAC masters outside the shipping resource directory.')
        info = subprocess.check_output(['afinfo', str(source)], text=True)
        if 'alac' not in info:
            parser.error(f'{source} is not an ALAC master; refusing another lossy encode.')
    with tempfile.TemporaryDirectory() as scratch:
        for source in sources:
            encoded = Path(scratch) / source.name
            subprocess.run(['afconvert', str(source), str(encoded), '-f', 'm4af',
                            '-d', 'aac@48000', '-b', '256000', '-q', '127', '-s', '2'], check=True)
            print(f'{source.name}: {source.stat().st_size:,} -> {encoded.stat().st_size:,} bytes')
        # Publish only after every encode succeeds.
        for source in sources:
            (output / source.name).write_bytes((Path(scratch) / source.name).read_bytes())


if __name__ == '__main__':
    main()
