#!/usr/bin/env python3
"""Export the Debug app's actual 3D mascot and copy validated PNGs unchanged."""
import argparse
import json
from pathlib import Path
import shutil
import struct
import subprocess
import time
import zlib


def simctl(*args):
    return subprocess.check_output(["xcrun", "simctl", *args], text=True).strip()


def validate_png(path, width, height, alpha):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    offset = 8
    header = None
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        end = offset + 12 + length
        if end > len(data):
            break
        crc = struct.unpack(">I", data[end - 4:end])[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise ValueError(f"Incomplete or corrupt PNG: {path}")
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", payload)
        if kind == b"IEND":
            if header is None or header[:2] != (width, height):
                raise ValueError(f"Unexpected dimensions: {path}")
            if (header[3] in (4, 6)) != alpha:
                raise ValueError(f"Unexpected alpha channel: {path}")
            return
        offset = end
    raise ValueError(f"Incomplete PNG: {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("udid", help="Explicit UDID of a booted, disposable QA simulator")
    parser.add_argument("--bundle-id", default="com.xavier.sudokulisa")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    devices = json.loads(simctl("list", "devices", "booted", "--json"))
    if not any(d["udid"] == args.udid for group in devices["devices"].values() for d in group):
        parser.error("The specified simulator must already be booted.")
    container = Path(simctl("get_app_container", args.udid, args.bundle_id, "data"))
    output = container / "Documents" / "OctopusAssets"
    icons = root / "Stickers/Assets.xcassets/iMessage App Icon.stickersiconset"
    assets = [("AppIcon.png", 1024, 1024, False, root / "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")]
    for slot in json.loads((icons / "Contents.json").read_text())["images"]:
        name = slot.get("filename")
        if name:
            width, height = map(int, Path(name).stem.rsplit("-", 1)[1].split("x"))
            assets.append((name, width, height, False, icons / name))
    for name in ("lisa-smile", "lisa-bravo", "lisa-zen", "lisa-heart"):
        assets.append((name + ".png", 408, 408, True, root / "Stickers/Resources" / (name + ".png")))

    # Remove only these generated staging files so a stale export cannot pass.
    for name, *_ in assets:
        (output / name).unlink(missing_ok=True)
    simctl("launch", "--terminate-running-process", args.udid, args.bundle_id, "--export-octopus-assets")
    deadline = time.monotonic() + 60
    while True:
        try:
            for name, width, height, alpha, _ in assets:
                validate_png(output / name, width, height, alpha)
            break
        except (OSError, ValueError, struct.error) as error:
            if time.monotonic() >= deadline:
                raise SystemExit(f"Export not ready; repository assets unchanged. Install a current Debug build. Last error: {error}")
            time.sleep(0.25)
    # No resampling or conversion: preserve all dimensions and transparency.
    for name, _, _, _, destination in assets:
        shutil.copyfile(output / name, destination)
    print(f"Copied {len(assets)} validated PNGs from {output}. Rebuild to include them.")


if __name__ == "__main__":
    main()
