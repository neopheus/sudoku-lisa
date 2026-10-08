#!/usr/bin/env python3
"""Collect native Poulpi renders and encode matching transparent WebP files.

The artwork is rendered by PoulpiStickerExporter in the Debug iOS app. Pillow
only re-encodes/compresses it; it does not create or alter the artwork.
"""

import argparse
from hashlib import sha256
from pathlib import Path
import subprocess
import time

from PIL import Image


MOODS = (
    "idle happy thinking encouraging sleepy celebrating pirouette wobble peek jelly "
    "swim bow curious giggle rocket chase moonwalk juggle cloudHide sneeze "
    "tumble balance dizzy superhero"
).split()


def source_from_simulator(udid: str, bundle_id: str) -> Path:
    container = subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", udid, bundle_id, "data"], text=True
    ).strip()
    return Path(container) / "Documents" / "PoulpiStickers"


def validate(path: Path, size: int) -> Image.Image:
    with Image.open(path) as image:
        image.load()
        if image.format != "PNG" or image.size != (size, size) or image.mode != "RGBA":
            raise ValueError(f"Expected {size}x{size} RGBA PNG: {path}")
        lo, hi = image.getchannel("A").getextrema()
        if lo != 0 or hi != 255:
            raise ValueError(f"Missing transparent background or opaque art: {path}")
        bounds = image.getchannel("A").getbbox()
        if bounds is None or min(bounds[0], bounds[1], size - bounds[2], size - bounds[3]) < 4:
            raise ValueError(f"Artwork touches the canvas edge: {path}: {bounds}")
        return image.copy()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--source", type=Path, help="PoulpiStickers folder from the Debug app")
    group.add_argument("--udid", help="Booted QA simulator containing the installed Debug app")
    parser.add_argument("--bundle-id", default="com.xavier.sudokulisa")
    parser.add_argument("--launch", action="store_true", help="Run the Debug export before collecting")
    args = parser.parse_args()
    if args.launch and not args.udid:
        parser.error("--launch requires --udid")

    source = args.source or source_from_simulator(args.udid, args.bundle_id)
    if args.launch:
        for name in [*(f"poulpi-{mood}.png" for mood in MOODS), "poulpi-tray.png"]:
            (source / name).unlink(missing_ok=True)
        subprocess.run(
            ["xcrun", "simctl", "launch", "--terminate-running-process", args.udid,
             args.bundle_id, "--export-poulpi-stickers"], check=True
        )
        deadline = time.monotonic() + 90
        while not (source / "poulpi-tray.png").exists():
            if time.monotonic() >= deadline:
                raise SystemExit("Native export timed out; install a current Debug build.")
            time.sleep(0.25)

    art = {mood: validate(source / f"poulpi-{mood}.png", 512) for mood in MOODS}
    tray = validate(source / "poulpi-tray.png", 96)
    digests = {mood: sha256(image.tobytes()).hexdigest() for mood, image in art.items()}
    if len(set(digests.values())) != len(MOODS):
        raise ValueError("At least two moods produced identical pixels")

    destination = Path(__file__).resolve().parents[2] / "Sources" / "PoulpiStickers" / "Resources"
    destination.mkdir(parents=True, exist_ok=True)
    for mood, image in art.items():
        stem = f"poulpi-{mood}"
        png = destination / f"{stem}.png"
        webp = destination / f"{stem}.webp"
        image.save(png, format="PNG", optimize=True, compress_level=9)
        image.save(webp, format="WEBP", quality=82, method=6, exact=True)
        if png.stat().st_size >= 500_000 or webp.stat().st_size >= 100_000:
            raise ValueError(f"Asset exceeds size limits: {stem}: {png.stat().st_size}/{webp.stat().st_size}")
        with Image.open(webp) as check:
            if check.size != (512, 512) or check.mode != "RGBA":
                raise ValueError(f"Invalid WebP dimensions or transparency: {webp}")
    tray_path = destination / "poulpi-tray.png"
    tray.save(tray_path, format="PNG", optimize=True, compress_level=9)
    if tray_path.stat().st_size >= 50_000:
        raise ValueError(f"Tray exceeds 50 KB: {tray_path.stat().st_size}")
    print(f"Validated and encoded {len(art)} transparent sticker pairs plus tray in {destination}")


if __name__ == "__main__":
    main()
