#!/usr/bin/env python3
"""Check flow/defs/*.json:
- file name 90161Z-T<NN>-<slug>-r<N> (PFM 2026-11-11: downloads self-sort by project, task, revision);
- no "['body/" path expressions. On the gov device (2026-11-11, Task 4 r1) outputs('Get_items')?['body/value']
  returned Null after Get items succeeded; use body('Action')?['key']."""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
bad = []
for f in sorted((ROOT / "flow" / "defs").glob("*.json")):
    if not re.fullmatch(r"90161Z-T\d{2}-[a-z0-9-]+-r\d+", f.stem):
        bad.append(f"BAD name {f.name}: use 90161Z-T<NN>-<slug>-r<N>.json")
    if re.search(r"""\[\s*\\?['"]body/""", f.read_text(encoding="utf-8")):
        bad.append(f"BAD {f.name}: body/ path expression; use body('Action')?['key']")
# R26: the solution test defs (flow/solution/test-defs) follow the same name rule and the body/ rule.
for f in sorted((ROOT / "flow" / "solution" / "test-defs").glob("*.json")):
    if not re.fullmatch(r"90161Z-T\d{2}-[a-z0-9-]+-r\d+", f.stem):
        bad.append(f"BAD name {f.name}: use 90161Z-T<NN>-<slug>-r<N>.json")
    if re.search(r"""\[\s*\\?['"]body/""", re.sub(r'"splitOn": "[^"]*"', "", f.read_text(encoding="utf-8"))):
        bad.append(f"BAD {f.name}: body/ path expression; use body('Action')?['key']")
print("\n".join(bad) or "OK flow defs")
sys.exit(1 if bad else 0)
