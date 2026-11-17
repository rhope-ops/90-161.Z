#!/usr/bin/env python3
"""Measure every listed text pair in docs/palette.json against WCAG 2.1 contrast (PFM: verify by measuring)."""
import json, pathlib, sys
P = json.loads((pathlib.Path(__file__).resolve().parent.parent / "docs" / "palette.json").read_text())
def lum(h):
    """Return the relative luminance of a color. Takes a 6-digit hex string (no #); returns a number from 0 to 1."""
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
bad = []
for fg, bg, need in P["pairs"]:
    a, b = sorted([lum(P["tokens"][fg]), lum(P["tokens"][bg])], reverse=True)
    r = (a + 0.05) / (b + 0.05)
    print(f"{fg} on {bg}: {r:.2f}:1 (need {need})")
    if r < need: bad.append(f"{fg} on {bg}")
print("FAIL " + ", ".join(bad) if bad else f"OK palette {len(P['pairs'])} pairs")
sys.exit(1 if bad else 0)
