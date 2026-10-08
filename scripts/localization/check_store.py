#!/usr/bin/env python3
"""Validate prepared App Store copy and native screenshots without contacting Apple."""
import argparse
import json
from pathlib import Path
import struct
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "docs/app-store"
LOCALES = ("fr-FR", "en-US", "de-DE", "es-ES", "ru")
SHOTS = ("01-partie.png", "02-accueil.png", "03-indice.png",
         "04-tutoriel.png", "05-voyage.png", "06-poulpi.png")


def validate(require_images: bool) -> None:
    for locale in LOCALES:
        data = json.loads((ROOT / f"{locale}.json").read_text())
        entries = data["fields"]
        fields = {entry["id"]: entry["value"] for entry in entries}
        assert len(fields) == len(entries), f"{locale}: duplicate field"
        for key, limit in (("name", 30), ("subtitle", 30)):
            assert 0 < len(data[key]) <= limit, f"{locale}: {key} exceeds {limit} characters"
        for key, limit in (("promotionalText", 170), ("description", 4000)):
            assert 0 < len(fields[key]) <= limit, f"{locale}: {key} exceeds {limit} characters"
        # Apple's documented keyword limit is bytes, not Unicode characters.
        keyword_bytes = len(fields["keywords"].encode("utf-8"))
        assert 0 < keyword_bytes <= 100, f"{locale}: keywords exceed 100 UTF-8 bytes"
        assert all(len(word.strip()) > 2 for word in fields["keywords"].split(","))
        assert "<html" not in fields["description"].lower()
        if require_images:
            for name in SHOTS:
                path = ROOT / locale / name
                header = path.read_bytes()[:26]
                assert header[:8] == b"\x89PNG\r\n\x1a\n", f"Invalid PNG: {path}"
                width, height = struct.unpack(">II", header[16:24])
                assert (width, height) == (1179, 2556), f"Unexpected native size: {path}"
                with Image.open(path) as image:
                    assert image.mode in ("RGB", "RGBA"), f"Expected RGB image: {path}"
                    if image.mode == "RGBA":
                        assert image.getchannel("A").getextrema() == (255, 255), f"Transparent screenshot: {path}"
        print(f"{locale}: copy valid; keywords {keyword_bytes}/100 bytes"
              + ("; 6 native opaque screenshots valid" if require_images else ""))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--images", action="store_true", help="Also require all six screenshots per locale")
    validate(parser.parse_args().images)
