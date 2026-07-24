from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "scripts" / "autoload" / "game_state.gd"

text = TARGET.read_text(encoding="utf-8")
lines = text.splitlines()

print("line 1478:", repr(lines[1477]))
for idx in (1477, 1613, 1614, 1615):
    if idx < len(lines):
        line = lines[idx]
        for i, ch in enumerate(line):
            if ord(ch) in (0x22, 0x201C, 0x201D):
                print(f"  L{idx+1} col{i}: U+{ord(ch):04X} {ch!r}")

odd_lines = []
for i, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.startswith("#"):
        continue
    if line.count('"') % 2 == 1 and "'" not in line:
        odd_lines.append((i, line[:100]))

print("odd ascii quote lines:", len(odd_lines))
for item in odd_lines[:15]:
    print(item)
