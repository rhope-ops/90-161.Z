#!/usr/bin/env python3
"""The 90-161.Z logo PNGs for the build scripts (R29; the PFM, 2026-11-17: 1A logo places, 2A PNGs never committed).

The master is assets/logo/90161Z-logo.svg; scripts/build_logo.js renders the PNGs (Playwright with Chromium). The record
assets/logo/90161Z-logo.render.json holds the SHA-256 of the SVG and of each PNG it rendered.
- With a renderer (cloud sessions): every build renders again. A build writes the record; a --check fails when the render
  differs from the record (run the build).
- With no renderer (the GitHub runner has no Playwright): the SVG must still match the record, and the PNG is taken from the
  committed text that already embeds it (the caller's fallback) and must match the recorded SHA-256. So the check proves the
  same bytes either way; it never skips.
"""
import hashlib, json, subprocess, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SVG = ROOT / 'assets/logo/90161Z-logo.svg'
RECORD = ROOT / 'assets/logo/90161Z-logo.render.json'
SIZES = (512, 192, 128, 64, 32, 16)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def render():
    """{size: bytes} from scripts/build_logo.js, or None when node or Playwright is not installed."""
    with tempfile.TemporaryDirectory() as d:
        try:
            r = subprocess.run(['node', str(ROOT / 'scripts/build_logo.js'), d], capture_output=True, text=True)
        except FileNotFoundError:
            return None
        if r.returncode != 0:
            if "Cannot find module 'playwright'" in r.stderr or 'Executable doesn' in r.stderr:
                return None
            raise SystemExit('LOGO render failed: ' + r.stderr.strip()[-300:])
        return {n: (Path(d) / f'90161Z-logo-{n}.png').read_bytes() for n in SIZES}


_cache = {}


def png(size, check, fallback):
    """The PNG of one size. fallback() returns the bytes the committed text holds (used only with no renderer)."""
    if 'r' not in _cache:
        _cache['r'] = render()
    rec = json.loads(RECORD.read_text(encoding='utf-8')) if RECORD.exists() else {}
    svg = sha(SVG.read_bytes())
    pngs = _cache['r']
    if pngs is not None:
        want = {'svg': svg, 'png': {str(n): sha(b) for n, b in pngs.items()}}
        if rec != want:
            if check:
                raise SystemExit('LOGO record stale: the SVG or its render changed (run python3 scripts/build_task_scripts.py)')
            RECORD.write_text(json.dumps(want, indent=2) + '\n', encoding='utf-8')
        return pngs[size]
    if rec.get('svg') != svg:
        raise SystemExit('LOGO: the SVG changed and no renderer is here (node + Playwright): build where one is')
    data = fallback()
    if data is None or sha(data) != rec['png'][str(size)]:
        raise SystemExit('LOGO: the committed %d px PNG does not match the record' % size)
    return data
