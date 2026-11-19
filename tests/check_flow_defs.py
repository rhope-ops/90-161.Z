#!/usr/bin/env python3
"""Check flow/defs/*.json, flow/solution/test-defs/*.json and flow/solution/defs/*.json:
- file name 90161Z-T<NN>-<slug>-r<N> (PFM 2026-11-11: downloads self-sort by project, task, revision);
- no "['body/" path expressions. On the gov device (2026-11-11, Task 4 r1) outputs('Get_items')?['body/value']
  returned Null after Get items succeeded; use body('Action')?['key']."""
import json, pathlib, re, sys

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
# R34: the flow solution defs (flow/solution/defs): the six product flows 90161Z-F<NN>-..., and the T21 probe flows of the
# solution (fallback A, the PFM 18 Nov 26), which use only the SharePoint connector (no Power Automate Management).
sol_defs = sorted((ROOT / "flow" / "solution" / "defs").glob("*.json"))
for f in sol_defs:
    if not re.fullmatch(r"90161Z-(F\d{2}|T21-probe)-[a-z0-9-]+-r\d+", f.stem):
        bad.append(f"BAD name {f.name}: use 90161Z-F<NN>-<slug>-r<N> or 90161Z-T21-probe-<slug>-r<N>")
    text = f.read_text(encoding="utf-8")
    if re.search(r"""\[\s*\\?['"]body/""", re.sub(r'"splitOn": "[^"]*"', "", text)):
        bad.append(f"BAD {f.name}: body/ path expression; use body('Action')?['key']")
    if f.stem.startswith("90161Z-T21-") and (json.loads(text)["connections"] != ["shared_sharepointonline"] or "shared_flowmanagement" in text):
        bad.append(f"BAD {f.name}: a probe flow of the solution uses only the SharePoint connector")
if len([f for f in sol_defs if f.stem.startswith("90161Z-T21-probe-")]) != 2:
    bad.append("BAD flow/solution/defs: expected the 2 T21 probe flows (health and button)")
print("\n".join(bad) or f"OK flow defs (solution defs={len(sol_defs)})")
sys.exit(1 if bad else 0)
