from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = list((ROOT / "scripts").rglob("*.gd"))

issues: list[str] = []

for path in FILES:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    paren = bracket = brace = 0
    for i, line in enumerate(lines, 1):
        in_str = False
        esc = False
        for ch in line:
            if in_str:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    in_str = False
                continue
            if ch == '"':
                in_str = True
                continue
            if ch == "#":
                break
            if ch == "(":
                paren += 1
            elif ch == ")":
                paren -= 1
            elif ch == "[":
                bracket += 1
            elif ch == "]":
                bracket -= 1
            elif ch == "{":
                brace += 1
            elif ch == "}":
                brace -= 1
        if paren < 0 or bracket < 0 or brace < 0:
            issues.append(f"{path.relative_to(ROOT)}:{i} negative balance")
    if paren or bracket or brace:
        issues.append(
            f"{path.relative_to(ROOT)} unbalanced paren={paren} bracket={bracket} brace={brace}"
        )

    for i, line in enumerate(lines, 1):
        if re.search(r"\bmatch\b.*:", line):
            pass
        if re.match(r"\t*\"[^\"]+\"\s*,\s*\"[^\"]+\":\s*$", line):
            issues.append(f"{path.relative_to(ROOT)}:{i} suspicious match pattern: {line.strip()}")

print("checked", len(FILES), "files")
for issue in issues:
    print(issue)
if not issues:
    print("no bracket issues found")
