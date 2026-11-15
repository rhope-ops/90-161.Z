#!/usr/bin/env python3
"""Build this repo's RADE round bundles with the pinned RADE engine. This repo needs no RADE checkout (PFM, 2026-11-15).

scripts/rade.lock.json names the RADE commit and every file the engine reads, each with its SHA-256. The build downloads
those files by commit id from raw.githubusercontent.com into .rade-cache/<commit>/ (git-ignored): each file goes to a
temporary name and gets its real name only after its SHA-256 matches. Every build hashes the cached files again; a
changed file is deleted and downloaded again. A wrong hash or no network with no good cache stops the build before the
engine runs, so no bundle is written.
RADE_DIR=<folder> is the one override, for a test of an unmerged engine: it skips the lock and prints a warning. Never
commit a bundle built that way (tests/run.sh checks the committed bundle against the pinned engine).
Lock rules (serial, who may change it): docs/dev-setup.md "RADE engine".
Usage: python3 scripts/build_paste_bundles.py [--check]      build (or check) every bundle in scripts/paste_bundles.json
       python3 scripts/build_paste_bundles.py --engine-path  print the checked engine path (tests read it)
"""
import hashlib, json, os, subprocess, sys, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCK_FILE = ROOT / 'scripts/rade.lock.json'
CACHE = ROOT / '.rade-cache'
RAW = 'https://raw.githubusercontent.com/%s/%s/%s'


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def fetch(lock, cache=CACHE, opener=urllib.request.urlopen):
    """Return the folder that holds the locked files, each one checked against the lock. Stops (SystemExit) on failure."""
    if lock['engine'] not in lock['files']:
        sys.exit('FAIL scripts/rade.lock.json: the engine file %r has no SHA-256 in "files".' % lock['engine'])
    home = Path(cache) / lock['commit']
    for rel, want in lock['files'].items():
        if rel.startswith('/') or '..' in Path(rel).parts:
            sys.exit('FAIL scripts/rade.lock.json: bad file path %r' % rel)
        dest = home / rel
        if dest.is_file():
            if sha256(dest) == want:
                continue
            print('NOTE the cached file %s changed after its download: deleted, downloading it again.' % dest, file=sys.stderr)
            dest.unlink()
        dest.parent.mkdir(parents=True, exist_ok=True)
        url = RAW % (lock['repo'], lock['commit'], rel)
        tmp = dest.with_name(dest.name + '.tmp%d' % os.getpid())
        try:
            with opener(url, timeout=30) as r:
                data = r.read()
        except Exception as e:   # no network, proxy block, HTTP error, timeout
            sys.exit('FAIL cannot download the RADE engine file %s (%s: %s) and the cache %s has no good copy. '
                     'The build needs network access to raw.githubusercontent.com once for each lock. No bundle was written.'
                     % (url, type(e).__name__, e, home))
        try:
            tmp.write_bytes(data)
            got = sha256(tmp)
            if got != want:
                sys.exit('FAIL %s has sha256 %s, the lock wants %s. The file was deleted. No bundle was written. '
                         'Fix scripts/rade.lock.json only on purpose (docs/dev-setup.md "RADE engine").' % (url, got, want))
            os.replace(tmp, dest)
        finally:
            if tmp.exists():
                tmp.unlink()
    return home


def engine():
    lock = json.loads(LOCK_FILE.read_text())
    over = os.environ.get('RADE_DIR')
    if over:
        e = Path(over) / lock['engine']
        if not e.is_file():
            sys.exit('FAIL RADE_DIR is set but %s does not exist.' % e)
        print('WARNING RADE_DIR is set: this build uses the engine in %s and skips scripts/rade.lock.json. '
              'Never commit a bundle built this way.' % over, file=sys.stderr)
        return e
    return fetch(lock) / lock['engine']


if __name__ == '__main__':
    e = engine()
    if '--engine-path' in sys.argv:
        print(e); sys.exit(0)
    sys.exit(subprocess.call([sys.executable, '-B', str(e), '--app-root', str(ROOT)] + [a for a in sys.argv[1:] if a == '--check']))
