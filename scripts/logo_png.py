#!/usr/bin/env python3
"""The 90-161.Z logo PNGs for the build scripts (R29; the PFM, 2026-11-17: 1A logo places, 2A PNGs never committed;
logo drawn in code, the PFM, 2026-11-17).

The master is assets/logo/90161Z-logo.svg. scripts/logo_draw.py draws it in pure Python, so every machine gives the same
bytes (a browser render did not). The record assets/logo/90161Z-logo.render.json holds the SHA-256 of the SVG and of
each PNG size. A build writes the record when it changed; a --check fails when the SVG or the drawing code gives other
PNGs than the record (run the build, then review the new logo before it ships).
Used by: scripts/build_task_scripts.py (128 px in the T22 window) and scripts/build_paste_bundles.py (the PNG files a
round carries). Run target: Python 3.8+, standard library only.
"""
import hashlib
import json
from pathlib import Path

import logo_draw

ROOT = Path(__file__).resolve().parent.parent
SVG = ROOT / 'assets/logo/90161Z-logo.svg'
RECORD = ROOT / 'assets/logo/90161Z-logo.render.json'
SIZES = (512, 192, 128, 64, 32, 16)
_cache = {}


def sha(data):
    """Return the SHA-256 of bytes as hex."""
    return hashlib.sha256(data).hexdigest()


def png(size, check):
    """Return the PNG bytes of one logo size. With `check` True, stop when the record does not match the drawing (the
    SVG or the drawing code changed); otherwise write the new record. All sizes are drawn once per run."""
    if 'pngs' not in _cache:
        svg_text = SVG.read_text(encoding='utf-8')
        _cache['pngs'] = {n: logo_draw.draw(svg_text, n) for n in SIZES}
        want = {'svg': sha(SVG.read_bytes()), 'png': {str(n): sha(b) for n, b in _cache['pngs'].items()}}
        have = json.loads(RECORD.read_text(encoding='utf-8')) if RECORD.exists() else {}
        if have != want:
            if check:
                raise SystemExit('LOGO record stale: the SVG or scripts/logo_draw.py changed (run python3 scripts/build_task_scripts.py)')
            RECORD.write_text(json.dumps(want, indent=2) + '\n', encoding='utf-8')
    return _cache['pngs'][size]
