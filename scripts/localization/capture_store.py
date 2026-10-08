#!/usr/bin/env python3
"""Capture authentic, native-resolution Store screenshots on a dedicated QA simulator.

Requires Xcode and Pillow. The selected simulator's app data is reset by UI tests.
Example: python3 scripts/localization/capture_store.py --udid <QA-UDID>
"""
import argparse
from datetime import datetime
import os
from pathlib import Path
import subprocess

from PIL import Image

LOCALES = {"fr": "fr-FR", "en": "en-US", "de": "de-DE", "es": "es-ES", "ru": "ru"}
TESTS = {"fr": "French", "en": "English", "de": "German", "es": "Spanish", "ru": "Russian"}
FILES = {"01-Accueil": "02-accueil.png", "02-Grille-quotidienne": "01-partie.png",
         "03-Indice-explique": "03-indice.png", "04-Lecon-interactive": "04-tutoriel.png",
         "05-Voyage": "05-voyage.png", "06-Poulpi": "06-poulpi.png"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--udid", required=True, help="Dedicated QA simulator; test app progress is reset")
    parser.add_argument("--languages", nargs="+", choices=LOCALES, default=["en", "de", "es", "ru"])
    parser.add_argument("--derived-data", default="/tmp/lisa-localized-store-validation")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--result-bundle", type=Path)
    parser.add_argument("--display", help="Simulator display ID, needed for multi-display devices")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output or root / "docs/app-store"
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    bundle = args.result_bundle or Path(f"/tmp/lisa-localized-store-{stamp}.xcresult")
    log_path = bundle.with_suffix(".log")
    command = ["xcodebuild", "-project", "SudokuLisa.xcodeproj", "-scheme", "SudokuLisa",
               "-destination", f"platform=iOS Simulator,id={args.udid}", "-derivedDataPath", args.derived_data,
               "CODE_SIGNING_ALLOWED=NO", "-parallel-testing-enabled", "NO", "-resultBundlePath", str(bundle)]
    command += [f"-only-testing:LisaUITests/AppStoreScreenshotTests/test{TESTS[lang]}AppStoreScreenshots"
                for lang in args.languages]
    command.append("test")
    env = os.environ.copy()
    env["TEST_RUNNER_LISA_NATIVE_CAPTURE"] = "1"
    process = subprocess.Popen(command, cwd=root, env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, bufsize=1)
    captures = set()
    errors = []
    with log_path.open("w") as log:
        for line in process.stdout:
            log.write(line)
            log.flush()
            if "APPSTORE_CAPTURE_READY:" in line:
                marker = line.split("APPSTORE_CAPTURE_READY:", 1)[1].strip()
                language, name = marker.split("-", 1)
                target = output / LOCALES[language] / FILES[name]
                target.parent.mkdir(parents=True, exist_ok=True)
                try:
                    display = [f"--display={args.display}"] if args.display else []
                    subprocess.run(["xcrun", "simctl", "io", args.udid, "screenshot", *display, str(target)],
                                   check=True, capture_output=True, text=True)
                    with Image.open(target) as source:
                        size = source.size
                        source.convert("RGB").save(target)
                    captures.add((language, name))
                    print(f"Captured {target} at native {size}", flush=True)
                except (subprocess.CalledProcessError, OSError) as error:
                    errors.append(str(error))
                    print(f"Capture failed: {marker}: {error}", flush=True)
            elif "Test Case" in line or "** TEST" in line or "error:" in line:
                print(line.strip(), flush=True)
    status = process.wait()
    expected = {(language, name) for language in args.languages for name in FILES}
    missing = expected - captures
    print(f"Result bundle: {bundle}\nBuild/test log: {log_path}")
    if missing:
        print(f"Missing native captures: {sorted(missing)}")
    return status or (1 if errors or missing else 0)


if __name__ == "__main__":
    raise SystemExit(main())
