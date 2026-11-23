#!/usr/bin/env python3
"""Measure color pairs against WCAG 2.1 contrast (PFM: verify by measuring; fleet v2: compute ratios in code, never by hand).

Part 1: every listed text pair in docs/palette.json.
Part 2 (fleet v2, 2026-11-23): the real CSS tokens of the pages, read from the files, in each color scheme:
  index.html (light, dark) and templates/list-mockup.css (light, dark). Text pairs need 4.5:1; control borders
  (--ctl: buttons, chips, pills) need 3:1 against the surfaces they sit on (WCAG 1.4.11).
Run: python3 tests/check_palette.py (tests/run.sh runs it). Last line "OK palette N pairs, M page pairs"; exit 1 on a fail.
Network: none.
Writes: none.
Credentials: none.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
P = json.loads((ROOT / "docs" / "palette.json").read_text())

# Page pairs: (file, scheme, foreground token, background token, minimum ratio).
PAGE_PAIRS = [
    (page, scheme, fg, bg, need)
    for page, scheme in (("index.html", "light"), ("index.html", "dark"))
    for fg, bg, need in (("fg", "bg", 4.5), ("fg", "card", 4.5), ("mut", "bg", 4.5), ("mut", "card", 4.5),
                         ("acc", "bg", 4.5), ("acc", "card", 4.5), ("ctl", "bg", 3.0), ("ctl", "card", 3.0),
                         ("open-fg", "open-bg", 4.5), ("done-fg", "done-bg", 4.5), ("note-fg", "note-bg", 4.5))
] + [
    ("templates/list-mockup.css", scheme, fg, bg, need)
    for scheme in ("light", "dark")
    for fg, bg, need in (("fg", "bg", 4.5), ("fg", "surface", 4.5), ("muted", "surface", 4.5), ("accent", "surface", 4.5),
                         ("accent", "accent-soft", 4.5), ("ctl", "surface", 3.0), ("ctl", "bg", 3.0))
]


def lum(h):
    """Return the relative luminance of a color. Takes a 6-digit hex string (with or without #); returns 0 to 1."""
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def ratio(a, b):
    """Return the WCAG contrast ratio of two hex colors (1 to 21)."""
    x, y = sorted([lum(a), lum(b)], reverse=True)
    return (x + 0.05) / (y + 0.05)


def tokens(path):
    """Read the custom properties of a page's color schemes.

    Args:
        path: the file, relative to the repository root (an .html page with a <style> block, or a .css file).

    Returns:
        A dict {"light": {name: hex}, "dark": {name: hex}}. Light is the first ":root{...}" block; dark is the
        ':root[data-theme="dark"]{...}' block laid over light (the prefers-color-scheme block holds the same values).
    """
    text = (ROOT / path).read_text(encoding="utf-8")
    light = re.search(r"(?m)^:root\{([^}]*)\}", text)
    dark = re.search(r':root\[data-theme="dark"\]\{([^}]*)\}', text)

    def props(block):
        """Map --name: #hex declarations of one block. Takes the block text; returns a dict (6-digit hex only)."""
        return {m.group(1): m.group(2) for m in re.finditer(r"--([\w-]+):\s*(#[0-9a-fA-F]{6})\b", block or "")}

    base = props(light.group(1) if light else "")
    return {"light": base, "dark": dict(base, **props(dark.group(1) if dark else ""))}


def main():
    """Run both parts and print one line per pair, then the OK or FAIL line.

    Returns:
        The exit code: 1 when any pair is below its minimum or a token is missing, else 0.
    """
    bad = []
    for fg, bg, need in P["pairs"]:
        r = ratio(P["tokens"][fg], P["tokens"][bg])
        print(f"{fg} on {bg}: {r:.2f}:1 (need {need})")
        if r < need:
            bad.append(f"{fg} on {bg}")
    seen = {}
    for page, scheme, fg, bg, need in PAGE_PAIRS:
        t = seen.setdefault(page, tokens(page))[scheme]
        if fg not in t or bg not in t:
            bad.append(f"{page} {scheme}: token --{fg} or --{bg} not found")
            continue
        r = ratio(t[fg], t[bg])
        print(f"{page} {scheme} --{fg} {t[fg]} on --{bg} {t[bg]}: {r:.2f}:1 (need {need})")
        if r < need:
            bad.append(f"{page} {scheme} --{fg} on --{bg}")
    print("FAIL " + ", ".join(bad) if bad else f"OK palette {len(P['pairs'])} pairs, {len(PAGE_PAIRS)} page pairs")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
