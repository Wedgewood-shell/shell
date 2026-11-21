#!/usr/bin/env python3
"""Copy the Kitty palette into core/Theme.qml (between the "kitty palette" markers).

A snapshot, not a live sync: run again after changing the Kitty colours, then
restart Quickshell. Only the palette block is rewritten; the role mapping below
it in Theme.qml is left alone.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
THEME = ROOT / 'core/Theme.qml'
KITTY = Path.home() / '.config/kitty'

palette = {}
for line in (KITTY / 'colors.conf').read_text().splitlines():
    match = re.fullmatch(r'\s*(\w+)\s+(#[0-9a-fA-F]{6})\s*', line)
    if match:
        palette[match[1]] = match[2].lower()

opacity = 1.0
for line in (KITTY / 'kitty.conf').read_text().splitlines():
    match = re.fullmatch(r'\s*background_opacity\s+([0-9.]+)\s*', line)
    if match:
        opacity = float(match[1])

entries = [('kittyBackground', 'background'), ('kittyForeground', 'foreground')]
entries += [(f'color{n}', f'color{n}') for n in (0, 1, 2, 3, 4, 5, 6, 8, 15)]
missing = [key for _, key in entries if key not in palette]
if missing:
    raise SystemExit(f'Missing in colors.conf: {", ".join(missing)}')

indent = ' ' * 4
block = [f'{indent}// BEGIN kitty palette']
block += [f'{indent}readonly property color {name}: "{palette[key]}"' for name, key in entries]
block += [f'{indent}readonly property real kittyOpacity: {opacity:g}', f'{indent}// END kitty palette']

source = THEME.read_text()
pattern = re.compile(r'^[ \t]*// BEGIN kitty palette\n.*?^[ \t]*// END kitty palette$', re.S | re.M)
if not pattern.search(source):
    raise SystemExit('Palette markers not found in core/Theme.qml')
updated = pattern.sub(lambda _: '\n'.join(block), source)
if updated == source:
    print('Theme.qml already matches the Kitty palette')
else:
    THEME.write_text(updated)
    print('Updated core/Theme.qml; restart Quickshell to apply')
