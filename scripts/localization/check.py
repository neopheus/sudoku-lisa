#!/usr/bin/env python3
"""Validate localization coverage without Xcode (run from any directory)."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[2]
languages = ('fr', 'en', 'ru', 'de', 'es')
literal = r'"(?:[^"\\]|\\.)*"'
entry = re.compile(rf'^({literal})\s*=\s*({literal});$')

def read(path):
    values = {}
    for line in path.read_text().splitlines():
        if not line.strip() or line.startswith('//'):
            continue
        match = entry.fullmatch(line)
        assert match, (path, line)
        key, value = map(json.loads, match.groups())
        assert key not in values, (path, 'duplicate', key)
        assert value, (path, 'empty', key)
        values[key] = value
    return values

for directory in ('Sources/SudokuCore/Resources', 'Stickers'):
    source = read(root / directory / 'fr.lproj/Localizable.strings')
    for language in languages:
        values = read(root / directory / f'{language}.lproj/Localizable.strings')
        assert source.keys() == values.keys(), (directory, language, 'key mismatch')
        for key, value in values.items():
            assert source[key].count('%@') == value.count('%@'), (language, key, 'placeholder mismatch')
    print(f'{directory}: {len(source)} keys complete in all five languages')

source = read(root / 'Sources/SudokuCore/Resources/fr.lproj/Localizable.strings')
for directory in ('App', 'Sources/SudokuCore'):
    for file in (root / directory).rglob('*.swift'):
        for key in re.findall(rf'L10n\.text\(({literal})', file.read_text()):
            assert json.loads(key) in source, (file, 'missing translation', key)
print('All literal L10n.text calls have translations.')
