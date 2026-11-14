#!/usr/bin/env python3
"""Build this repo's RADE round bundles with the pinned RADE engine (the Administrator, 2026-11-14: the engine moved to
rhope-ops/RADE engine/rade_build.py; this repo keeps only its manifest scripts/paste_bundles.json and its files).

Finds a RADE checkout: $RADE_DIR, else a folder next to this repo named RADE (any letter case). The engine file must
match the sha256 in scripts/rade.lock.json; another engine stops the build (update the lock on purpose, in its own
commit, after the RADE change is merged). CI runs no project tests here (no scripts/check.local.sh).
Usage: python3 scripts/build_paste_bundles.py [--check]      build (or check) every bundle in scripts/paste_bundles.json
       python3 scripts/build_paste_bundles.py --engine-path  print the checked engine path (tests read it)
"""
import hashlib, json, os, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCK = json.loads((ROOT / 'scripts/rade.lock.json').read_text())


def engine():
    cands = [Path(os.environ['RADE_DIR'])] if os.environ.get('RADE_DIR') else [p for p in ROOT.parent.iterdir() if p.is_dir() and p.name.lower() == 'rade']
    for c in cands:
        e = c / LOCK['engine']
        if e.is_file():
            sha = hashlib.sha256(e.read_bytes()).hexdigest()
            if sha != LOCK['sha256']:
                sys.exit('FAIL RADE engine %s has sha256 %s, the lock wants %s (commit %s). Check out that commit, or update scripts/rade.lock.json on purpose.'
                         % (e, sha[:12], LOCK['sha256'][:12], LOCK['commit'][:12]))
            return e
    sys.exit('FAIL no RADE checkout: clone https://github.com/%s next to this repo (folder RADE) at commit %s, or set RADE_DIR.' % (LOCK['repo'], LOCK['commit']))


if __name__ == '__main__':
    e = engine()
    if '--engine-path' in sys.argv:
        print(e); sys.exit(0)
    sys.exit(subprocess.call([sys.executable, str(e), '--app-root', str(ROOT)] + [a for a in sys.argv[1:] if a == '--check']))
