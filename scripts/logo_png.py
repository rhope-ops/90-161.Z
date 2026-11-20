#!/usr/bin/env python3
"""The 90-161.Z logo PNGs for the build scripts (R29; the PFM, 2026-11-17: 1A logo places, 2A PNGs never committed;
logo drawn in code, the PFM, 2026-11-17).

Two masters (MASTERS): 'usaf' = assets/logo/90161Z-logo.svg (USAF colours: dark mode, the site logo, the round PNG files)
and, from R37, 'fulcrum' = assets/logo/90161Z-logo-fulcrum.svg (Fulcrum colours: Windows light mode in the T22 window;
the PFM, 19 Nov 26: the same logo rule as the bookmark page). scripts/logo_draw.py draws them in pure Python, so every
machine gives the same bytes (a browser render did not). Each master has its record (<master name>.render.json beside
it) with the SHA-256 of the SVG and of each PNG size it is drawn at. A build writes a record when it changed; a --check
fails when the SVG or the drawing code gives other PNGs than the record (run the build, then review the new logo before
it ships).
Used by: scripts/build_task_scripts.py (128 px of both masters in the T22 window) and scripts/build_paste_bundles.py
(the 'usaf' PNG files a round carries). Run target: Python 3.8+, standard library only.
"""
import hashlib
import json
from pathlib import Path

import logo_draw

ROOT = Path(__file__).resolve().parent.parent
# master name -> (SVG, record, the sizes it is drawn at). Fulcrum is drawn only at the size the T22 window uses (each size
# costs about half a second to draw).
MASTERS = {
    'usaf': (ROOT / 'assets/logo/90161Z-logo.svg', ROOT / 'assets/logo/90161Z-logo.render.json', (512, 192, 128, 64, 32, 16)),
    'fulcrum': (ROOT / 'assets/logo/90161Z-logo-fulcrum.svg', ROOT / 'assets/logo/90161Z-logo-fulcrum.render.json', (128,)),
}
SVG, RECORD, SIZES = MASTERS['usaf']   # the names other scripts read (the 'usaf' master)
_cache = {}


def sha(data):
    """Return the SHA-256 of bytes as hex."""
    return hashlib.sha256(data).hexdigest()


def png(size, check, master='usaf'):
    """Return the PNG bytes of one logo size of one master ('usaf' or 'fulcrum'). With `check` True, stop when the
    master's record does not match the drawing (the SVG or the drawing code changed); otherwise write the new record.
    All sizes of a master are drawn once per run."""
    svg, record, sizes = MASTERS[master]
    if master not in _cache:
        svg_text = svg.read_text(encoding='utf-8')
        _cache[master] = {n: logo_draw.draw(svg_text, n) for n in sizes}
        want = {'svg': sha(svg.read_bytes()), 'png': {str(n): sha(b) for n, b in _cache[master].items()}}
        have = json.loads(record.read_text(encoding='utf-8')) if record.exists() else {}
        if have != want:
            if check:
                raise SystemExit('LOGO record stale (%s): the SVG or scripts/logo_draw.py changed (run python3 scripts/build_task_scripts.py)' % master)
            record.write_text(json.dumps(want, indent=2) + '\n', encoding='utf-8')
    return _cache[master][size]
