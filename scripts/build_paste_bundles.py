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
"""
import hashlib, json, os, subprocess, sys, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCK_FILE = ROOT / 'scripts/rade.lock.json'
CACHE = ROOT / '.rade-cache'
RAW = 'https://raw.githubusercontent.com/%s/%s/%s'


def sha256(path):
    """Return the SHA-256 hex digest of a file. Takes the path."""
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
    """Find the RADE engine file to build with. Takes nothing; returns its path: the RADE_DIR copy when set (with a warning), else the locked download."""
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


def render_logo(check):
    """Draw the logo PNGs that the bundles and application.logo list (assets/logo/build/90161Z-logo-<size>.png) into assets/logo/build/,
    before the engine reads them. Takes check (True = fail when the recorded hashes are stale; see logo_png.png)."""
    # R29 (PFM 17 Nov 26, 1A and 2A): a round may carry the 90-161.Z logo PNG (site logo and thumbnail). The PNGs are not
    # committed: scripts/logo_png.py draws them in code (scripts/logo_draw.py), the same bytes on every machine.
    import re
    man = ROOT / 'scripts/paste_bundles.json'
    if not man.exists():
        return
    sys.path.insert(0, str(ROOT / 'scripts'))
    import logo_png
    data = json.loads(man.read_text(encoding='utf-8'))
    # R44 (RADE engine-v42): application.logo is the PNG that RADE makes the shortcut icon from; draw it too.
    srcs = [f['src'] for b in data['bundles'] for f in b['files']]
    if data.get('application', {}).get('logo'):
        srcs.append(data['application']['logo'])
    for src in srcs:
        m = re.match(r'assets/logo/build/90161Z-logo-(\d+)\.png$', src)
        if m:
            dst = ROOT / src
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(logo_png.png(int(m.group(1)), check))


def copy_fonts(eng):
    """Copy the font files that the bundles list (assets/fonts/build/90161Z-<name>) from the engine's fonts folder.

    R39 (PFM 20 Nov 26, docs/phases.md R39): the 90-161.Z window (T22 r12) uses the Sofia Sans fonts of the RADE window.
    They are the pinned engine's own files (engine/fonts, hash-checked by fetch), so they are never committed here:
    assets/fonts/build/ is git-ignored, like the logo PNGs. The prefix 90161Z- marks them as files 90-161.Z made.

    Args:
        eng: the engine file path (its folder holds fonts/).
    Returns: nothing. Exits when a listed font is not in the engine.
    """
    import re, shutil
    man = ROOT / 'scripts/paste_bundles.json'
    if not man.exists():
        return
    fonts = Path(eng).parent / 'fonts'
    for b in json.loads(man.read_text(encoding='utf-8'))['bundles']:
        for f in b['files']:
            m = re.match(r'assets/fonts/build/90161Z-([A-Za-z0-9.-]+)$', f['src'])
            if not m:
                continue
            src = fonts / m.group(1)
            if not src.is_file():
                sys.exit('FAIL %s is listed in scripts/paste_bundles.json but the engine has no %s' % (f['src'], src))
            dst = ROOT / f['src']
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dst)


def no_scripts_in_results():
    """Stop the build when a collect name can match a script (the PFM, 2026-11-20: no scripts in results; R37 finding 1).
    Takes nothing; exits with the FAIL lines of scripts/check_collect.py when one is bad."""
    man = ROOT / 'scripts/paste_bundles.json'
    if not man.exists():   # no round definition, so no collect names (as in render_logo)
        return
    sys.path.insert(0, str(ROOT / 'scripts'))
    import check_collect
    fails = check_collect.check(json.loads((ROOT / 'scripts/paste_bundles.json').read_text(encoding='utf-8')))
    if fails:
        sys.exit('\n'.join(fails))


if __name__ == '__main__':
    no_scripts_in_results()
    e = engine()
    render_logo('--check' in sys.argv[1:])
    copy_fonts(e)
    code = subprocess.call([sys.executable, '-B', str(e), '--app-root', str(ROOT)] + [a for a in sys.argv[1:] if a == '--check'])
    readme = ROOT / 'scripts/build_readme.py'
    if code == 0 and '--check' not in sys.argv[1:] and readme.is_file() and (ROOT / 'README.md').is_file():   # a test copy may hold no README.md
        # README.md gets the new round's "Open the script" link and the tasks of go.md (the PFM, 2026-11-25).
        code = subprocess.call([sys.executable, '-B', str(readme)])
    sys.exit(code)
