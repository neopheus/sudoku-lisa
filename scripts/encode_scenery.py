#!/usr/bin/env python3
"""Build shipping JPEGs from untouched PNG masters; requires ImageMagick 7.
Never resize, strip color profiles, subsample chroma, or encode from another JPEG.
"""
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MASTERS = ROOT / 'docs/escales/png-masters'
CATALOG = ROOT / 'App/Assets.xcassets'


def main():
    sources = sorted(MASTERS.glob('SceneryStop*.png'))
    if len(sources) != 25:
        raise ValueError('Expected the 25 original PNG scenery masters')
    with tempfile.TemporaryDirectory() as directory:
        prepared = []
        for source in sources:
            properties = subprocess.check_output(
                ['magick', 'identify', '-format', '%w %h %[opaque]', str(source)], text=True)
            if properties.strip() != '1024 1536 True':
                raise ValueError(f'Unexpected dimensions or transparency: {source}: {properties}')
            target = Path(directory) / (source.stem + '.jpg')
            subprocess.run(['magick', str(source), '-sampling-factor', '4:4:4',
                            '-quality', '98', str(target)], check=True)
            prepared.append((source, target))
        for source, target in prepared:
            folder = CATALOG / (source.stem + '.imageset')
            manifest = folder / 'Contents.json'
            contents = json.loads(manifest.read_text())
            assert len(contents['images']) == 1
            contents['images'][0]['filename'] = 'art.jpg'
            (folder / 'art.jpg').write_bytes(target.read_bytes())
            manifest.write_text(json.dumps(contents, indent=2) + '\n')
            print(f'{source.stem}: {source.stat().st_size:,} -> {target.stat().st_size:,} bytes')


if __name__ == '__main__':
    main()
