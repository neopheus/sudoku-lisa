#!/bin/sh
# A local guardrail, not an App Store download-size certification.
set -eu
if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
  echo "Usage: sh scripts/check_size.sh /path/to/SudokuLisa.app" >&2
  exit 2
fi
python3 - "$1" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
size = sum(p.stat().st_size for p in path.rglob('*') if p.is_file() and not p.is_symlink())
limit = 100_000_000
print(f'Local bundle: {size:,} bytes ({size / 1_000_000:.2f} MB)')
print('Budget: < 100 MB (decimal). This is NOT an App Store size measurement.')
print('Confirm every device variant with a signed App Thinning Size Report and App Store Connect.')
if size >= limit:
    print('FAIL: local bundle meets or exceeds budget.', file=sys.stderr)
    sys.exit(1)
print('PASS: local bundle below budget; distribution size remains to be confirmed.')
PY
